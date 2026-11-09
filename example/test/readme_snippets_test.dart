import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';
import 'package:theme_reveal_kit_example/readme_external.dart' as adapter;
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

  test(
    'all 18 README Dart blocks match sources compiled by this test import',
    () {
      final readme = read('README.md');
      final source = [
        read('example/lib/readme_snippets.dart'),
        read('example/lib/readme_external.dart'),
        read('example/lib/presentation_recipes.dart'),
        read('example/lib/presentation_quick_start.dart'),
      ].join('\n');
      final blocks = RegExp(
        r'```dart\n([\s\S]*?)\n```',
      ).allMatches(readme).toList();
      expect(blocks, hasLength(18));
      for (final block in RegExp(
        r'```[^\n]*\n([\s\S]*?)\n```',
      ).allMatches(readme)) {
        expect(block[1]!.split('\n').length, lessThanOrEqualTo(25));
      }
      for (final block in blocks) {
        expect(
          source.contains(block[1]!),
          isTrue,
          reason: 'README block differs from compiled code: ${block[1]}',
        );
      }
      for (final block in RegExp(
        r'```dart\n([\s\S]*?)\n```',
      ).allMatches(read('doc/widgets_and_external_mode.md'))) {
        expect(source.contains(block[1]!), isTrue);
      }
      expect(
        RegExp(r'^## ', multiLine: true).allMatches(readme),
        hasLength(18),
      );
      for (final match in RegExp(r'\]\(([^)]+)\)').allMatches(readme)) {
        final target = match[1]!;
        if (!target.startsWith('http') && !target.startsWith('#')) {
          expect(
            File('${root.path}/$target').existsSync(),
            isTrue,
            reason: target,
          );
        }
      }
      expect(readme, contains('Profile-mode performance | Unmeasured'));
      expect(readme, contains('![macOS verified]'));
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
    },
  );

  test(
    'README JSON documents resolve, assets are declared, schema and release metadata are valid',
    () {
      final readme = read('README.md');
      final jsonBlocks = RegExp(
        r'```json\n([\s\S]*?)\n```',
      ).allMatches(readme).toList();
      expect(jsonBlocks, hasLength(2));
      for (final block in jsonBlocks) {
        expect(jsonDecode(block[1]!), isA<Map<String, dynamic>>());
        expect(
          RevealShape.jsonString(block[1]!).resolve().bounds.isEmpty,
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
      expect(read('pubspec.yaml'), contains('version: 0.1.0'));
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
