import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';
import 'package:theme_reveal_kit_example/readme_external.dart' as adapter;
import 'package:theme_reveal_kit_example/readme_usage.dart' as usage;
import 'support/readme_bloc.dart' as bloc_recipe;
import 'package:theme_reveal_kit_example/presentation_recipes.dart' as recipes;
import 'package:theme_reveal_kit_example/presentation_quick_start.dart'
    as quick;
import 'package:theme_reveal_kit_example/readme_snippets.dart' as snippets;

Directory _packageRoot() {
  var directory = Directory.current;
  while (!File('${directory.path}/lib/theme_reveal_kit.dart').existsSync()) {
    if (directory.parent.path == directory.path) {
      throw StateError('Package root not found');
    }
    directory = directory.parent;
  }
  return directory;
}

void main() {
  final root = _packageRoot();
  String read(String path) => File('${root.path}/$path').readAsStringSync();

  test('all README Dart blocks match sources compiled by this test import', () {
    final readme = read('README.md');
    String dedent(String value) {
      final lines = value.replaceFirst(RegExp(r'\s+$'), '').split('\n');
      final indent = lines
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.length - line.trimLeft().length)
          .reduce((a, b) => a < b ? a : b);
      return lines
          .map((line) => line.length >= indent ? line.substring(indent) : '')
          .join('\n')
          .trim();
    }

    final sourceFiles = [
      'example/lib/readme_usage.dart',
      'example/lib/readme_managed.dart',
      'example/lib/readme_notifier.dart',
      'example/lib/readme_external_app.dart',
      'example/lib/readme_settings.dart',
      'example/lib/readme_storage.dart',
      'example/test/support/readme_bloc.dart',
    ];
    final snippetsByKey = <String, String>{};
    for (final path in sourceFiles) {
      for (final match in RegExp(
        r'^[ \t]*// snippet:(\w+):(file|expression|statements)\n(.*?)^[ \t]*// end:\1',
        multiLine: true,
        dotAll: true,
      ).allMatches(read(path))) {
        var body = dedent(match[3]!);
        if (match[2] == 'expression') body = body.substring(0, body.length - 1);
        snippetsByKey[match[1]!] = body;
      }
    }
    final blocks = RegExp(
      r'<!-- snippet:(\w+) -->\n```dart\n(.*?)\n```',
      dotAll: true,
    ).allMatches(readme).toList();
    expect(blocks.length, snippetsByKey.length);
    expect(RegExp(r'```dart\n').allMatches(readme).length, blocks.length);
    for (final block in blocks) {
      expect(
        block[2],
        snippetsByKey[block[1]],
        reason: 'README body differs: ${block[1]}',
      );
      expect(block[2]!.startsWith('//'), isTrue);
      expect(
        block[2],
        isNot(matches(RegExp(r'^(Widget |Future<bool> )', multiLine: true))),
      );
    }
    final source = [
      read('example/lib/readme_external.dart'),
      read('example/lib/readme_snippets.dart'),
    ].join('\n');
    for (final block in RegExp(
      r'```dart\n([\s\S]*?)\n```',
    ).allMatches(read('doc/widgets_and_external_mode.md'))) {
      expect(source.contains(block[1]!), isTrue);
    }
    expect(RegExp(r'^## ', multiLine: true).allMatches(readme), hasLength(12));
    for (final match in RegExp(r'\]\(([^)]+)\)').allMatches(readme)) {
      final target = match[1]!;
      if (!target.startsWith('http') && !target.startsWith('#')) {
        expect(
          FileSystemEntity.typeSync('${root.path}/$target') !=
              FileSystemEntityType.notFound,
          isTrue,
          reason: target,
        );
      }
    }
    expect(readme, contains('| macOS | Verified |'));
    expect(readme, contains('| Android | Unverified |'));
    expect(readme, contains('| iOS | Unverified |'));
    expect(readme, contains('| Web | Unverified |'));
    expect(readme, contains('alt="verified: macOS"'));
    final images = RegExp(
      r'<img\b[^>]*>',
    ).allMatches(readme).map((m) => m[0]!).toList();
    final badgeSources = images
        .take(5)
        .map((tag) => RegExp(r'src="([^"]+)"').firstMatch(tag)![1]!)
        .toList();
    expect(badgeSources, [
      'https://img.shields.io/pub/v/theme_reveal_kit',
      'https://img.shields.io/pub/likes/theme_reveal_kit',
      'https://img.shields.io/pub/points/theme_reveal_kit',
      'https://img.shields.io/badge/license-MIT-blue',
      'https://img.shields.io/badge/verified-macOS-success',
    ]);
    for (final tag in images) {
      expect(tag, matches(r'alt="[^"]+"'));
      expect(tag, matches(r'width="[1-9][0-9]*"'));
    }
    for (final tag in images.skip(5)) {
      expect(
        tag,
        contains(
          'https://raw.githubusercontent.com/Ahmedelsapagh10/theme_reveal/master/doc/media/',
        ),
      );
    }
    expect(readme, isNot(contains('](LICENSE)')));
    expect(readme, isNot(contains('](CONTRIBUTING.md)')));
    expect(readme, isNot(contains('](example/)')));
    const raw =
        'https://raw.githubusercontent.com/Ahmedelsapagh10/theme_reveal/master/';
    for (final match in RegExp(
      r'https://raw\.githubusercontent\.com/[^)\s"]+',
    ).allMatches(readme)) {
      expect(match[0]!, startsWith(raw));
      expect(
        File('${root.path}/${match[0]!.substring(raw.length)}').existsSync(),
        isTrue,
      );
    }
    final manifest = jsonDecode(read('doc/media/manifest.json')) as List;
    for (final entry in manifest) {
      final file = File('${root.path}/doc/media/${entry['file']}');
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), entry['bytes']);
      if (file.path.endsWith('.gif')) {
        expect(file.lengthSync(), lessThanOrEqualTo(1500000));
      }
    }
  });

  test(
    'JSON fixtures resolve, assets are declared, schema and release metadata are valid',
    () {
      for (final document in [
        snippets.jsonPathDocument,
        snippets.jsonShapeDocument,
      ]) {
        expect(jsonDecode(document), isA<Map<String, dynamic>>());
        expect(
          RevealShape.jsonString(document).resolve().bounds.isEmpty,
          isFalse,
        );
      }
      final schema =
          jsonDecode(read('doc/reveal_shape.schema.json'))
              as Map<String, dynamic>;
      expect(schema['oneOf'], hasLength(2));
      for (final asset in [
        'assets/logo.svg',
        'assets/logo.png',
        'assets/custom_shape.json',
      ]) {
        expect(read('example/pubspec.yaml'), contains('    - $asset'));
        expect(File('${root.path}/example/$asset').existsSync(), isTrue);
      }
      expect(read('pubspec.yaml'), contains('version: 0.1.1'));
      final metadata = read('pubspec.yaml');
      expect(
        metadata,
        contains(
          'issue_tracker: https://github.com/Ahmedelsapagh10/theme_reveal/issues',
        ),
      );
      final screenshots = RegExp(
        r'^    path: (.+)$',
        multiLine: true,
      ).allMatches(metadata).toList();
      expect(screenshots.length, inInclusiveRange(1, 10));
      for (final screenshot in screenshots) {
        expect(File('${root.path}/${screenshot[1]}').existsSync(), isTrue);
      }
      final topics = metadata.split('topics:\n')[1].split('\n\n')[0];
      expect(
        RegExp(r'^  - ', multiLine: true).allMatches(topics).length,
        lessThanOrEqualTo(5),
      );
      expect(read('pubspec.yaml'), contains('flutter: ">=3.41.0"'));
      expect(
        read('pubspec.yaml'),
        contains('repository: https://github.com/Ahmedelsapagh10/theme_reveal'),
      );
      expect(
        read('LICENSE'),
        startsWith('MIT License\n\nCopyright (c) 2026 Ahmed Elsapagh'),
      );
      expect(File('${root.path}/lib/theme_reveal.dart').existsSync(), isFalse);
    },
  );

  testWidgets(
    'quick start compiles and preserves managed state; all widget/config recipes construct',
    (tester) async {
      final controller = RevealThemeController(storage: MemoryThemeStorage());
      expect(quick.main, isA<Function>());
      expect(usage.main, isA<Function>());
      expect(const bloc_recipe.CubitThemeApp(), isA<Widget>());
      expect(usage.externalButton, isA<Function>());
      expect(recipes.animation.duration, const Duration(milliseconds: 900));
      expect(recipes.chooseMode, isA<Function>());
      final widgets = <Widget>[
        recipes.circularButton(controller),
        recipes.starButton(controller),
        recipes.triangleButton(controller),
        snippets.modeSelector(controller),
        snippets.settingsAppearance(controller),
        snippets.iconMaskButton(controller),
        snippets.svgMaskButton(controller),
        snippets.pngMaskButton(controller),
        snippets.jsonMaskButton(controller),
        snippets.customThemeTrigger(controller),
        snippets.accessibleThemeButton(controller),
      ];
      expect(widgets, hasLength(11));
      expect(
        snippets.diamondPath().resolve().containsUnit(Offset.zero),
        isTrue,
      );
      expect(
        snippets.preservingStar().completionStrategy,
        RevealCompletionStrategy.preserveShape,
      );
      expect(
        snippets.morphingStar().completionStrategy,
        RevealCompletionStrategy.morphToFullscreen,
      );
      expect(
        snippets.dissolvingLogo().completionStrategy,
        RevealCompletionStrategy.expandAndDissolve,
      );
      expect(
        snippets.animatedConfiguration().duration,
        const Duration(milliseconds: 850),
      );
      // These platform/animation operations are compiled, not invoked without their host.
      expect(snippets.restoreSavedTheme, isA<Function>());
      expect(snippets.revealFromCenter, isA<Function>());
      expect(snippets.main, isA<Function>());
      await tester.pumpWidget(snippets.QuickStartApp(controller: controller));
      final navigator = tester.state(find.byType(Navigator));
      controller.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(Navigator)), same(navigator));
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .themeAnimationDuration,
        Duration.zero,
      );
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.dark,
      );
      await controller.flush();
      await tester.pumpWidget(
        const SizedBox.shrink(),
      ); // QuickStartApp owns disposal.
    },
  );

  testWidgets('README ValueNotifier recipe changes the live theme', (
    tester,
  ) async {
    final mode = ValueNotifier(ThemeMode.light);
    await tester.pumpWidget(recipes.externalThemeApp(mode));
    await tester.tap(find.text('Toggle theme'));
    await tester.pumpAndSettle();
    expect(mode.value, ThemeMode.dark);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    mode.dispose();
  });

  testWidgets('usage Cubit-style and ValueNotifier apps emit through reveal', (
    tester,
  ) async {
    await tester.pumpWidget(const bloc_recipe.CubitThemeApp());
    await tester.tap(find.text('Change theme'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tester.pumpWidget(const usage.NotifierThemeApp());
    await tester.tap(find.text('Change theme'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'usage Settings, trigger and three-state selector change managed theme',
    (tester) async {
      final controller = RevealThemeController(storage: MemoryThemeStorage());
      Widget app(Widget home) => RevealThemeBuilder(
        controller: controller,
        builder: (context, settings) => MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: settings.themeMode,
          themeAnimationDuration: settings.themeAnimationDuration,
          builder: settings.builder,
          home: home,
        ),
      );
      await tester.pumpWidget(app(usage.SettingsPage(controller: controller)));
      await tester.tap(find.byType(RevealThemeButton));
      await tester.pumpAndSettle();
      expect(controller.themeMode, ThemeMode.dark);
      await tester.pumpWidget(
        app(Scaffold(body: usage.customButton(controller))),
      );
      await tester.tap(find.byType(RevealThemeTrigger));
      await tester.pumpAndSettle();
      expect(controller.themeMode, ThemeMode.light);
      await tester.pumpWidget(
        app(Scaffold(body: usage.themeSelector(controller))),
      );
      for (final mode in [ThemeMode.dark, ThemeMode.system, ThemeMode.light]) {
        await tester.tap(
          find.text(switch (mode) {
            ThemeMode.light => 'Light',
            ThemeMode.dark => 'Dark',
            ThemeMode.system => 'System',
          }),
        );
        await tester.pumpAndSettle();
        expect(controller.themeMode, mode);
      }
      for (final button in [
        usage.circleButton,
        usage.triangleButton,
        usage.starButton,
        usage.heartButton,
        usage.roundedButton,
        usage.iconButton,
        usage.svgButton,
        usage.pngButton,
        usage.jsonButton,
        usage.pathButton,
      ]) {
        expect(
          (button(controller) as RevealThemeButton).revealShape,
          isA<RevealShape>(),
        );
      }
      await controller.flush();
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  test('usage storage adapter restores and writes theme preferences', () async {
    String? saved = 'dark';
    final storage = usage.AppThemeStorage(
      load: () async => saved,
      save: (value) async => saved = value,
    );
    final controller = await usage.restoreTheme(storage);
    expect(controller.themeMode, ThemeMode.dark);
    controller.resetToSystem();
    await controller.flush();
    expect(saved, 'system');
    saved = 'invalid';
    await usage.refreshTheme(controller);
    expect(controller.themeMode, ThemeMode.system);
    controller.dispose();
  });

  test('custom storage recipe persists for its session', () async {
    final controller = await snippets.sessionController();
    expect(controller.themeMode, ThemeMode.system);
    controller.setThemeMode(ThemeMode.dark);
    await controller.flush();
    await controller.reloadFromStorage();
    expect(controller.themeMode, ThemeMode.dark);
    controller.dispose();
  });

  testWidgets('compiled Cubit adapter waits for an async state emission', (
    tester,
  ) async {
    final mode = ValueNotifier(ThemeMode.light);
    final source = GlobalKey();
    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: mode,
        builder: (context, value, _) => MaterialApp(
          themeMode: value,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeAnimationDuration: Duration.zero,
          builder: (context, child) => ThemeRevealViewport(child: child!),
          home: Scaffold(key: source, body: const Text('External state')),
        ),
      ),
    );
    final request = adapter.revealCubitMode(
      source.currentContext!,
      mode: ThemeMode.dark,
      config: const RevealAnimationConfig(
        reducedMotion: RevealReducedMotion.always,
      ),
      updateMode: (value) async {
        await Future<void>.value();
        mode.value = value;
      },
    );
    await tester.pumpAndSettle();
    expect(await request, isTrue);
    expect(Theme.of(source.currentContext!).brightness, Brightness.dark);
    expect(
      ThemeRevealViewport.of(source.currentContext!).debugHasSnapshot,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    mode.dispose();
  });
}
