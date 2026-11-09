import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../animation/reveal_completion_strategy.dart';
import '../utils/reveal_exception.dart';

/// Resolves auto, morph shortcut and non-coverable-mask dissolve fallback.
RevealCompletionStrategy resolveCompletionStrategy({
  required RevealCompletionStrategy requested,
  required bool canCover,
  bool morphToFullscreen = false,
}) {
  if (!canCover) return RevealCompletionStrategy.expandAndDissolve;
  if (morphToFullscreen) return RevealCompletionStrategy.morphToFullscreen;
  return requested == RevealCompletionStrategy.auto
      ? RevealCompletionStrategy.preserveShape
      : requested;
}

/// Internal completed cutout geometry and remaining old-frame opacity.
class RevealComposition {
  /// Creates a cutout and opacity for one frame.
  const RevealComposition(this.cutout, this.opacity);

  /// Viewport-space area to remove from the old frame.
  final Path cutout;

  /// Remaining old-frame opacity, zero at the terminal progress.
  final double opacity;
}

/// Completion uses raw time, independently of the eased mask expansion. The
/// endpoint is transparent even if a custom cutout never reaches the corners.
RevealComposition composeReveal({
  required Path shapePath,
  required double progress,
  required Size viewport,
  required Offset origin,
  required RevealCompletionStrategy strategy,
  required bool isComplex,
  double completionStart = .7,
}) {
  if (progress >= 1) return RevealComposition(Path(), 0);
  final completion = ((progress - completionStart) / (1 - completionStart))
      .clamp(0.0, 1.0);
  final fadeLength = isComplex || strategy.builder != null ? .12 : .03;
  var opacity = ((1 - progress) / fadeLength).clamp(0.0, 1.0);
  var cutout = shapePath;
  if (strategy == RevealCompletionStrategy.expandAndDissolve) {
    opacity *= 1 - completion;
  } else if (strategy == RevealCompletionStrategy.morphToFullscreen &&
      completion > 0) {
    final corners = [
      Offset.zero,
      Offset(viewport.width, 0),
      Offset(0, viewport.height),
      viewport.bottomRight(Offset.zero),
    ];
    final radius =
        corners.map((corner) => (corner - origin).distance).reduce(math.max) *
        completion;
    // Continuous union with a growing circle, not point-wise path morphing.
    cutout = Path.combine(
      PathOperation.union,
      shapePath,
      Path()..addOval(Rect.fromCircle(center: origin, radius: radius)),
    );
  } else if (strategy.builder != null) {
    cutout = strategy.builder!(
      Path.from(shapePath),
      progress,
      viewport,
      origin,
    );
    final bounds = cutout.getBounds();
    if (!bounds.left.isFinite ||
        !bounds.top.isFinite ||
        !bounds.right.isFinite ||
        !bounds.bottom.isFinite) {
      throw const RevealException(
        'Custom completion must return a finite path.',
      );
    }
    // Also catches invalid native geometry mixed with valid contours.
    cutout = Path.combine(PathOperation.union, cutout, Path());
  }
  return RevealComposition(cutout, opacity);
}
