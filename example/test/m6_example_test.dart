import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';
import 'package:theme_reveal_kit_example/app.dart';
import 'package:theme_reveal_kit_example/example_storage.dart';
import 'package:theme_reveal_kit_example/external_main.dart';
import 'package:theme_reveal_kit_example/reveal_preferences.dart';

class _Backend implements ThemePreferencesBackend {
  final values = <String, String>{'theme_reveal_kit.mode': 'light'};
  bool failReads = false;
  @override
  Future<String?> getString(String key) async {
    if (failReads) throw StateError('Offline preferences');
    return values[key];
  }

  @override
  Future<bool?> getBool(String key) async => null;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _Fixture {
  _Fixture() {
    storage = ExampleThemeStorage(backend: backend);
    controller = RevealThemeController(
      defaultMode: ThemeMode.light,
      storage: storage,
    );
    preferences.updateConfig(
      const RevealAnimationConfig(reducedMotion: RevealReducedMotion.always),
    );
  }
  final backend = _Backend();
  final preferences = RevealPreferences();
  late final ExampleThemeStorage storage;
  late final RevealThemeController controller;
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      RevealExampleApp(
        controller: controller,
        preferences: preferences,
        storage: storage,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await controller.flush();
    controller.dispose();
    preferences.dispose();
  }
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _show(
  WidgetTester tester,
  Finder finder, {
  String list = 'playground-scroll',
}) async {
  final scrollable = find
      .descendant(
        of: find.byKey(PageStorageKey(list)),
        matching: find.byType(Scrollable),
      )
      .first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: scrollable,
    maxScrolls: 40,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String id, String label) async {
  final field = find.byKey(ValueKey(id));
  await _show(tester, field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  final popup = find.byType(Scrollable).last;
  tester.state<ScrollableState>(popup).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(
    find.descendant(of: popup, matching: find.text(label)),
    160,
    scrollable: popup,
  );
  final item = find.descendant(of: popup, matching: find.text(label));
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pumpAndSettle();
}

Future<void> _slide(WidgetTester tester, String id, double value) async {
  final slider = find.byKey(ValueKey(id));
  await _show(tester, slider);
  tester.widget<Slider>(slider).onChanged!(value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Home has rich content and preserves workspace, scroll and Navigator across tabs/themes',
    (tester) async {
      final f = _Fixture();
      await f.mount(tester);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Make a little change.'), findsOneWidget);
      expect(find.text('One live application'), findsOneWidget);
      final home = find.byKey(const PageStorageKey('home-scroll'));
      final slider = find.descendant(of: home, matching: find.byType(Slider));
      tester.widget<Slider>(slider).onChanged!(.85);
      await tester.pumpAndSettle();
      final notifications = find.widgetWithText(
        SwitchListTile,
        'Notifications',
      );
      await _show(tester, notifications, list: 'home-scroll');
      await tester.tap(notifications);
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(of: home, matching: find.byType(Scrollable))
          .first;
      final scroll = tester.state<ScrollableState>(scrollable);
      final offset = scroll.position.pixels;
      final navigator = tester.state(find.byType(Navigator));
      for (final tab in ['Playground', 'Integrations', 'Settings']) {
        await _tab(tester, tab);
      }
      await tester.tap(find.widgetWithText(ChoiceChip, 'dark'));
      await tester.pumpAndSettle();
      expect(f.controller.themeMode, ThemeMode.dark);
      await _tab(tester, 'Home');
      expect(tester.widget<SwitchListTile>(notifications).value, isFalse);
      expect(scroll.position.pixels, offset);
      await _show(tester, slider, list: 'home-scroll');
      expect(tester.widget<Slider>(slider).value, .85);
      expect(tester.state(find.byType(Navigator)), same(navigator));
      await tester.scrollUntilVisible(
        find.text('Activity 8'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('Activity 8'), findsOneWidget);
      await f.close(tester);
    },
  );

  testWidgets(
    'Settings compact toggle is in its card, three-state selector and Playground shortcut work',
    (tester) async {
      final f = _Fixture();
      await f.mount(tester);
      await _tab(tester, 'Settings');
      final button = find.byKey(const ValueKey('settings-theme-button'));
      expect(tester.getSize(button), const Size(48, 48));
      expect(
        find.ancestor(of: button, matching: find.byType(Card)),
        findsOneWidget,
      );
      expect(find.byType(FloatingActionButton), findsNothing);
      for (final mode in [ThemeMode.dark, ThemeMode.system, ThemeMode.light]) {
        final chip = find.widgetWithText(ChoiceChip, mode.name);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(f.controller.themeMode, mode);
        expect(find.text('Current mode: ${mode.name}'), findsOneWidget);
        expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
      }
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(f.controller.themeMode, ThemeMode.dark);
      final shortcut = find.byKey(const ValueKey('open-playground'));
      await tester.ensureVisible(shortcut);
      await tester.tap(shortcut);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('playground-theme-button')).hitTestable(),
        findsOneWidget,
      );
      await f.close(tester);
    },
  );

  testWidgets(
    'Persistence lab inspects actual storage, corrupts its key, reloads safe fallback and restores saved mode',
    (tester) async {
      final f = _Fixture();
      await f.mount(tester);
      await _tab(tester, 'Settings');
      await tester.tap(find.widgetWithText(ChoiceChip, 'dark'));
      await tester.pumpAndSettle();
      await _show(
        tester,
        find.byKey(const ValueKey('stored-value')),
        list: 'settings-scroll',
      );
      expect(find.text('Stored value: dark'), findsOneWidget);
      final invalid = find.byKey(const ValueKey('write-invalid'));
      await _show(tester, invalid, list: 'settings-scroll');
      await tester.tap(invalid);
      await tester.pumpAndSettle();
      expect(f.backend.values[f.storage.key], 'invalid-theme-mode');
      expect(find.text('Stored value: invalid-theme-mode'), findsOneWidget);
      expect(f.controller.themeMode, ThemeMode.dark);
      final reload = find.byKey(const ValueKey('reload-storage'));
      await _show(tester, reload, list: 'settings-scroll');
      await tester.tap(reload);
      await tester.pumpAndSettle();
      expect(f.controller.themeMode, ThemeMode.light);
      expect(find.text('Reloaded safely: light'), findsOneWidget);
      expect(await f.storage.read(), isNull);
      f.controller.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(f.backend.values[f.storage.key], 'dark');
      final restored = await RevealThemeController.create(
        defaultMode: ThemeMode.light,
        storage: f.storage,
      );
      expect(restored.themeMode, ThemeMode.dark);
      restored.dispose();
      await f.close(tester);
    },
  );

  testWidgets('Persistence read errors are shown and refresh recovers', (
    tester,
  ) async {
    final f = _Fixture();
    f.backend.failReads = true;
    await f.mount(tester);
    await _tab(tester, 'Settings');
    await _show(
      tester,
      find.byKey(const ValueKey('storage-error')),
      list: 'settings-scroll',
    );
    expect(find.textContaining('Could not read storage'), findsOneWidget);
    f.backend.failReads = false;
    final refresh = find.byKey(const ValueKey('refresh-storage'));
    await _show(tester, refresh, list: 'settings-scroll');
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('storage-error')), findsNothing);
    expect(find.text('Stored value: light'), findsOneWidget);
    f.backend.failReads = true;
    final reload = find.byKey(const ValueKey('reload-storage'));
    await _show(tester, reload, list: 'settings-scroll');
    await tester.tap(reload);
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not reload saved theme'), findsOneWidget);
    await f.close(tester);
  });

