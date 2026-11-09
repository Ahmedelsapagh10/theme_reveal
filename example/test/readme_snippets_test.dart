import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';
import 'package:theme_reveal_kit_example/readme_external.dart' as adapter;
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
    'all 16 README Dart blocks match sources compiled by this test import',
    () {
      final readme = read('README.md');
      final source = [
        read('example/lib/readme_snippets.dart'),
        read('example/lib/readme_external.dart'),
      ].join('\n');
      final blocks = RegExp(
        r'```dart\n([\s\S]*?)\n```',
      ).allMatches(readme).toList();
      expect(blocks, hasLength(16));
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
      final sections = RegExp(
        r'^## (\d+)\. ',
        multiLine: true,
      ).allMatches(readme).map((m) => int.parse(m[1]!));
      expect(sections, orderedEquals(List.generate(25, (index) => index + 1)));
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
      expect(readme, contains('Preview media pending'));
      expect(readme, isNot(contains('![')));
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
      expect(
        jsonBlocks.map((m) => m[1]),
        orderedEquals([snippets.jsonPathDocument, snippets.jsonShapeDocument]),
      );
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
      expect(read('pubspec.yaml'), contains('RELEASE METADATA PLACEHOLDER'));
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
      final recipes = <Widget>[
        snippets.modeSelector(controller),
        snippets.settingsAppearance(controller),
        snippets.iconMaskButton(controller),
        snippets.svgMaskButton(controller),
        snippets.pngMaskButton(controller),
        snippets.jsonMaskButton(controller),
        snippets.customThemeTrigger(controller),
        snippets.accessibleThemeButton(controller),
      ];
      expect(recipes, hasLength(8));
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
