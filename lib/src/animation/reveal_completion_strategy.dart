import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Receives the placed, eased shape and raw timeline progress in `[0, 1]`.
typedef RevealCutoutBuilder =
    Path Function(
      Path shapePath,
      double progress,
      Size viewport,
      Offset origin,
    );

/// Immutable policy for uncovering the final old-frame pixels.
@immutable
class RevealCompletionStrategy {
  const RevealCompletionStrategy._(this._kind) : builder = null;

  /// Uses a caller-supplied vector cutout at each raw progress value.
  ///
  /// For raster shapes the input path is their placement rectangle. An invalid
  /// custom result reports an error and falls back to dissolve.
  const RevealCompletionStrategy.custom(RevealCutoutBuilder this.builder)
    : _kind = 4;

  /// Preserves a coverable shape; otherwise uses dissolve.
  static const auto = RevealCompletionStrategy._(0);

  /// Keeps the shape silhouette while expanding to sampled coverage.
  static const preserveShape = RevealCompletionStrategy._(1);

  /// Unions the shape with a growing viewport-covering circle.
  static const morphToFullscreen = RevealCompletionStrategy._(2);

  /// Expands the mask and fades the remaining old frame during completion.
  static const expandAndDissolve = RevealCompletionStrategy._(3);

  final int _kind;

  /// Custom cutout callback, or null for a built-in strategy.
  final RevealCutoutBuilder? builder;

  /// Stable descriptive name of this strategy.
  String get name => const [
    'auto',
    'preserveShape',
    'morphToFullscreen',
    'expandAndDissolve',
    'custom',
  ][_kind];
}