  testWidgets(
    'every config field is wired to real theme controls through the Playground',
    (tester) async {
      final f = _Fixture();
      await f.mount(tester);
      await _tab(tester, 'Playground');
      await _pick(tester, 'playground-shape-picker', 'Ellipse');
      await _pick(tester, 'playground-strategy-picker', 'Morph to fullscreen');
      await _slide(tester, 'completion-start', .5);
      await _show(tester, find.byKey(const ValueKey('morph-shortcut')));
      await tester.tap(find.byKey(const ValueKey('morph-shortcut')));
      await tester.pumpAndSettle();
      await _slide(tester, 'duration', 1200);
      await _pick(tester, 'curve', 'Linear');
      await _slide(tester, 'delay', 150);
      await _slide(tester, 'completion-delay', 200);
      await _pick(tester, 'repeat-policy', 'queueLatest');
      await _pick(tester, 'reduced-motion', 'never');
      await _pick(tester, 'origin', 'Normalized');
      await _slide(tester, 'origin-x', .25);
      await _slide(tester, 'origin-y', .75);
      await _slide(tester, 'initial-size', 36);
      await _slide(tester, 'start-rotation', -90);
      await _slide(tester, 'end-rotation', 90);
      await _pick(tester, 'mask-fit', 'fill');
      await _pick(tester, 'alignment', 'Bottom right');
      await _pick(tester, 'edge-color', 'Amber');
      await _slide(tester, 'edge-width', 4);
      await _pick(tester, 'glow-color', 'Pink');
      await _slide(tester, 'glow-radius', 15);
      await _slide(tester, 'feather', 8);
      await _show(tester, find.byKey(const ValueKey('animation-enabled')));
      await tester.tap(find.byKey(const ValueKey('animation-enabled')));
      await tester.pumpAndSettle();
      final c = f.preferences.config;
      expect(c.enabled, isFalse);
      expect(c.duration, const Duration(milliseconds: 1200));
      expect(c.curve, Curves.linear);
      expect(c.delay, const Duration(milliseconds: 150));
      expect(c.completionDelay, const Duration(milliseconds: 200));
      expect(c.initialSize, 36);
      expect(c.startRotation, closeTo(-math.pi / 2, .001));
      expect(c.endRotation, closeTo(math.pi / 2, .001));
      expect(c.maskFit, RevealMaskFit.fill);
      expect(c.alignment, Alignment.bottomRight);
      expect(c.completionStart, .5);
      expect(c.completionStrategy, RevealCompletionStrategy.morphToFullscreen);
      expect(c.morphToFullscreen, isTrue);
      expect(c.repeatPolicy, RevealRepeatPolicy.queueLatest);
      expect(c.reducedMotion, RevealReducedMotion.never);
      expect(c.edgeColor, Colors.amber);
      expect(c.edgeWidth, 4);
      expect(c.glowColor, Colors.pink);
      expect(c.glowRadius, 15);
      expect(c.feather, 8);
      final viewport = tester.renderObject<RenderBox>(
        find.byType(ThemeRevealViewport),
      );
      expect(
        c.origin.resolve(viewport: viewport),
        Offset(viewport.size.width * .25, viewport.size.height * .75),
      );
      for (final button in tester.widgetList<RevealThemeButton>(
        find.byType(RevealThemeButton, skipOffstage: false),
      )) {
        expect(button.animation, same(c));
        expect(button.revealShape, same(f.preferences.shape));
      }
      await _pick(tester, 'edge-color', 'None');
      await _pick(tester, 'glow-color', 'None');
      expect(f.preferences.config.edgeColor, isNull);
      expect(f.preferences.config.glowColor, isNull);
      expect(f.preferences.config.duration, c.duration);
      await f.close(tester);
    },
  );

