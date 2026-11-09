import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/src/rendering/reveal_painter.dart';
import 'package:theme_reveal_kit/src/rendering/scene_capture.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';
import '../support/mask_fixtures.dart';

class _PendingMaskBundle extends CachingAssetBundle {
  final gate = Completer<ByteData>();
  @override
  Future<ByteData> load(String key) => gate.future;
}

class Harness {
  Harness(this.image);
  final ui.Image image;
  final key = GlobalKey<ThemeRevealViewportState>();
  final buttonKey = GlobalKey();
  final fieldKey = GlobalKey();
  final controller = RevealThemeController(
    defaultMode: ThemeMode.light,
    storage: MemoryThemeStorage(),
  );
  final errors = <Object>[];
  final snapshots = <ui.Image>[];
  int captures = 0;
  double? ratio;
  ThemeRevealViewportState get engine => key.currentState!;

  Future<void> mount(
    WidgetTester tester, {
    RevealCapture? capture,
    RevealAnimationConfig config = const RevealAnimationConfig(),
    RevealShape shape = const RevealShape.circle(),
    bool disableAnimations = false,
    double dpr = 1,
    Widget? child,
  }) async {
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
          themeMode: controller.themeMode,
          themeAnimationDuration: Duration.zero,
          theme: ThemeData(brightness: Brightness.light),
          darkTheme: ThemeData(brightness: Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: disableAnimations,
              devicePixelRatio: dpr,
            ),
            child: ThemeRevealViewport(
              key: key,
              onError: (error, _) => errors.add(error),
              capture:
                  capture ??
                  (boundary, pixelRatio) async {
                    captures++;
                    ratio = pixelRatio;
                    final clone = image.clone();
                    snapshots.add(clone);
                    return clone;
                  },
              child: child!,
            ),
          ),
          home:
              child ??
              Scaffold(
                body: Column(
                  children: [
                    TextField(key: fieldKey),
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: RevealThemeButton(
                          key: buttonKey,
                          controller: controller,
                          animation: config,
                          revealShape: shape,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await controller.flush();
    controller.dispose();
  }
}

Future<void> untilState(
  WidgetTester tester,
  Harness harness,
  RevealTransitionState state,
) async {
  for (
    var i = 0;
    i < 30 && harness.engine.transitionState.value != state;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(harness.engine.transitionState.value, state);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image image;
  setUp(() async => image = await createTestImage(cache: false));
  tearDown(() => image.dispose());

  testWidgets(
    'ordered frames, both directions, real theme, pointer blocking, cleanup',
    (tester) async {
      final harness = Harness(image);
      await harness.mount(tester, dpr: 4);
      final states = <RevealTransitionState>[];
      harness.engine.transitionState.addListener(
        () => states.add(harness.engine.transitionState.value),
      );
      for (final mode in [ThemeMode.dark, ThemeMode.light]) {
        final previous = harness.controller.themeMode;
        final request = harness.engine.toggleTheme(
          harness.controller,
          from: harness.buttonKey.currentContext,
        );
        await untilState(tester, harness, RevealTransitionState.capturing);
        expect(harness.controller.themeMode, previous);
        await tester.pump();
        expect(harness.engine.debugHasOverlay, isTrue);
        expect(harness.controller.themeMode, mode);
        expect(harness.engine.debugHasOverlay, isTrue);
        expect(
          harness.engine.transitionState.value,
          RevealTransitionState.applyingTheme,
        );
        await untilState(tester, harness, RevealTransitionState.revealing);
        expect(
          Theme.of(harness.buttonKey.currentContext!).brightness,
          mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        expect(
          harness.engine.debugOrigin,
          tester.getCenter(find.byType(RevealThemeButton)),
        );
        await tester.tap(find.byType(RevealThemeButton), warnIfMissed: false);
        expect(harness.controller.themeMode, mode);
        await tester.pumpAndSettle();
        expect(await request, isTrue);
        expect(harness.engine.debugHasOverlay, isFalse);
        expect(harness.engine.debugHasSnapshot, isFalse);
        expect(harness.snapshots.last.debugDisposed, isTrue);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint && widget.painter is RevealPainter,
          ),
          findsNothing,
        );
      }
      expect(harness.ratio, 3);
      expect(states, [
        for (var i = 0; i < 2; i++) ...[
          RevealTransitionState.preparing,
          RevealTransitionState.capturing,
          RevealTransitionState.applyingTheme,
          RevealTransitionState.revealing,
          RevealTransitionState.completing,
          RevealTransitionState.idle,
        ],
      ]);
      expect(harness.errors, isEmpty);
      await harness.close(tester);
    },
  );

  testWidgets('ignore rejects repeated requests before any work', (
    tester,
  ) async {
    final harness = Harness(image);
    await harness.mount(tester);
    final first = harness.engine.toggleTheme(harness.controller);
    final ignored = harness.engine.toggleTheme(harness.controller);
    expect(await ignored, isFalse);
    await tester.pumpAndSettle();
    expect(await first, isTrue);
    expect(harness.captures, 1);
    expect(harness.controller.themeMode, ThemeMode.dark);
    await harness.close(tester);
  });

  testWidgets('queueLatest supersedes the pending request and runs the last', (
    tester,
  ) async {
    final harness = Harness(image);
    await harness.mount(tester);
    const queue = RevealAnimationConfig(
      repeatPolicy: RevealRepeatPolicy.queueLatest,
    );
    final calls = <String>[];
    final first = harness.engine.reveal(
      onThemeChange: () => calls.add('first'),
    );
    final discarded = harness.engine.reveal(
      config: queue,
      onThemeChange: () => calls.add('discarded'),
    );
    final last = harness.engine.reveal(
      config: queue,
      onThemeChange: () => calls.add('last'),
    );
    expect(await discarded, isFalse);
    await tester.pumpAndSettle();
    expect(await first, isTrue);
    expect(await last, isTrue);
    expect(calls, ['first', 'last']);
    expect(harness.captures, 2);
    expect(harness.snapshots.every((image) => image.debugDisposed), isTrue);
    await harness.close(tester);
  });

  testWidgets(
    'idle listeners cannot start a parallel reveal beside queued work',
    (tester) async {
      final harness = Harness(image);
      await harness.mount(tester);
      final calls = <String>[];
      Future<bool>? reentrant;
      harness.engine.transitionState.addListener(() {
        if (harness.engine.transitionState.value ==
                RevealTransitionState.idle &&
            reentrant == null) {
          reentrant = harness.engine.reveal(
            onThemeChange: () => calls.add('parallel'),
          );
        }
      });
      final first = harness.engine.reveal(
        onThemeChange: () => calls.add('first'),
      );
      final queued = harness.engine.reveal(
        config: const RevealAnimationConfig(
          repeatPolicy: RevealRepeatPolicy.queueLatest,
        ),
        onThemeChange: () => calls.add('queued'),
      );
      await tester.pumpAndSettle();
      expect(await first, isTrue);
      expect(await queued, isTrue);
      expect(await reentrant, isFalse);
      expect(calls, ['first', 'queued']);
      expect(harness.captures, 2);
      await harness.close(tester);
    },
  );

  testWidgets(
    'disposal during animation frees image and rejects pending work',
    (tester) async {
      final harness = Harness(image);
      await harness.mount(tester);
      final first = harness.engine.toggleTheme(harness.controller);
      await untilState(tester, harness, RevealTransitionState.revealing);
      final queued = harness.engine.reveal(
        config: const RevealAnimationConfig(
          repeatPolicy: RevealRepeatPolicy.queueLatest,
        ),
        onThemeChange: () => fail('disposed queue ran'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(await first, isTrue);
      expect(await queued, isFalse);
      expect(harness.snapshots.single.debugDisposed, isTrue);
      expect(tester.takeException(), isNull);
      await harness.controller.flush();
      harness.controller.dispose();
    },
  );

  testWidgets('disposal during asynchronous capture disposes a late image', (
    tester,
  ) async {
    final harness = Harness(image);
    final capture = Completer<ui.Image>();
    var started = false;
    await harness.mount(
      tester,
      capture: (_, _) {
        started = true;
        return capture.future;
      },
    );
    final first = harness.engine.toggleTheme(harness.controller);
    for (var i = 0; !started && i < 10; i++) {
      await tester.pump();
    }
    expect(started, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(await first, isFalse);
    final lateImage = image.clone();
    capture.complete(lateImage);
    await tester.pump();
    expect(lateImage.debugDisposed, isTrue);
    expect(harness.controller.themeMode, ThemeMode.light);
    harness.controller.dispose();
  });

  testWidgets(
    'disposal while waiting for an external callback cannot retain snapshot',
    (tester) async {
      final harness = Harness(image);
      final callback = Completer<void>();
      await harness.mount(tester);
      final first = harness.engine.reveal(onThemeChange: () => callback.future);
      await untilState(tester, harness, RevealTransitionState.applyingTheme);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(await first, isFalse);
      expect(harness.snapshots.single.debugDisposed, isTrue);
      callback.complete();
      await tester.pump();
      harness.controller.dispose();
    },
  );

  testWidgets(
    'capture failure applies instantly, reports, and unlocks engine',
    (tester) async {
      final harness = Harness(image);
      final failure = StateError('capture unsupported');
      await harness.mount(tester, capture: (_, _) async => throw failure);
      final request = harness.engine.toggleTheme(harness.controller);
      await tester.pumpAndSettle();
      expect(await request, isTrue);
      expect(harness.controller.themeMode, ThemeMode.dark);
      expect(harness.errors, [failure]);
      expect(harness.engine.isBusy, isFalse);
      expect(harness.engine.debugHasOverlay, isFalse);
      expect(harness.engine.debugHasSnapshot, isFalse);
      await harness.close(tester);
    },
  );

  testWidgets('theme callback failure runs once and removes the old frame', (
    tester,
  ) async {
    final harness = Harness(image);
    await harness.mount(tester);
    var calls = 0;
    final request = harness.engine.reveal(
      onThemeChange: () {
        calls++;
        throw StateError('state update failed');
      },
    );
    await tester.pumpAndSettle();
    expect(await request, isFalse);
    expect(calls, 1);
    expect(harness.errors, hasLength(1));
    expect(harness.engine.debugHasOverlay, isFalse);
    expect(harness.snapshots.single.debugDisposed, isTrue);
    await harness.close(tester);
  });

  testWidgets('resize aborts animation without waiting for its duration', (
    tester,
  ) async {
    final harness = Harness(image);
    await harness.mount(tester);
    final request = harness.engine.toggleTheme(
      harness.controller,
      config: const RevealAnimationConfig(duration: Duration(minutes: 1)),
    );
    await untilState(tester, harness, RevealTransitionState.revealing);
    tester.view.physicalSize = const Size(700, 900);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pump();
    expect(await request, isTrue);
    expect(harness.engine.debugHasOverlay, isFalse);
    expect(harness.engine.debugHasSnapshot, isFalse);
    expect(harness.snapshots.single.debugDisposed, isTrue);
    expect(harness.controller.themeMode, ThemeMode.dark);
    await harness.close(tester);
  });

  testWidgets(
    'metrics change during capture applies instantly and releases late capture',
    (tester) async {
      final harness = Harness(image);
      final capture = Completer<ui.Image>();
      var started = false;
      await harness.mount(
        tester,
        capture: (_, _) {
          started = true;
          return capture.future;
        },
      );
      final request = harness.engine.toggleTheme(harness.controller);
      for (var i = 0; !started && i < 10; i++) {
        await tester.pump();
      }
      expect(started, isTrue);
      harness.engine.didChangeMetrics();
      await tester.pump();
      expect(await request, isTrue);
      expect(harness.controller.themeMode, ThemeMode.dark);
      final lateImage = image.clone();
      capture.complete(lateImage);
      await tester.pump();
      expect(lateImage.debugDisposed, isTrue);
      await harness.close(tester);
    },
  );

  for (final policy in RevealReducedMotion.values) {
    testWidgets('reduced motion $policy with system preference', (
      tester,
    ) async {
      final harness = Harness(image);
      await harness.mount(tester, disableAnimations: true);
      final request = harness.engine.toggleTheme(
        harness.controller,
        config: RevealAnimationConfig(reducedMotion: policy),
      );
      await tester.pumpAndSettle();
      expect(await request, isTrue);
      expect(harness.captures, policy == RevealReducedMotion.never ? 1 : 0);
      expect(harness.controller.themeMode, ThemeMode.dark);
      await harness.close(tester);
    });
  }

  testWidgets(
    'disabled and zero duration skip capture; delays are cancellable',
    (tester) async {
      final harness = Harness(image);
      await harness.mount(tester);
      for (final config in [
        const RevealAnimationConfig(enabled: false),
        const RevealAnimationConfig(duration: Duration.zero),
      ]) {
        final request = harness.engine.toggleTheme(
          harness.controller,
          config: config,
        );
        await tester.pumpAndSettle();
        expect(await request, isTrue);
      }
      expect(harness.captures, 0);
      final delayed = harness.engine.toggleTheme(
        harness.controller,
        config: const RevealAnimationConfig(delay: Duration(minutes: 1)),
      );
      harness.engine.didChangeMetrics();
      await tester.pumpAndSettle();
      expect(await delayed, isTrue);
      expect(harness.captures, 0);
      await harness.close(tester);
    },
  );

  testWidgets(
    'navigator, focus, text, and widget state survive a real theme change',
    (tester) async {
      final harness = Harness(image);
      await harness.mount(tester);
      final navigator = tester.state(find.byType(Navigator));
      final fieldState = tester.state(find.byKey(harness.fieldKey));
      await tester.enterText(find.byType(TextField), 'still here');
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      final focus = editable.focusNode;
      expect(focus.hasFocus, isTrue);
      final request = harness.engine.toggleTheme(harness.controller);
      await tester.pumpAndSettle();
      expect(await request, isTrue);
      expect(tester.state(find.byType(Navigator)), same(navigator));
      expect(tester.state(find.byKey(harness.fieldKey)), same(fieldState));
      expect(find.text('still here'), findsOneWidget);
      expect(focus.hasFocus, isTrue);
      await harness.close(tester);
    },
  );

  testWidgets(
    'invalid vector masks report once and animate the circle fallback',
    (tester) async {
      final harness = Harness(image);
      await harness.mount(tester);
      final request = harness.engine.reveal(
        shape: RevealShape.customPath(builder: (_) => Path()),
        onThemeChange: harness.controller.toggleTheme,
      );
      await untilState(tester, harness, RevealTransitionState.revealing);
      expect(harness.errors.single, isA<RevealShapeException>());
      expect(
        harness.engine.debugCompletionStrategy,
        RevealCompletionStrategy.preserveShape,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .whereType<RevealPainter>()
          .single;
      expect(painter.cutout.getBounds().width, greaterThan(0));
      expect(
        painter.cutout.getBounds().width,
        closeTo(painter.cutout.getBounds().height, .001),
      );
      await tester.pumpAndSettle();
      expect(await request, isTrue);
      expect(harness.snapshots.single.debugDisposed, isTrue);
      await harness.close(tester);
    },
  );

  testWidgets(
    'ring switches even explicit morph/custom strategies to dissolve',
    (tester) async {
      final harness = Harness(image);
      await harness.mount(tester);
      final ring = RevealShape.customPath(
        builder: (_) => Path()
          ..fillType = PathFillType.evenOdd
          ..addOval(const Rect.fromLTWH(-50, -50, 100, 100))
          ..addOval(const Rect.fromLTWH(-20, -20, 40, 40)),
      );
      for (final strategy in [
        RevealCompletionStrategy.auto,
        RevealCompletionStrategy.preserveShape,
        RevealCompletionStrategy.morphToFullscreen,
        RevealCompletionStrategy.custom(
          (path, progress, viewport, origin) => path,
        ),
      ]) {
        final request = harness.engine.reveal(
          shape: ring,
          config: RevealAnimationConfig(completionStrategy: strategy),
          onThemeChange: harness.controller.toggleTheme,
        );
        await untilState(tester, harness, RevealTransitionState.revealing);
        expect(
          harness.engine.debugCompletionStrategy,
          RevealCompletionStrategy.expandAndDissolve,
        );
        await tester.pumpAndSettle();
        expect(await request, isTrue);
        expect(harness.engine.debugHasSnapshot, isFalse);
      }
      expect(harness.errors, isEmpty);
      await harness.close(tester);
    },
  );

  testWidgets('custom completion failure reports once and finishes safely', (
    tester,
  ) async {
    final harness = Harness(image);
    await harness.mount(tester);
    var calls = 0;
    final request = harness.engine.reveal(
      config: RevealAnimationConfig(
        completionStrategy: RevealCompletionStrategy.custom((
          path,
          progress,
          viewport,
          origin,
        ) {
          calls++;
          throw StateError('bad custom completion');
        }),
      ),
      onThemeChange: harness.controller.toggleTheme,
    );
    await tester.pumpAndSettle();
    expect(await request, isTrue);
    expect(calls, 1);
    expect(harness.errors, hasLength(1));
    expect(harness.engine.debugHasOverlay, isFalse);
    expect(harness.snapshots.single.debugDisposed, isTrue);
    await harness.close(tester);
  });

  testWidgets('button and trigger forward the vector shape and animation', (
    tester,
  ) async {
    final harness = Harness(image);
    var resolutions = 0;
    var completions = 0;
    await harness.mount(
      tester,
      shape: RevealShape.customPath(
        builder: (_) {
          resolutions++;
          return Path()..addRect(const Rect.fromLTWH(0, 0, 100, 50));
        },
      ),
      config: RevealAnimationConfig(
        maskFit: RevealMaskFit.fill,
        startRotation: -.2,
        endRotation: .6,
        alignment: const Alignment(.1, -.1),
        completionStrategy: RevealCompletionStrategy.custom((
          path,
          progress,
          viewport,
          origin,
        ) {
          completions++;
          expect(viewport, const Size(800, 600));
          expect(origin, tester.getCenter(find.byType(RevealThemeButton)));
          return path;
        }),
      ),
    );
    await tester.tap(find.byType(RevealThemeButton));
    await tester.pumpAndSettle();
    expect(resolutions, 1);
    expect(completions, greaterThan(1));
    expect(harness.controller.themeMode, ThemeMode.dark);
    expect(harness.errors, isEmpty);
    await harness.close(tester);
  });

  testWidgets(
    'cached raster survives eviction while active, then its retained handle disposes',
    (tester) async {
      final bytes = (await tester.runAsync(
        () => pngFixture(
          16,
          16,
          (canvas) => canvas.drawColor(Colors.white, BlendMode.src),
        ),
      ))!;
      final shape = RevealShape.bytes(bytes);
      final cached = (await tester.runAsync(shape.resolveAsync))!;
      final harness = Harness(image);
      await harness.mount(tester);
      final request = harness.engine.reveal(
        shape: shape,
        onThemeChange: harness.controller.toggleTheme,
      );
      await untilState(tester, harness, RevealTransitionState.revealing);
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .whereType<RevealPainter>()
          .single;
      final handle = painter.alphaMask!;
      expect(handle.debugDisposed, isFalse);
      RevealShape.clearCache();
      expect(cached.alphaImage!.debugDisposed, isTrue);
      expect(handle.debugDisposed, isFalse);
      await tester.pumpAndSettle();
      expect(await request, isTrue);
      expect(handle.debugDisposed, isTrue);
      expect(harness.snapshots.single.debugDisposed, isTrue);
      await harness.close(tester);
    },
  );

  testWidgets(
    'disposal during asset loading cancels the request and does not retain a late mask',
    (tester) async {
      final bytes = Uint8List.fromList(
        utf8.encode(
          '<svg viewBox="0 0 10 10"><rect width="10" height="10"/></svg>',
        ),
      );
      final bundle = _PendingMaskBundle();
      final shape = RevealShape.svgAsset('late.svg', bundle: bundle);
      final harness = Harness(image);
      await harness.mount(tester);
      final request = harness.engine.reveal(
        shape: shape,
        onThemeChange: harness.controller.toggleTheme,
      );
      await tester.pump();
      expect(
        harness.engine.transitionState.value,
        RevealTransitionState.preparing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(await request, isFalse);
      bundle.gate.complete(ByteData.sublistView(bytes));
      await tester.pump();
      final resolved = await shape.resolveAsync();
      expect(harness.captures, 0);
      expect(harness.controller.themeMode, ThemeMode.light);
      RevealShape.clearCache();
      expect(resolved.isRaster, isFalse);
      harness.controller.dispose();
    },
  );
}
