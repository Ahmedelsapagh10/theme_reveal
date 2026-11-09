import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../controller/reveal_theme_controller.dart';
import '../rendering/reveal_geometry.dart';
import '../rendering/reveal_composition.dart';
import '../rendering/reveal_painter.dart';
import '../rendering/scene_capture.dart';
import '../shapes/reveal_shape.dart';
import '../utils/reveal_exception.dart';
import 'reveal_animation_config.dart';
import 'reveal_completion_strategy.dart';
import 'transition_state.dart';

/// Applies a new theme; its future must complete after the new state is emitted.
typedef RevealThemeChange = FutureOr<void> Function();

/// Install around the child supplied to MaterialApp.builder, above Navigator.
/// The live subtree remains in one RepaintBoundary for the viewport's lifetime.
///
/// ```dart
/// // Use your existing mode and state update; keep the update inside onThemeChange.
/// MaterialApp(
///   theme: ThemeData.light(),
///   darkTheme: ThemeData.dark(),
///   themeMode: mode,
///   themeAnimationDuration: Duration.zero,
///   builder: (context, child) => ThemeRevealViewport(child: child!),
///   home: home,
/// )
/// ```
class ThemeRevealViewport extends StatefulWidget {
  /// Wraps the MaterialApp.builder child in the permanent snapshot boundary.
  const ThemeRevealViewport({
    super.key,
    required this.child,
    this.onError,
    @visibleForTesting this.capture = captureRevealScene,
  });

  /// Live application subtree; never moved into the temporary overlay.
  final Widget child;

  /// Default error listener for shape, capture and callback failures.
  final RevealErrorCallback? onError;

  /// Override capture in widget tests; ownership of the image transfers here.
  @visibleForTesting
  final RevealCapture capture;

  /// Finds the nearest enclosing reveal viewport, or null.
  static ThemeRevealViewportState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<ThemeRevealViewportState>();

  /// Finds the enclosing viewport or throws a descriptive RevealException.
  static ThemeRevealViewportState of(BuildContext context) =>
      maybeOf(context) ??
      (throw const RevealException(
        'No ThemeRevealViewport found. Install it using MaterialApp.builder.',
      ));

  @override
  State<ThemeRevealViewport> createState() => ThemeRevealViewportState();
}

