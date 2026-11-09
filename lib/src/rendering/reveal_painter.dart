import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'reveal_geometry.dart';

/// Paints the old frame with a vector hole exposing the live app beneath it.
class RevealPainter extends CustomPainter {
  /// Creates an internal old-frame compositor with optional vector/raster effects.
  RevealPainter({
    required this.snapshot,
    required this.cutout,
    required this.opacity,
    this.edgeColor,
    this.edgeWidth = 0,
    this.glowColor,
    this.glowRadius = 0,
    this.feather = 0,
    this.alphaMask,
    this.maskBounds,
    this.maskPlacement,
    this.rasterCompletionCutout,
    this.rasterUsesCustomPath = false,
  });

  /// Borrowed old scene image; the engine owns its lifetime.
  final ui.Image snapshot;

  /// Viewport-space vector cutout.
  final Path cutout;

  /// Overall old-frame opacity, including completion safety fade.
  final double opacity;

  /// Optional vector boundary stroke color.
  final Color? edgeColor;

  /// Boundary stroke width in logical pixels.
  final double edgeWidth;

  /// Optional vector boundary glow color.
  final Color? glowColor;

  /// Vector boundary blur radius in logical pixels.
  final double glowRadius;

  /// Gaussian sigma of the vector cutout boundary.
  final double feather;

  /// Borrowed bounded raster alpha image, if the source is raster.
  final ui.Image? alphaMask;

  /// Normalized raster bounds before placement.
  final Rect? maskBounds;

  /// Raster-to-viewport affine placement.
  final Affine? maskPlacement;

  /// Additional completion geometry, such as a growing circle.
  final Path? rasterCompletionCutout;

  /// Whether a custom strategy overrides the raster silhouette with a path.
  final bool rasterUsesCustomPath;

  @override
  void paint(Canvas canvas, Size size) {
    // Includes edge/glow, so even deliberately incomplete custom masks leave
    // no old pixels or decorations behind at the transition endpoint.
    if (opacity <= 0) return;
    final bounds = Offset.zero & size;
    canvas.saveLayer(
      bounds,
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    canvas.drawImageRect(
      snapshot,
      Rect.fromLTWH(
        0,
        0,
        snapshot.width.toDouble(),
        snapshot.height.toDouble(),
      ),
      bounds,
      Paint()..filterQuality = FilterQuality.low,
    );
    if (alphaMask != null && !rasterUsesCustomPath) {
      canvas.save();
      canvas.transform(maskPlacement!.matrix);
      canvas.drawImageRect(
        alphaMask!,
        Rect.fromLTWH(
          0,
          0,
          alphaMask!.width.toDouble(),
          alphaMask!.height.toDouble(),
        ),
        maskBounds!,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..filterQuality = FilterQuality.low,
      );
      canvas.restore();
      if (rasterCompletionCutout != null) {
        canvas.drawPath(
          rasterCompletionCutout!,
          Paint()..blendMode = BlendMode.dstOut,
        );
      }
    } else {
      canvas.drawPath(
        cutout,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..maskFilter = alphaMask == null && feather > 0
              ? MaskFilter.blur(BlurStyle.normal, feather)
              : null,
      );
    }
    canvas.restore();
    if (alphaMask != null) return; // Edge, glow and feather are vector-only.
    if (cutout.getBounds().isEmpty) return;
    if (glowColor != null && glowRadius > 0) {
      canvas.drawPath(
        cutout,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = edgeWidth > 0 ? edgeWidth : 1
          ..color = glowColor!.withValues(alpha: glowColor!.a * opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius),
      );
    }
    if (edgeColor != null && edgeWidth > 0) {
      canvas.drawPath(
        cutout,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = edgeWidth
          ..color = edgeColor!.withValues(alpha: edgeColor!.a * opacity),
      );
    }
  }

  @override
  bool shouldRepaint(RevealPainter oldDelegate) => true;
}
