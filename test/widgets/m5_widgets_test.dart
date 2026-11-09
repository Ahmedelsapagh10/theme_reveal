import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/src/rendering/reveal_painter.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

import '../animation/theme_reveal_viewport_test.dart' show Harness, untilState;

// A Cubit-style state/stream/emit contract, without a state-management package.
class _ThemeCubit {
  ThemeMode state = ThemeMode.light;
  final _changes = StreamController<ThemeMode>();
  Stream<ThemeMode> get stream => _changes.stream;

  Future<void> setThemeMode(ThemeMode mode) async {
    await Future<void>.value();
    state = mode;
    _changes.add(mode);
  }

  Future<void> close() => _changes.close();
}

void main() {
  late ui.Image image;
  setUp(() async => image = await createTestImage(cache: false));
  tearDown(() => image.dispose());

  for (final animation in RevealLogoAnimation.values) {
    testWidgets(
      'decorative logo: $animation, aspect ratio, stable child, circle',
      (tester) async {
        final controller = RevealThemeController(
          defaultMode: ThemeMode.light,
          storage: MemoryThemeStorage(),
        );
        final logoKey = GlobalKey();
        final viewportKey = GlobalKey<ThemeRevealViewportState>();
        await tester.pumpWidget(
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => MaterialApp(
              themeMode: controller.themeMode,
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeAnimationDuration: Duration.zero,
              builder: (context, child) => ThemeRevealViewport(
                key: viewportKey,
                capture: (_, _) async => image.clone(),
                child: child!,
              ),
              home: Scaffold(
                body: Center(
                  child: RevealThemeButton(
                    controller: controller,
                    logoAnimation: animation,
                    logo: SizedBox(key: logoKey, width: 80, height: 20),
                  ),
                ),
              ),
            ),
          ),
        );
        final originalElement = logoKey.currentContext;
        final fitted = tester.renderObject<RenderFittedBox>(
          find.byType(FittedBox),
        );
        final logoBox =
            logoKey.currentContext!.findRenderObject()! as RenderBox;
        final topLeft = logoBox.localToGlobal(Offset.zero);
        final bottomRight = logoBox.localToGlobal(const Offset(80, 20));
        expect(bottomRight - topLeft, const Offset(24, 6));
        expect(fitted.fit, BoxFit.contain);
        expect(find.byType(Icon), findsNothing);
        await tester.tap(find.byType(RevealThemeButton));
        for (
          var i = 0;
          i < 30 &&
              viewportKey.currentState!.transitionState.value !=
                  RevealTransitionState.revealing;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 1));
        }
        expect(
          viewportKey.currentState!.transitionState.value,
          RevealTransitionState.revealing,
        );
        expect(logoKey.currentContext, same(originalElement));
        final logo = find
            .ancestor(
              of: find.byKey(logoKey),
              matching: find.byType(AnimatedBuilder),
            )
            .first;
        if (animation == RevealLogoAnimation.fade) {
          final opacity = tester.widget<Opacity>(
            find.descendant(of: logo, matching: find.byType(Opacity)),
          );
          expect(opacity.opacity, lessThan(1));
        } else if (animation == RevealLogoAnimation.scale ||
            animation == RevealLogoAnimation.rotate) {
          final transform = tester.widget<Transform>(
            find.descendant(of: logo, matching: find.byType(Transform)).first,
          );
          expect(
            transform.transform.storage,
            isNot(orderedEquals(Matrix4.identity().storage)),
          );
        }
        expect(
          tester
              .widget<RevealThemeButton>(find.byType(RevealThemeButton))
              .revealShape,
          const RevealShape.circle(),
        );
        await tester.pumpAndSettle();
        expect(logoKey.currentContext, same(originalElement));
        expect(viewportKey.currentState!.debugHasSnapshot, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await controller.flush();
        controller.dispose();
      },
    );
  }

  testWidgets('busy, disabled, custom border/radius/icons, tooltip and label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = RevealThemeController(
      defaultMode: ThemeMode.light,
      storage: MemoryThemeStorage(),
    );
    const border = Border.fromBorderSide(
      BorderSide(color: Colors.red, width: 3),
    );
    const radius = BorderRadius.all(Radius.circular(7));
    Widget app({bool busy = false, bool enabled = true}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: RevealThemeButton(
            controller: controller,
            busy: busy,
            enabled: enabled,
            tooltip: 'Appearance',
            semanticLabel: 'Choose theme',
            animation: const RevealAnimationConfig(
              reducedMotion: RevealReducedMotion.always,
            ),
            style: const RevealButtonStyle(
              size: 24,
              border: border,
              borderRadius: radius,
              lightIcon: Icons.wb_sunny,
              darkIcon: Icons.nightlight,
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(busy: true));
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      .5,
    );
    expect(
      tester.getSemantics(find.byType(RevealThemeTrigger)),
      matchesSemantics(
        label: 'Choose theme',
        value: 'Busy',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    await tester.tap(find.byType(RevealThemeButton));
    await tester.pumpAndSettle();
    expect(controller.themeMode, ThemeMode.light);
    expect(tester.getSize(find.byType(RevealThemeButton)), const Size(48, 48));
    await tester.pumpWidget(app(enabled: false));
    await tester.pumpAndSettle();
    final icon = tester.widget<Icon>(find.byIcon(Icons.wb_sunny));
    expect(
      icon.color,
      Theme.of(tester.element(find.byType(RevealThemeButton))).disabledColor,
    );
    final container = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(RevealThemeButton),
            matching: find.byType(Container),
          ),
        )
        .single;
    expect((container.decoration! as BoxDecoration).border, border);
    expect((container.decoration! as BoxDecoration).borderRadius, radius);
    await tester.tap(find.byType(RevealThemeButton));
    await tester.pumpAndSettle();
    expect(controller.themeMode, ThemeMode.light);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(RevealThemeButton));
    await tester.pump();
    expect(find.text('Appearance'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(RevealThemeButton));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.nightlight), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await controller.flush();
    controller.dispose();
    semantics.dispose();
  });

  testWidgets(
    'becoming busy during a press releases the pressed state safely',
    (tester) async {
      final controller = RevealThemeController(
        defaultMode: ThemeMode.light,
        storage: MemoryThemeStorage(),
      );
      final busy = ValueNotifier(false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: busy,
                builder: (context, value, _) =>
                    RevealThemeButton(controller: controller, busy: value),
              ),
            ),
          ),
        ),
      );
      final pointer = await tester.startGesture(
        tester.getCenter(find.byType(RevealThemeButton)),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        .92,
      );
      busy.value = true;
      await tester.pump();
      expect(tester.takeException(), isNull);
      await pointer.up();
      await tester.pump();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      expect(controller.themeMode, ThemeMode.light);
      await tester.pumpWidget(const SizedBox.shrink());
      busy.dispose();
      controller.dispose();
    },
  );

  for (final systemReduced in [false, true]) {
    for (final mode in RevealReducedMotion.values) {
      testWidgets(
        'logo and busy reduced motion: $mode / system $systemReduced',
        (tester) async {
          final controller = RevealThemeController(
            defaultMode: ThemeMode.light,
            storage: MemoryThemeStorage(),
          );
          final reduced =
              mode == RevealReducedMotion.always ||
              (mode == RevealReducedMotion.system && systemReduced);
          Widget app({bool busy = false}) => MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: systemReduced),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: RevealThemeButton(
                  controller: controller,
                  busy: busy,
                  animation: RevealAnimationConfig(reducedMotion: mode),
                  logoAnimation: RevealLogoAnimation.fade,
                  logo: const SizedBox(width: 80, height: 20),
                ),
              ),
            ),
          );
          await tester.pumpWidget(app());
          controller.toggleTheme();
          await tester.pump();
          final fade = find.descendant(
            of: find.byType(RevealThemeButton),
            matching: find.byType(Opacity),
          );
          expect(tester.widget<Opacity>(fade).opacity, reduced ? 1 : 0);
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            tester.widget<Opacity>(fade).opacity,
            reduced ? 1 : closeTo(.5, .01),
          );
          await tester.pumpAndSettle();
          await tester.pumpWidget(app(busy: true));
          expect(
            tester
                .widget<CircularProgressIndicator>(
                  find.byType(CircularProgressIndicator),
                )
                .value,
            reduced ? .5 : null,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await controller.flush();
          controller.dispose();
        },
      );

      testWidgets(
        'button and engine reduced motion: $mode / system $systemReduced',
        (tester) async {
          final harness = Harness(image);
          final config = RevealAnimationConfig(reducedMotion: mode);
          final reduced =
              mode == RevealReducedMotion.always ||
              (mode == RevealReducedMotion.system && systemReduced);
          await harness.mount(
            tester,
            disableAnimations: systemReduced,
            config: config,
          );
          expect(
            tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
            reduced ? Duration.zero : const Duration(milliseconds: 120),
          );
          expect(
            tester
                .widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
                .duration,
            reduced ? Duration.zero : const Duration(milliseconds: 200),
          );
          await tester.tap(find.byType(RevealThemeButton));
          await tester.pumpAndSettle();
          expect(harness.controller.themeMode, ThemeMode.dark);
          expect(harness.captures, reduced ? 0 : 1);
          expect(harness.engine.debugHasOverlay, isFalse);
          expect(harness.engine.debugHasSnapshot, isFalse);
          await harness.close(tester);
        },
      );
    }
  }

  testWidgets(
    'RTL, text scaling, high contrast, theme-dependent screen-reader labels',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = RevealThemeController(
        defaultMode: ThemeMode.light,
        storage: MemoryThemeStorage(),
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(highContrast: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final colors = ColorScheme.fromSeed(seedColor: Colors.yellow).copyWith(
        primaryContainer: Colors.black,
        onPrimaryContainer: Colors.white,
      );
      await tester.pumpWidget(
        MaterialApp(
          highContrastTheme: ThemeData(colorScheme: colors),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(3)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          ),
          home: Scaffold(
            body: Column(
              children: [
                RevealThemeButton(controller: controller),
                RevealThemeTrigger(
                  controller: controller,
                  child: const Text('Custom theme control'),
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        Directionality.of(tester.element(find.byType(RevealThemeButton))),
        TextDirection.rtl,
      );
      final button = find.byType(RevealThemeTrigger).first;
      expect(tester.getSemantics(button).label, 'Switch to dark theme');
      expect(tester.widget<Icon>(find.byType(Icon)).color, Colors.white);
      expect(
        tester.getSize(find.byType(RevealThemeButton)),
        const Size(48, 48),
      );
      expect(tester.getSize(find.byType(Text)).height, greaterThan(30));
      await tester.tap(find.byType(RevealThemeButton));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(button).label, 'Switch to light theme');
      expect(
        tester.widget<Tooltip>(find.byType(Tooltip)).message,
        'Switch to light theme',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await controller.flush();
      controller.dispose();
      semantics.dispose();
    },
  );

  testWidgets(
    'custom interactive child: one tap, gesture origin, keyboard center, semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final harness = Harness(image);
      var childTaps = 0;
      await harness.mount(
        tester,
        child: Scaffold(
          body: Center(
            child: RevealThemeTrigger(
              controller: harness.controller,
              animation: const RevealAnimationConfig(
                origin: RevealOrigin.gesture(),
              ),
              child: ElevatedButton(
                onPressed: () => childTaps++,
                child: const Text('Decorative child'),
              ),
            ),
          ),
        ),
      );
      final trigger = find.byType(RevealThemeTrigger);
      final point = tester.getTopLeft(trigger) + const Offset(8, 8);
      await tester.tapAt(point);
      await untilState(tester, harness, RevealTransitionState.revealing);
      expect(harness.engine.debugOrigin, point);
      await tester.pumpAndSettle();
      expect(childTaps, 0);
      expect(harness.controller.themeMode, ThemeMode.dark);
      final focus = tester
          .widget<FocusableActionDetector>(
            find.byType(FocusableActionDetector).first,
          )
          .focusNode!;
      focus.requestFocus();
      await tester.pump();
      for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
        await tester.sendKeyEvent(key);
        await untilState(tester, harness, RevealTransitionState.revealing);
        expect(harness.engine.debugOrigin, tester.getCenter(trigger));
        await tester.pumpAndSettle();
      }
      expect(harness.captures, 3);
      expect(childTaps, 0);
      expect(tester.getSemantics(trigger).label, 'Switch to light theme');
      expect(find.bySemanticsLabel('Decorative child'), findsNothing);
      final node = tester.getSemantics(trigger);
      tester.binding.performSemanticsAction(
        ui.SemanticsActionEvent(
          viewId: tester.view.viewId,
          nodeId: node.id,
          type: ui.SemanticsAction.tap,
        ),
      );
      await tester.pumpAndSettle();
      expect(harness.controller.themeMode, ThemeMode.light);
      expect(harness.captures, 4);
      await harness.close(tester);
      semantics.dispose();
    },
  );

  testWidgets(
    'external Cubit-style state waits for emission and reveals live app',
    (tester) async {
      final cubit = _ThemeCubit();
      final viewportKey = GlobalKey<ThemeRevealViewportState>();
      final routeKey = GlobalKey();
      final gate = Completer<void>();
      await tester.pumpWidget(
        StreamBuilder<ThemeMode>(
          initialData: cubit.state,
          stream: cubit.stream,
          builder: (context, snapshot) => MaterialApp(
            themeMode: snapshot.data,
            themeAnimationDuration: Duration.zero,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            builder: (context, child) => ThemeRevealViewport(
              key: viewportKey,
              capture: (_, _) async => image.clone(),
              child: child!,
            ),
            home: Scaffold(key: routeKey, body: const Text('External app')),
          ),
        ),
      );
      final routeElement = routeKey.currentContext;
      final viewport = viewportKey.currentState!;
      final request = viewport.reveal(
        from: routeKey.currentContext,
        globalPosition: const Offset(70, 90),
        shape: const RevealShape.triangle(),
        config: const RevealAnimationConfig(origin: RevealOrigin.gesture()),
        onThemeChange: () async {
          await gate.future;
          await cubit.setThemeMode(ThemeMode.dark);
        },
      );
      await tester.pumpAndSettle();
      expect(
        viewport.transitionState.value,
        RevealTransitionState.applyingTheme,
      );
      expect(viewport.debugHasOverlay, isTrue);
      expect(cubit.state, ThemeMode.light);
      gate.complete();
      for (
        var i = 0;
        i < 30 &&
            viewport.transitionState.value != RevealTransitionState.revealing;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(viewport.transitionState.value, RevealTransitionState.revealing);
      expect(Theme.of(routeKey.currentContext!).brightness, Brightness.dark);
      expect(viewport.debugOrigin, const Offset(70, 90));
      expect(routeKey.currentContext, same(routeElement));
      await tester.pumpAndSettle();
      expect(await request, isTrue);
      expect(viewport.debugHasSnapshot, isFalse);
      expect(viewport.debugHasOverlay, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(cubit.close());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'no-option button produces a circular cutout with original defaults',
    (tester) async {
      final harness = Harness(image);
      await harness.mount(
        tester,
        child: Scaffold(
          body: Center(
            child: RevealThemeButton(controller: harness.controller),
          ),
        ),
      );
      await tester.tap(find.byType(RevealThemeButton));
      await untilState(tester, harness, RevealTransitionState.revealing);
      await tester.pump(); // Establish the ticker's first-frame timestamp.
      await tester.pump(const Duration(milliseconds: 100));
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .whereType<RevealPainter>()
          .single;
      final bounds = painter.cutout.getBounds();
      expect(bounds.width, greaterThan(0));
      expect(bounds.width, closeTo(bounds.height, .001));
      expect(bounds.center, harness.engine.debugOrigin);
      final radius = bounds.width / 2;
      for (var i = 0; i < 16; i++) {
        final direction = Offset(
          math.cos(i * math.pi / 8),
          math.sin(i * math.pi / 8),
        );
        expect(
          painter.cutout.contains(bounds.center + direction * (radius * .99)),
          isTrue,
        );
        expect(
          painter.cutout.contains(bounds.center + direction * (radius * 1.01)),
          isFalse,
        );
      }
      expect(painter.alphaMask, isNull);
      expect(
        harness.engine.debugCompletionStrategy,
        RevealCompletionStrategy.preserveShape,
      );
      await tester.pumpAndSettle();
      await harness.close(tester);
    },
  );
}
