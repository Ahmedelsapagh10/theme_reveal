import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import '../shapes/reveal_mask_fit.dart';

/// Hand-written 2D affine transform shared by placement and coverage checks.
class Affine {
  /// Creates the internal 2D matrix `[a c tx; b d ty; 0 0 1]`.
  const Affine(this.a, this.b, this.c, this.d, this.tx, this.ty);

  /// Computes source-independent placement, rotation, fit and anchor alignment.
  factory Affine.placement({
    required Offset origin,
    required double size,
    double rotation = 0,
    Alignment alignment = Alignment.center,
    Rect bounds = const Rect.fromLTWH(-.5, -.5, 1, 1),
    RevealMaskFit fit = RevealMaskFit.contain,
    Size viewport = const Size(1, 1),
  }) {
    final longest = math.max(viewport.width, viewport.height);
    final scaleX = fit == RevealMaskFit.fill && longest > 0
        ? size * viewport.width / longest / bounds.width
        : size;
    final scaleY = fit == RevealMaskFit.fill && longest > 0
        ? size * viewport.height / longest / bounds.height
        : size;
    final a = math.cos(rotation) * scaleX;
    final b = math.sin(rotation) * scaleX;
    final c = -math.sin(rotation) * scaleY;
    final d = math.cos(rotation) * scaleY;
    final anchor = alignment.withinRect(bounds);
    return Affine(
      a,
      b,
      c,
      d,
      origin.dx - a * anchor.dx - c * anchor.dy,
      origin.dy - b * anchor.dx - d * anchor.dy,
    );
  }

  /// Linear matrix coefficients and logical-pixel translation components.
  final double a, b, c, d, tx, ty;

  /// Transforms a normalized point into viewport coordinates.
  Offset transform(Offset point) => Offset(
    a * point.dx + c * point.dy + tx,
    b * point.dx + d * point.dy + ty,
  );

  /// Maps a viewport point back into normalized mask coordinates.
  Offset inverseTransform(Offset point) {
    final det = a * d - b * c;
    return Offset(
      (d * (point.dx - tx) - c * (point.dy - ty)) / det,
      (-b * (point.dx - tx) + a * (point.dy - ty)) / det,
    );
  }

  /// Equivalent column-major 4×4 matrix for Canvas and Path transforms.
  Float64List get matrix =>
      Float64List.fromList([a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1]);
}

/// Internal sampled coverage result, including non-coverable fallback size.
class CoverageResult {
  /// Creates a coverage size and whether all tested points were covered.
  const CoverageResult(this.size, this.canCover);

  /// Solved longest placement side in logical pixels.
  final double size;

  /// Whether the sampled grid and anchor checks accepted coverage.
  final bool canCover;
}

/// Searches a normalized mask, independent of its source or geometry.
CoverageResult solveCoverage({
  required bool Function(Offset) containsUnit,
  required Rect unitBounds,
  required Size viewport,
  required Offset origin,
  double rotation = 0,
  Alignment alignment = Alignment.center,
  RevealMaskFit fit = RevealMaskFit.contain,
}) {
  final diagonal = viewport.bottomRight(Offset.zero).distance;
  // A hole at the anchor stays under an origin inside the viewport at every
  // scale, even when the 11x11 samples happen to miss that exact location.
  if ((Offset.zero & viewport).contains(origin) &&
      !containsUnit(alignment.withinRect(unitBounds))) {
    return CoverageResult(diagonal * 1.5, false);
  }
  bool covers(double size) {
    final placement = Affine.placement(
      origin: origin,
      size: size,
      rotation: rotation,
      alignment: alignment,
      bounds: unitBounds,
      fit: fit,
      viewport: viewport,
    );
    for (var y = 0; y <= 10; y++) {
      for (var x = 0; x <= 10; x++) {
        if (!containsUnit(
          placement.inverseTransform(
            Offset(viewport.width * x / 10, viewport.height * y / 10),
          ),
        )) {
          return false;
        }
      }
    }
    return true;
  }

  var high = math.max(1.0, diagonal);
  var low = 0.0;
  var covered = covers(high);
  for (var i = 0; !covered && i < 24; i++) {
    low = high;
    high *= 2;
    covered = covers(high);
  }
  if (!covered) return CoverageResult(diagonal * 1.5, false);
  for (var i = 0; i < 40; i++) {
    final middle = (low + high) / 2;
    if (covers(middle)) {
      high = middle;
    } else {
      low = middle;
    }
  }
  return CoverageResult(high * 1.000001, true);
}