  testWidgets(
    'all shapes, parameterized origins, six presets and reset are usable and shared',
    (tester) async {
      final f = _Fixture();
      await f.mount(tester);
      await _tab(tester, 'Playground');
      await _show(
        tester,
        find.byKey(const ValueKey('playground-shape-picker')),
      );
      final shape = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(const ValueKey('playground-shape-picker')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(
        shape.items!.map((item) => item.value),
        containsAll(revealShapes.keys),
      );
      expect(shape.items!.length, 15);
      const presetShapes = [
        'Circle',
        'Triangle',
        'Star',
        'PNG',
        'Circle',
        'Circle',
      ];
      const presetDurations = [650, 950, 1000, 900, 650, 250];
      for (final preset in RevealPreferences.presets) {
        final chip = find.byKey(ValueKey('preset-$preset'));
        await _show(tester, chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        final button = tester.widget<RevealThemeButton>(
          find.byKey(const ValueKey('playground-theme-button')),
        );
        expect(button.revealShape, same(f.preferences.shape));
        expect(button.animation, same(f.preferences.config));
        final index = RevealPreferences.presets.indexOf(preset);
        expect(f.preferences.shapeName, presetShapes[index]);
        expect(
          f.preferences.config.duration.inMilliseconds,
          presetDurations[index],
        );
        if (preset == 'Soft Reveal') {
          expect(f.preferences.config.feather, 12);
        }
        if (preset == 'Star Reveal') {
          expect(f.preferences.config.endRotation, math.pi / 4);
        }
      }
      expect(f.preferences.config.duration, const Duration(milliseconds: 250));
      await _pick(tester, 'origin', 'Offset');
      await _slide(tester, 'origin-x', 120);
      await _slide(tester, 'origin-y', 80);
      final viewport = tester.renderObject<RenderBox>(
        find.byType(ThemeRevealViewport),
      );
      expect(
        f.preferences.config.origin.resolve(viewport: viewport),
        const Offset(120, 80),
      );
      await _pick(tester, 'origin', 'Normalized');
      expect(f.preferences.originX, 1);
      expect(f.preferences.originY, 1);
      expect(
        f.preferences.config.origin.resolve(viewport: viewport),
        viewport.size.bottomRight(Offset.zero),
      );
      await _pick(tester, 'origin', 'Keyed marker');
      expect(
        f.preferences.config.origin.resolve(viewport: viewport),
        viewport.globalToLocal(
          tester.getCenter(find.byKey(f.preferences.originKey)),
        ),
      );
      await _pick(tester, 'origin', 'Top end');
      expect(
        f.preferences.config.origin.resolve(
          viewport: viewport,
          textDirection: TextDirection.rtl,
        ),
        Offset.zero,
      );
      final reset = find.byKey(const ValueKey('reset-preferences'));
      await _show(tester, reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(f.preferences.shapeName, 'Circle');
      expect(f.preferences.config.duration, const Duration(milliseconds: 650));
      expect(f.preferences.config.feather, 0);
      expect(f.preferences.config.startRotation, 0);
      expect(f.preferences.config.reducedMotion, RevealReducedMotion.system);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const ValueKey('playground-shape-picker')),
            )
            .initialValue,
        'Circle',
      );
      await f.close(tester);
    },
  );

