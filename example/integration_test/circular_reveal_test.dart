import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';
import 'package:theme_reveal_kit/src/rendering/reveal_painter.dart';
import 'package:theme_reveal_kit_example/app.dart';
import 'package:theme_reveal_kit_example/example_storage.dart';
import 'package:theme_reveal_kit_example/external_main.dart'
    as external_example;
import 'package:theme_reveal_kit_example/reveal_preferences.dart';

class _NativeHostEvents with WidgetsBindingObserver {
  int revision = 0;
  @override
  void didChangeMetrics() {
    revision++;
    debugPrint('Native host metrics changed');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    revision++;
    debugPrint('Native host lifecycle: $state');
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Keep semantics enabled before testWidgets records its handle baseline.
  // A desktop AX client attaching mid-test must not look like a leaked handle.
  setUpAll(() => binding.platformDispatcher.semanticsEnabledTestValue = true);
  tearDownAll(binding.platformDispatcher.clearSemanticsEnabledTestValue);

  if (const bool.fromEnvironment('VERIFY_PERSISTED_THEME')) {
    testWidgets('a separate macOS launch restores the saved light theme', (
      tester,
    ) async {
      final restored = await RevealThemeController.create(
        defaultMode: ThemeMode.dark,
        storage: SharedPrefsThemeStorage(
          key: 'theme_reveal_kit.integration.mode',
        ),
      );
      expect(restored.themeMode, ThemeMode.light);
      await tester.pumpWidget(RevealExampleApp(controller: restored));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.light,
      );
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(find.text('Current mode: light'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      restored.dispose();
    });
    return;
  }

  testWidgets(
    'native capture reveals the live theme at the button and saves it',
    (tester) async {
      final storage = SharedPrefsThemeStorage(
        key: 'theme_reveal_kit.integration.mode',
      );
      await storage.write(ThemeMode.dark);
      final controller = await RevealThemeController.create(storage: storage);
      final screenKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: screenKey,
          child: RevealExampleApp(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('settings-theme-button'));
      final viewport = ThemeRevealViewport.of(tester.element(button));
      final viewportBox = tester.renderObject<RenderBox>(
        find.byType(ThemeRevealViewport),
      );
      final expectedOrigin = viewportBox.globalToLocal(
        tester.getCenter(button),
      );
      final states = <RevealTransitionState>[];
      viewport.transitionState.addListener(
        () => states.add(viewport.transitionState.value),
      );

      Future<List<int>> pixelAt(Offset point) async {
        final boundary =
            screenKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final index = (point.dy.floor() * image.width + point.dx.floor()) * 4;
          return List<int>.generate(
            4,
            (channel) => bytes.getUint8(index + channel),
          );
        } finally {
          image.dispose();
        }
      }

      // A blank area far from the trigger stays old until the cutout reaches it.
      final outside = Offset(12, viewportBox.size.height / 2);
      final inside = expectedOrigin - const Offset(40, 0);
      final oldPixel = await pixelAt(outside);
      final oldInside = await pixelAt(inside);
      await tester.tap(button);
      for (
        var i = 0;
        i < 40 &&
            viewport.transitionState.value != RevealTransitionState.revealing;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 5));
      }
      expect(viewport.transitionState.value, RevealTransitionState.revealing);
      expect(viewport.debugHasSnapshot, isTrue);
      expect(viewport.debugOrigin, expectedOrigin);
      expect(controller.themeMode, ThemeMode.light);
      expect(Theme.of(tester.element(button)).brightness, Brightness.light);
      await tester.pump(); // Establish the ticker's first-frame timestamp.
      await tester.pump(const Duration(milliseconds: 180));
      expect(await pixelAt(outside), oldPixel);
      final revealedInside = await pixelAt(inside);
      expect(revealedInside, isNot(oldInside));
      await tester.pumpAndSettle();
      expect(viewport.transitionState.value, RevealTransitionState.idle);
      expect(viewport.debugHasOverlay, isFalse);
      expect(viewport.debugHasSnapshot, isFalse);
      expect(await pixelAt(outside), isNot(oldPixel));
      expect(await pixelAt(inside), revealedInside);
      expect(
        states,
        containsAllInOrder([
          RevealTransitionState.preparing,
          RevealTransitionState.capturing,
          RevealTransitionState.applyingTheme,
          RevealTransitionState.revealing,
          RevealTransitionState.completing,
          RevealTransitionState.idle,
        ]),
      );
      await controller.flush();
      expect(controller.lastPersistenceError, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      final restored = await RevealThemeController.create(storage: storage);
      expect(restored.themeMode, ThemeMode.light);
      await tester.pumpWidget(RevealExampleApp(controller: restored));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.light,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      restored.dispose();
    },
  );

