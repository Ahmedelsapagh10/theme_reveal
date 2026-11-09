import 'package:flutter/material.dart';

import '../utils/reveal_origin.dart';
import '../shapes/reveal_mask_fit.dart';
import 'reveal_completion_strategy.dart';
import 'transition_state.dart';

/// Vector reveal configuration. Sizes are logical pixels; rotations radians.
///
/// ```dart
/// // Set this as the animation argument on your button or trigger.
/// const RevealAnimationConfig(
///   duration: Duration(milliseconds: 900),
///   origin: RevealOrigin.screenCenter(),
///   reducedMotion: RevealReducedMotion.system,
/// );
/// ```
@immutable
class RevealAnimationConfig {
  /// Creates an outward reveal configuration with a 650 ms circular default.
  const RevealAnimationConfig({
    this.enabled = true,
    this.duration = const Duration(milliseconds: 650),
    this.curve = Curves.easeInOutCubic,
    this.delay = Duration.zero,
    this.completionDelay = Duration.zero,
    this.origin = const RevealOrigin.buttonCenter(),
    this.initialSize = 0,
    this.startRotation = 0,
    this.endRotation = 0,
    this.alignment = Alignment.center,
    this.maskFit = RevealMaskFit.contain,
    this.completionStrategy = RevealCompletionStrategy.auto,
    this.morphToFullscreen = false,
    this.completionStart = .7,
    this.edgeColor,
    this.edgeWidth = 0,
    this.glowColor,
    this.glowRadius = 0,
    this.feather = 0,
    this.repeatPolicy = RevealRepeatPolicy.ignore,
    this.reducedMotion = RevealReducedMotion.system,
  }) : assert(completionStart >= 0 && completionStart < 1),
       assert(edgeWidth >= 0 && edgeWidth < double.infinity),
       assert(glowRadius >= 0 && glowRadius < double.infinity),
       assert(feather >= 0 && feather < double.infinity),
       assert(initialSize >= 0 && initialSize < double.infinity),
       assert(
         startRotation > double.negativeInfinity &&
             startRotation < double.infinity,
       ),
       assert(
         endRotation > double.negativeInfinity && endRotation < double.infinity,
       );

  /// Whether to capture and animate; false applies the theme instantly.
  final bool enabled;

  /// Expansion duration; zero applies the theme instantly.
  final Duration duration;

  /// Easing applied to mask expansion, independently of terminal completion.
  final Curve curve;

  /// Delay before capture; cancelled when viewport metrics change.
  final Duration delay;

  /// Time to retain the fully transparent overlay before cleanup.
  final Duration completionDelay;

  /// Where expansion starts, resolved in viewport-local coordinates.
  final RevealOrigin origin;

  /// Initial longest mask side in logical pixels, before expansion.
  final double initialSize;

  /// Initial mask rotation in radians.
  final double startRotation;

  /// Final rotation in radians, also used by the coverage solver.
  final double endRotation;

  /// Point of the normalized mask anchored at the resolved origin.
  final Alignment alignment;

  /// Whether placement preserves or stretches mask proportions.
  final RevealMaskFit maskFit;

  /// How the final portion uncovers the viewport, subject to coverage fallback.
  final RevealCompletionStrategy completionStrategy;

  /// Shortcut selecting morphToFullscreen, subject to coverage fallback.
  final bool morphToFullscreen;

  /// Raw progress where morph/dissolve completion begins; in [0, 1).
  final double completionStart;

  /// Optional vector edge color; ignored by raster masks.
  final Color? edgeColor;

  /// Vector edge width in logical pixels; zero disables the stroke.
  final double edgeWidth;

  /// Optional vector glow color; ignored by raster masks.
  final Color? glowColor;

  /// Vector glow blur radius in logical pixels; zero disables the glow.
  final double glowRadius;

  /// Gaussian sigma in logical pixels for the vector cutout boundary.
  final double feather;

  /// How requests received while another request is active are handled.
  final RevealRepeatPolicy repeatPolicy;

  /// Whether to follow, force or override the system motion preference.
  final RevealReducedMotion reducedMotion;

  /// Returns a copy replacing non-null arguments.
  ///
  /// Null color arguments retain existing colors. To clear a color, construct a
  /// new configuration; this method does not use a nullable-value sentinel.
  RevealAnimationConfig copyWith({
    bool? enabled,
    Duration? duration,
    Curve? curve,
    Duration? delay,
    Duration? completionDelay,
    RevealOrigin? origin,
    double? initialSize,
    double? startRotation,
    double? endRotation,
    Alignment? alignment,
    RevealMaskFit? maskFit,
    RevealCompletionStrategy? completionStrategy,
    bool? morphToFullscreen,
    double? completionStart,
    Color? edgeColor,
    double? edgeWidth,
    Color? glowColor,
    double? glowRadius,
    double? feather,
    RevealRepeatPolicy? repeatPolicy,
    RevealReducedMotion? reducedMotion,
  }) => RevealAnimationConfig(
    enabled: enabled ?? this.enabled,
    duration: duration ?? this.duration,
    curve: curve ?? this.curve,
    delay: delay ?? this.delay,
    completionDelay: completionDelay ?? this.completionDelay,
    origin: origin ?? this.origin,
    initialSize: initialSize ?? this.initialSize,
    startRotation: startRotation ?? this.startRotation,
    endRotation: endRotation ?? this.endRotation,
    alignment: alignment ?? this.alignment,
    maskFit: maskFit ?? this.maskFit,
    completionStrategy: completionStrategy ?? this.completionStrategy,
    morphToFullscreen: morphToFullscreen ?? this.morphToFullscreen,
    completionStart: completionStart ?? this.completionStart,
    edgeColor: edgeColor ?? this.edgeColor,
    edgeWidth: edgeWidth ?? this.edgeWidth,
    glowColor: glowColor ?? this.glowColor,
    glowRadius: glowRadius ?? this.glowRadius,
    feather: feather ?? this.feather,
    repeatPolicy: repeatPolicy ?? this.repeatPolicy,
    reducedMotion: reducedMotion ?? this.reducedMotion,
  );
}