  testWidgets(
    'Playground and Integrations actions change the live app using shared preferences',
    (tester) async {
      final f = _Fixture();
      await f.mount(tester);
      await _tab(tester, 'Playground');
      await tester.tap(find.byKey(const ValueKey('center-reveal')));
      await tester.pumpAndSettle();
      expect(f.controller.themeMode, ThemeMode.dark);
      await tester.tap(find.byKey(const ValueKey('playground-theme-button')));
      await tester.pumpAndSettle();
      expect(f.controller.themeMode, ThemeMode.light);
      await _tab(tester, 'Integrations');
      expect(find.text('Managed mode'), findsOneWidget);
      expect(find.text('Custom storage'), findsOneWidget);
      final trigger = find.byKey(const ValueKey('custom-theme-trigger'));
      await _show(tester, trigger, list: 'integrations-scroll');
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(f.controller.themeMode, ThemeMode.dark);
      final png = find.byKey(const ValueKey('integration-PNG'));
      await _show(tester, png, list: 'integrations-scroll');
      await tester.tap(png);
      await tester.pumpAndSettle();
      expect(f.preferences.shapeName, 'PNG');
      final programmatic = find.byKey(
        const ValueKey('integration-programmatic'),
      );
      await _show(tester, programmatic, list: 'integrations-scroll');
      f.preferences.selectShape('Triangle');
      await tester.pumpAndSettle();
      await tester.tap(programmatic);
      await tester.pumpAndSettle();
      expect(f.controller.themeMode, ThemeMode.light);
      await _show(
        tester,
        find.byKey(const ValueKey('external-entry-command')),
        list: 'integrations-scroll',
      );
      expect(find.textContaining('external_main.dart'), findsOneWidget);
      await _tab(tester, 'Settings');
      expect(
        tester
            .widget<RevealThemeButton>(
              find.byKey(const ValueKey('settings-theme-button')),
            )
            .revealShape,
        same(f.preferences.shape),
      );
      await f.close(tester);
    },
  );

  testWidgets(
    'external entry drives theme via ValueNotifier and retains state without a package controller',
    (tester) async {
      final preferences = RevealPreferences()
        ..updateConfig(
          const RevealAnimationConfig(
            reducedMotion: RevealReducedMotion.always,
          ),
        );
      await tester.pumpWidget(
        ExternalThemeExampleApp(preferences: preferences),
      );
      await tester.tap(find.byKey(const ValueKey('external-counter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('external-theme-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Current mode: dark'), findsOneWidget);
      expect(find.text('Retained counter: 1'), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(find.byType(RevealThemeBuilder), findsNothing);
      expect(
        tester
            .state<ThemeRevealViewportState>(find.byType(ThemeRevealViewport))
            .debugHasOverlay,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      preferences.dispose();
    },
  );

  testWidgets(
    'responsive navigation preserves tab/config through narrow, wide and scaled text',
    (tester) async {
      final f = _Fixture();
      await tester.binding.setSurfaceSize(const Size(1200, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await f.mount(tester);
      expect(find.byType(NavigationRail), findsOneWidget);
      await _tab(tester, 'Playground');
      f.preferences.selectShape('Diamond');
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(360, 780));
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(find.text('Diamond · 650 ms'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _tab(tester, 'Settings');
      expect(
        find.byKey(const ValueKey('settings-theme-button')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      for (final tab in ['Home', 'Integrations', 'Playground']) {
        await _tab(tester, tab);
        expect(tester.takeException(), isNull);
      }
      await f.close(tester);
    },
  );
}