/// Imperative reveal engine exposed by ThemeRevealViewport.of.
class ThemeRevealViewportState extends State<ThemeRevealViewport>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _boundaryKey = GlobalKey();
  final _status = ValueNotifier(RevealTransitionState.idle);
  final _overlay = ValueNotifier<_RevealFrame?>(null);
  late final AnimationController _animation;
  _Run? _active;
  _Request? _pending;
  ui.Image? _snapshot;
  bool _disposed = false;
  final _disposedSignal = Completer<void>();
  Size? _layoutSize;

  /// Observable request lifecycle; owned and disposed by this viewport.
  ValueListenable<RevealTransitionState> get transitionState => _status;

  /// Whether an active or queued request exists.
  bool get isBusy => _active != null || _pending != null;

  /// Whether the engine currently owns a snapshot image (testing only).
  @visibleForTesting
  bool get debugHasSnapshot => _snapshot != null;

  /// Whether an old-frame overlay is installed (testing only).
  @visibleForTesting
  bool get debugHasOverlay => _overlay.value != null;

  /// Resolved overlay origin, or null without an overlay (testing only).
  @visibleForTesting
  Offset? get debugOrigin => _overlay.value?.origin;

  /// Effective strategy after coverage/custom-path fallback (testing only).
  @visibleForTesting
  RevealCompletionStrategy? get debugCompletionStrategy =>
      _active?.customFailed == true
      ? RevealCompletionStrategy.expandAndDissolve
      : _overlay.value?.strategy;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  /// True means the change was applied, including instant fallbacks. Ignored,
  /// superseded, disposed, or failed callbacks return false. A queued request's
  /// callback runs only when it becomes active; its origin is resolved then.
  /// [onThemeChange] must finish after the new state has been emitted.
  ///
  /// ```dart
  /// // Use your existing mode and state update; keep the update inside onThemeChange.
  /// await ThemeRevealViewport.of(buttonContext).reveal(
  ///   from: buttonContext,
  ///   onThemeChange: () => mode.value = ThemeMode.dark,
  /// );
  /// ```
  Future<bool> reveal({
    BuildContext? from,
    Offset? globalPosition,
    RevealShape shape = const RevealShape.circle(),
    RevealAnimationConfig config = const RevealAnimationConfig(),
    required RevealThemeChange onThemeChange,
    RevealErrorCallback? onError,
  }) {
    if (_disposed) return Future.value(false);
    final request = _Request(
      from,
      globalPosition,
      shape,
      config,
      onThemeChange,
      onError,
    );
    if (isBusy) {
      if (config.repeatPolicy == RevealRepeatPolicy.ignore) {
        return Future.value(false);
      }
      _pending?.result.complete(false);
      _pending = request;
    } else {
      _start(request);
    }
    return request.result.future;
  }

  /// Reveals a controller toggle with the same acceptance and fallback rules as reveal.
  ///
  /// ```dart
  /// // Toggle with a reveal; context must be below the viewport.
  /// ThemeRevealViewport.of(context).toggleTheme(controller, from: context);
  /// ```
  Future<bool> toggleTheme(
    RevealThemeController controller, {
    BuildContext? from,
    Offset? globalPosition,
    RevealShape shape = const RevealShape.circle(),
    RevealAnimationConfig config = const RevealAnimationConfig(),
  }) => reveal(
    from: from,
    globalPosition: globalPosition,
    shape: shape,
    config: config,
    onThemeChange: controller.toggleTheme,
  );

  /// Reveals an explicit controller mode with the same result semantics as reveal.
  ///
  /// ```dart
  /// // Select dark mode with a reveal; context must be below the viewport.
  /// ThemeRevealViewport.of(context).setThemeMode(controller, ThemeMode.dark, from: context);
  /// ```
  Future<bool> setThemeMode(
    RevealThemeController controller,
    ThemeMode mode, {
    BuildContext? from,
    Offset? globalPosition,
    RevealShape shape = const RevealShape.circle(),
    RevealAnimationConfig config = const RevealAnimationConfig(),
  }) => reveal(
    from: from,
    globalPosition: globalPosition,
    shape: shape,
    config: config,
    onThemeChange: () => controller.setThemeMode(mode),
  );

  void _start(_Request request) {
    final run = _Run(request);
    _active = run;
    unawaited(_perform(run));
  }

  void _state(RevealTransitionState state) {
    if (!_disposed) _status.value = state;
  }

  Future<void> _perform(_Run run) async {
    final request = run.request;
    final config = request.config;
    ui.Image? snapshot;
    var invoked = false;
    var applied = false;
    Future<void> apply() async {
      if (_disposed || invoked) return;
      invoked = true;
      _state(RevealTransitionState.applyingTheme);
      await Future.any([
        Future<void>.sync(request.onThemeChange),
        _disposedSignal.future,
      ]);
      applied = !_disposed;
    }

    try {
      _state(RevealTransitionState.preparing);
      final boundary =
          _boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final viewportSize = boundary.size;
      final pixelRatio = math.min(MediaQuery.devicePixelRatioOf(context), 3.0);
      if (config.duration.isNegative ||
          config.delay.isNegative ||
          config.completionDelay.isNegative) {
        throw const RevealException('Reveal durations must not be negative.');
      }
      final origin = config.origin.resolve(
        viewport: boundary,
        from: request.from,
        globalPosition: request.globalPosition,
        textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      );
      ResolvedShape? resolved;
      try {
        resolved = request.shape.requiresAsync
            ? await _resolveAsset(run)
            : request.shape.resolve().retain();
      } on RevealShapeException catch (error, stack) {
        _report(request, error, stack);
        resolved = const RevealShape.circle().resolve();
      }
      if (resolved == null || run.aborted || !mounted) {
        await apply();
        return;
      }
      run.mask = resolved;
      final unitPath = resolved.path;
      final coverage = solveCoverage(
        containsUnit: resolved.containsUnit,
        unitBounds: resolved.bounds,
        viewport: viewportSize,
        origin: origin,
        rotation: config.endRotation,
        alignment: config.alignment,
        fit: config.maskFit,
      );
      final strategy = resolveCompletionStrategy(
        requested: config.completionStrategy,
        canCover: coverage.canCover,
        morphToFullscreen: config.morphToFullscreen,
      );
      final reduce = switch (config.reducedMotion) {
        RevealReducedMotion.always => true,
        RevealReducedMotion.never => false,
        RevealReducedMotion.system => MediaQuery.disableAnimationsOf(context),
      };
      if (!config.enabled ||
          reduce ||
          config.duration == Duration.zero ||
          viewportSize.isEmpty) {
        await apply();
        return;
      }
      await _waitDelay(config.delay, run);
      if (run.aborted) {
        await apply();
        return;
      }
      _state(RevealTransitionState.capturing);
      // A pointer-down micro-animation may have dirtied the boundary. Capture
      // only after paint so toImage never receives an unpainted render object.
      await _frame(run);
      if (run.aborted) {
        await apply();
        return;
      }
      snapshot = await _capture(boundary, pixelRatio, run);
      if (run.aborted || snapshot == null) {
        await apply();
        return;
      }
      _snapshot = snapshot;
      _animation.value = 0;
      _overlay.value = _RevealFrame(
        snapshot,
        unitPath,
        origin,
        viewportSize,
        coverage.size,
        config,
        strategy,
        resolved.isComplex,
        resolved,
      );
      await _frame(run); // Install the opaque old frame before changing theme.
      await apply();
      if (run.aborted || _disposed) return;
      await _frame(run);
      await _frame(run); // Allow the new live theme two frames to settle.
      if (run.aborted || _disposed) return;
      _state(RevealTransitionState.revealing);
      _animation.duration = config.duration;
      await _animation.forward(from: 0).orCancel;
      _state(RevealTransitionState.completing);
      await _waitDelay(config.completionDelay, run);
    } on TickerCanceled {
      // Metrics/disposal intentionally cancel the animation.
    } catch (error, stack) {
      _report(request, error, stack);
      // Capture/origin failures still perform the requested change once.
      if (!invoked && !_disposed) {
        try {
          await apply();
        } catch (error, stack) {
          _report(request, error, stack);
        }
      }
    } finally {
      if (!_disposed) {
        _state(RevealTransitionState.completing);
        _overlay.value = null;
      }
      _snapshot = null;
      run.finished = true;
      run.snapshot?.dispose();
      run.snapshot = null;
      run.mask?.dispose();
      run.mask = null;
      _active = null;
      _state(RevealTransitionState.idle);
      request.result.complete(applied);
      // An idle listener may already have started another request. Its queue
      // belongs to that new run; never drain it into a concurrent reveal.
      if (_active == null && !_disposed) {
        final next = _pending;
        _pending = null;
        if (next != null) _start(next);
      }
    }
  }

  Future<ui.Image?> _capture(
    RenderRepaintBoundary boundary,
    double ratio,
    _Run run,
  ) {
    final capture = Future<ui.Image>.sync(() => widget.capture(boundary, ratio))
        .then<ui.Image?>(
          (image) {
            if (run.aborted || run.finished || _disposed) {
              image.dispose();
              return null;
            }
            run.snapshot = image;
            return image;
          },
          onError: (Object error, StackTrace stack) {
            if (run.aborted || _disposed) return null;
            Error.throwWithStackTrace(error, stack);
          },
        );
    return Future.any([
      capture,
      run.cancelled.future.then<ui.Image?>((_) => null),
    ]);
  }

  Future<ResolvedShape?> _resolveAsset(_Run run) {
    final future = run.request.shape.resolveAsync().then<ResolvedShape?>(
      (shape) {
        if (run.aborted || run.finished || _disposed) return null;
        final retained = shape.retain();
        run.mask = retained;
        return retained;
      },
      onError: (Object error, StackTrace stack) {
        if (run.aborted || run.finished || _disposed) return null;
        Error.throwWithStackTrace(error, stack);
      },
    );
    return Future.any([
      future,
      run.cancelled.future.then<ResolvedShape?>((_) => null),
    ]);
  }

  Future<void> _frame(_Run run) =>
      Future.any([WidgetsBinding.instance.endOfFrame, run.cancelled.future]);

  Future<void> _waitDelay(Duration duration, _Run run) async {
    if (duration == Duration.zero || run.aborted) return;
    final done = Completer<void>();
    final timer = Timer(duration, done.complete);
    try {
      await Future.any([done.future, run.cancelled.future]);
    } finally {
      timer.cancel();
    }
  }

  void _report(_Request request, Object error, StackTrace stack) {
    if (_disposed) return;
    try {
      (request.onError ?? widget.onError)?.call(error, stack);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'theme_reveal_kit',
          context: ErrorDescription('reporting a reveal error'),
        ),
      );
    }
  }

  void _abort() {
    final run = _active;
    if (run == null || run.aborted) return;
    run.aborted = true;
    run.cancelled.complete();
    _animation.stop(canceled: true);
    _overlay.value = null;
  }

  @override
  void didChangeMetrics() => _abort();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _abort();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (_layoutSize != null && _layoutSize != size && _active != null) {
        // Constraint-only changes can occur without platform metrics (e.g.
        // split views). Abort after layout, never notify during build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed) _abort();
        });
      }
      _layoutSize = size;
      return Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(key: _boundaryKey, child: widget.child),
          Positioned.fill(
            child: ValueListenableBuilder<_RevealFrame?>(
              valueListenable: _overlay,
              builder: (context, frame, _) => frame == null
                  ? const SizedBox.shrink()
                  : AbsorbPointer(
                      child: ExcludeSemantics(
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, _) {
                            final raw = _animation.value;
                            final progress = frame.config.curve
                                .transform(raw)
                                .clamp(0.0, 1.0);
                            final size = ui.lerpDouble(
                              frame.config.initialSize,
                              math.max(
                                frame.config.initialSize,
                                frame.finalSize,
                              ),
                              progress,
                            )!;
                            final placement = Affine.placement(
                              origin: frame.origin,
                              size: size,
                              rotation: ui.lerpDouble(
                                frame.config.startRotation,
                                frame.config.endRotation,
                                progress,
                              )!,
                              alignment: frame.config.alignment,
                              bounds: frame.mask.bounds,
                              fit: frame.config.maskFit,
                              viewport: frame.viewport,
                            );
                            final shapePath = frame.unitPath.transform(
                              placement.matrix,
                            );
                            final run = _active!;
                            RevealComposition compose(
                              RevealCompletionStrategy strategy,
                            ) => composeReveal(
                              shapePath: shapePath,
                              progress: raw,
                              viewport: frame.viewport,
                              origin: frame.origin,
                              strategy: strategy,
                              isComplex: frame.isComplex,
                              completionStart: frame.config.completionStart,
                            );
                            RevealComposition composition;
                            try {
                              composition = compose(
                                run.customFailed
                                    ? RevealCompletionStrategy.expandAndDissolve
                                    : frame.strategy,
                              );
                            } catch (error, stack) {
                              run.customFailed = true;
                              WidgetsBinding.instance.addPostFrameCallback(
                                (_) => _report(run.request, error, stack),
                              );
                              composition = compose(
                                RevealCompletionStrategy.expandAndDissolve,
                              );
                            }
                            return CustomPaint(
                              painter: RevealPainter(
                                snapshot: frame.snapshot,
                                cutout: composition.cutout,
                                opacity: composition.opacity,
                                edgeColor: frame.config.edgeColor,
                                edgeWidth: frame.config.edgeWidth,
                                glowColor: frame.config.glowColor,
                                glowRadius: frame.config.glowRadius,
                                feather: frame.config.feather,
                                alphaMask: frame.mask.alphaImage,
                                maskBounds: frame.mask.bounds,
                                maskPlacement: placement,
                                rasterUsesCustomPath:
                                    !run.customFailed &&
                                    frame.strategy.builder != null,
                                rasterCompletionCutout:
                                    frame.mask.isRaster &&
                                        frame.strategy ==
                                            RevealCompletionStrategy
                                                .morphToFullscreen
                                    ? composeReveal(
                                        shapePath: Path(),
                                        progress: raw,
                                        viewport: frame.viewport,
                                        origin: frame.origin,
                                        strategy: frame.strategy,
                                        isComplex: true,
                                        completionStart:
                                            frame.config.completionStart,
                                      ).cutout
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ),
        ],
      );
    },
  );

  @override
  void dispose() {
    _abort();
    _disposed = true;
    _disposedSignal.complete();
    WidgetsBinding.instance.removeObserver(this);
    _pending?.result.complete(false);
    _pending = null;
    _animation.dispose();
    _status.dispose();
    _overlay.dispose();
    super.dispose();
  }
}

class _Request {
  _Request(
    this.from,
    this.globalPosition,
    this.shape,
    this.config,
    this.onThemeChange,
    this.onError,
  );
  final BuildContext? from;
  final Offset? globalPosition;
  final RevealShape shape;
  final RevealAnimationConfig config;
  final RevealThemeChange onThemeChange;

  /// Default error listener for shape, capture and callback failures.
  final RevealErrorCallback? onError;
  final result = Completer<bool>();
}

class _Run {
  _Run(this.request);
  final _Request request;
  final cancelled = Completer<void>();
  bool aborted = false;
  bool finished = false;
  bool customFailed = false;
  ResolvedShape? mask;
  ui.Image? snapshot;
}

class _RevealFrame {
  const _RevealFrame(
    this.snapshot,
    this.unitPath,
    this.origin,
    this.viewport,
    this.finalSize,
    this.config,
    this.strategy,
    this.isComplex,
    this.mask,
  );
  final ui.Image snapshot;
  final Path unitPath;
  final Offset origin;
  final Size viewport;
  final double finalSize;
  final RevealAnimationConfig config;
  final RevealCompletionStrategy strategy;
  final bool isComplex;
  final ResolvedShape mask;
}
