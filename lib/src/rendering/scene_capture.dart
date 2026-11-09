import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// Internal injectable scene-capture callback; ownership transfers to the engine.
typedef RevealCapture =
    Future<ui.Image> Function(
      RenderRepaintBoundary boundary,
      double pixelRatio,
    );

/// Captures the painted Flutter boundary at the engine-capped pixel ratio.
Future<ui.Image> captureRevealScene(
  RenderRepaintBoundary boundary,
  double pixelRatio,
) => boundary.toImage(pixelRatio: pixelRatio);