  testWidgets('native vector/asset picker matrix has no old pixels at completion', (
    tester,
  ) async {
    final hostEvents = _NativeHostEvents();
    WidgetsBinding.instance.addObserver(hostEvents);
    addTearDown(() => WidgetsBinding.instance.removeObserver(hostEvents));
    final controller = RevealThemeController(
      defaultMode: ThemeMode.dark,
      storage: MemoryThemeStorage(),
    );
    final screenKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenKey,
        child: RevealExampleApp(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    final buttonFinder = find.byKey(const ValueKey('settings-theme-button'));
    final viewport = ThemeRevealViewport.of(tester.element(buttonFinder));
    final liveBoundary = tester.renderObject<RenderRepaintBoundary>(
      find
          .descendant(
            of: find.byType(ThemeRevealViewport),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );
    final outerBoundary =
        screenKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

    Future<void> pick(String key, String value) async {
      final field = find.byKey(ValueKey(key));
      if (tester.state<FormFieldState<String>>(field).value == value) return;
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.tap(field);
      await tester.pumpAndSettle();
      final popup = find.byType(Scrollable).last;
      tester.state<ScrollableState>(popup).position.jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(
        find.descendant(of: popup, matching: find.text(value)),
        160,
        scrollable: popup,
      );
      final item = find.descendant(of: popup, matching: find.text(value));
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      await tester.tap(item);
      await tester.pumpAndSettle();
    }

    Future<ui.Image> capture(RenderRepaintBoundary boundary) =>
        boundary.toImage(pixelRatio: 1);
    Future<List<int>> sample(
      RenderRepaintBoundary boundary,
      Offset point,
    ) async {
      final image = await capture(boundary);
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final index = (point.dy.floor() * image.width + point.dx.floor()) * 4;
        return List.generate(4, (channel) => bytes.getUint8(index + channel));
      } finally {
        image.dispose();
      }
    }

    var cases = 0;
    for (final shape in [
      'Circle',
      'Triangle',
      'Star',
      'Heart',
      'Rectangle',
      'Rounded rectangle',
      'Custom path',
      'Icon',
      'SVG',
      'PNG',
      'JSON',
    ]) {
      await pick('shape-picker', shape);
      for (final strategy in [
        'Auto',
        'Preserve shape',
        'Morph to fullscreen',
        'Expand and dissolve',
        'Custom',
      ]) {
        debugPrint('Checking $shape / $strategy');
        await pick('strategy-picker', strategy);
        await tester.ensureVisible(buttonFinder);
        await tester.pumpAndSettle();
        var verified = false;
        for (var attempt = 0; attempt < 4; attempt++) {
          final button = tester.widget<RevealThemeButton>(buttonFinder);
          final checkHole =
              (shape == 'PNG' || shape == 'SVG') && strategy == 'Auto';
          final holePoint =
              liveBoundary.globalToLocal(tester.getCenter(buttonFinder)) +
              const Offset(12, 12);
          final oldHolePixel = checkHole
              ? await sample(outerBoundary, holePoint)
              : null;
          final hostRevision = hostEvents.revision;
          final request = viewport.toggleTheme(
            controller,
            from: tester.element(buttonFinder),
            shape: button.revealShape,
            config: button.animation.copyWith(
              curve: Curves.linear,
              duration: const Duration(milliseconds: 350),
              completionDelay: const Duration(seconds: 2),
            ),
          );
          for (
            var i = 0;
            i < 200 &&
                viewport.transitionState.value !=
                    RevealTransitionState.revealing &&
                viewport.transitionState.value != RevealTransitionState.idle;
            i++
          ) {
            await tester.pump(const Duration(milliseconds: 5));
          }
          if (viewport.transitionState.value == RevealTransitionState.idle &&
              hostEvents.revision != hostRevision) {
            expect(await request, isTrue);
            expect(viewport.debugHasOverlay, isFalse);
            expect(viewport.debugHasSnapshot, isFalse);
            debugPrint('Retrying $shape / $strategy after a host event');
            await tester.pumpAndSettle();
            continue;
          }
          expect(
            viewport.transitionState.value,
            RevealTransitionState.revealing,
            reason: '$shape / $strategy',
          );
          if (shape == 'Custom path' || shape == 'SVG' || shape == 'PNG') {
            expect(
              viewport.debugCompletionStrategy,
              RevealCompletionStrategy.expandAndDissolve,
            );
          }
          if (checkHole) {
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 80));
            final actual = await sample(outerBoundary, holePoint);
            final live = await sample(liveBoundary, holePoint);
            expect(
              actual,
              oldHolePixel,
              reason:
                  '$shape must preserve its transparent center during expansion',
            );
            expect(actual, isNot(live));
          }
          for (
            var i = 0;
            i < 30 &&
                viewport.transitionState.value !=
                    RevealTransitionState.completing;
            i++
          ) {
            await tester.pump(const Duration(milliseconds: 20));
          }
          if (viewport.transitionState.value == RevealTransitionState.idle &&
              hostEvents.revision != hostRevision) {
            expect(await request, isTrue);
            expect(viewport.debugHasOverlay, isFalse);
            expect(viewport.debugHasSnapshot, isFalse);
            debugPrint('Retrying $shape / $strategy after a host event');
            await tester.pumpAndSettle();
            continue;
          }
          expect(
            viewport.transitionState.value,
            RevealTransitionState.completing,
            reason:
                '$shape / $strategy; lifecycle=${WidgetsBinding.instance.lifecycleState}',
          );
          expect(viewport.debugHasOverlay, isTrue);
          final activeMask = tester
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .map((widget) => widget.painter)
              .whereType<RevealPainter>()
              .single
              .alphaMask;
          if (shape == 'Icon' || shape == 'PNG') expect(activeMask, isNotNull);
          final actualImage = await capture(outerBoundary);
          final liveImage = await capture(liveBoundary);
          try {
            final actual = (await actualImage.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final live = (await liveImage.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            expect(actualImage.width, liveImage.width);
            expect(actualImage.height, liveImage.height);
            for (var y = 0; y <= 10; y++) {
              for (var x = 0; x <= 10; x++) {
                final px = (x * (liveImage.width - 1) / 10).floor();
                final py = (y * (liveImage.height - 1) / 10).floor();
                final index = (py * liveImage.width + px) * 4;
                for (var channel = 0; channel < 4; channel++) {
                  expect(
                    actual.getUint8(index + channel),
                    live.getUint8(index + channel),
                    reason: '$shape / $strategy at ($px,$py) channel $channel',
                  );
                }
              }
            }
          } finally {
            actualImage.dispose();
            liveImage.dispose();
          }
          await tester.pumpAndSettle();
          expect(await request, isTrue);
          expect(viewport.debugHasOverlay, isFalse);
          expect(viewport.debugHasSnapshot, isFalse);
          if (activeMask != null) expect(activeMask.debugDisposed, isTrue);
          cases++;
          verified = true;
          break;
        }
        expect(
          verified,
          isTrue,
          reason:
              '$shape / $strategy did not complete without a host interruption',
        );
      }
    }
    expect(cases, 55);
    final errors = <Object>[];
    final failed = viewport.reveal(
      shape: RevealShape.bytes(Uint8List.fromList([1, 2, 3, 4])),
      onThemeChange: controller.toggleTheme,
      onError: (error, _) => errors.add(error),
    );
    for (
      var i = 0;
      i < 100 &&
          viewport.transitionState.value != RevealTransitionState.revealing;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 5));
    }
    expect(viewport.transitionState.value, RevealTransitionState.revealing);
    expect(errors.single, isA<RevealShapeException>());
    expect(
      viewport.debugCompletionStrategy,
      RevealCompletionStrategy.preserveShape,
    );
    await tester.pumpAndSettle();
    expect(await failed, isTrue);
    expect(viewport.debugHasSnapshot, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await controller.flush();
    controller.dispose();
  });
  testWidgets(
    'decorative logo keeps the circle reveal and clears all old pixels',
    (tester) async {
      final controller = RevealThemeController(
        defaultMode: ThemeMode.light,
        storage: MemoryThemeStorage(),
      );
      final screenKey = GlobalKey();
      final logoKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: screenKey,
          child: RevealThemeBuilder(
            controller: controller,
            builder: (context, settings) => MaterialApp(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: settings.themeMode,
              themeAnimationDuration: settings.themeAnimationDuration,
              builder: settings.builder,
              home: Scaffold(
                body: Center(
                  child: RevealThemeButton(
                    controller: controller,
                    logoAnimation: RevealLogoAnimation.rotate,
                    logo: SizedBox(
                      key: logoKey,
                      width: 80,
                      height: 20,
                      child: const ColoredBox(color: Colors.green),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byType(RevealThemeButton);
      final viewport = ThemeRevealViewport.of(tester.element(button));
      final origin = tester.getCenter(button);
      final logoIdentity = identityHashCode(logoKey.currentContext);
      final boundary =
          screenKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      Future<List<int>> pixel(Offset point) async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final index = (point.dy.floor() * image.width + point.dx.floor()) * 4;
          return List.generate(4, (channel) => bytes.getUint8(index + channel));
        } finally {
          image.dispose();
        }
      }

      final outside = const Offset(12, 12);
      final inside = origin + const Offset(40, 0);
      final oldOutside = await pixel(outside);
      final oldInside = await pixel(inside);
      await tester.tap(button);
      for (
        var i = 0;
        i < 100 &&
            viewport.transitionState.value != RevealTransitionState.revealing;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 5));
      }
      expect(viewport.transitionState.value, RevealTransitionState.revealing);
      expect(viewport.debugOrigin, origin);
      expect(identityHashCode(logoKey.currentContext), logoIdentity);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(await pixel(outside), oldOutside);
      expect(await pixel(inside), isNot(oldInside));
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((paint) => paint.painter)
          .whereType<RevealPainter>()
          .single;
      expect(
        painter.cutout.getBounds().width,
        closeTo(painter.cutout.getBounds().height, .001),
      );
      expect(painter.alphaMask, isNull);
      await tester.pumpAndSettle();
      expect(viewport.debugHasOverlay, isFalse);
      expect(viewport.debugHasSnapshot, isFalse);
      expect(await pixel(outside), isNot(oldOutside));
      expect(identityHashCode(logoKey.currentContext), logoIdentity);
      final logo = logoKey.currentContext!.findRenderObject()! as RenderBox;
      final displaySize =
          logo.localToGlobal(const Offset(80, 20)) -
          logo.localToGlobal(Offset.zero);
      expect(displaySize.dx, closeTo(24, .001));
      expect(displaySize.dy, closeTo(6, .001));
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.flush();
      controller.dispose();
    },
  );
  testWidgets(
    'M6 Playground reveals from screen center and real storage rejects invalid values',
    (tester) async {
      final storage = ExampleThemeStorage(
        key: 'theme_reveal_kit.integration.demo',
      );
      await storage.write(ThemeMode.light);
      final controller = await RevealThemeController.create(
        defaultMode: ThemeMode.light,
        storage: storage,
      );
      final preferences = RevealPreferences();
      final screenKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: screenKey,
          child: RevealExampleApp(
            controller: controller,
            storage: storage,
            preferences: preferences,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Playground').last);
      await tester.pumpAndSettle();
      final preset = find.byKey(const ValueKey('preset-Minimal Fast'));
      await tester.ensureVisible(preset);
      await tester.pumpAndSettle();
      await tester.tap(preset);
      await tester.pumpAndSettle();
      final trigger = find.byKey(const ValueKey('center-reveal'));
      final viewport = ThemeRevealViewport.of(tester.element(trigger));
      final box = tester.renderObject<RenderBox>(
        find.byType(ThemeRevealViewport),
      );
      final boundary =
          screenKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      Future<List<int>> sample(Offset point) async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final index = (point.dy.floor() * image.width + point.dx.floor()) * 4;
          return List.generate(4, (channel) => bytes.getUint8(index + channel));
        } finally {
          image.dispose();
        }
      }

      final outside = const Offset(4, 80);
      final old = await sample(outside);
      await tester.tap(trigger);
      for (
        var i = 0;
        i < 100 &&
            viewport.transitionState.value != RevealTransitionState.revealing;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(viewport.transitionState.value, RevealTransitionState.revealing);
      expect(viewport.debugOrigin, box.size.center(Offset.zero));
      expect(preferences.config.duration, const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(controller.themeMode, ThemeMode.dark);
      expect(await sample(outside), isNot(old));
      expect(viewport.debugHasSnapshot, isFalse);
      expect(viewport.debugHasOverlay, isFalse);
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      final invalid = find.byKey(const ValueKey('write-invalid'));
      await tester.ensureVisible(invalid);
      await tester.pumpAndSettle();
      await tester.tap(invalid);
      await tester.pumpAndSettle();
      expect(await storage.readRaw(), 'invalid-theme-mode');
      final reload = find.byKey(const ValueKey('reload-storage'));
      await tester.ensureVisible(reload);
      await tester.pumpAndSettle();
      await tester.tap(reload);
      await tester.pumpAndSettle();
      expect(controller.themeMode, ThemeMode.light);
      expect(find.text('Reloaded safely: light'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.flush();
      controller.dispose();
      preferences.dispose();
    },
  );
  testWidgets(
    'M6 external ValueNotifier entry reveals from its button and retains app state',
    (tester) async {
      final preferences = RevealPreferences();
      preferences.updateConfig(
        const RevealAnimationConfig(duration: Duration(milliseconds: 250)),
      );
      final screenKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: screenKey,
          child: external_example.ExternalThemeExampleApp(
            preferences: preferences,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('external-counter')));
      await tester.pumpAndSettle();
      final trigger = find.byKey(const ValueKey('external-theme-toggle'));
      final viewport = ThemeRevealViewport.of(tester.element(trigger));
      final box = tester.renderObject<RenderBox>(
        find.byType(ThemeRevealViewport),
      );
      final expected = box.globalToLocal(tester.getCenter(trigger));
      final boundary =
          screenKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      Future<List<int>> pixel() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final index = (80 * image.width + 4) * 4;
          return List.generate(4, (channel) => bytes.getUint8(index + channel));
        } finally {
          image.dispose();
        }
      }

      final old = await pixel();
      await tester.tap(trigger);
      for (
        var i = 0;
        i < 100 &&
            viewport.transitionState.value != RevealTransitionState.revealing;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(viewport.transitionState.value, RevealTransitionState.revealing);
      expect(viewport.debugOrigin, expected);
      expect(viewport.debugHasSnapshot, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Current mode: dark'), findsOneWidget);
      expect(find.text('Retained counter: 1'), findsOneWidget);
      expect(await pixel(), isNot(old));
      expect(viewport.debugHasSnapshot, isFalse);
      expect(viewport.debugHasOverlay, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      preferences.dispose();
    },
  );
}
