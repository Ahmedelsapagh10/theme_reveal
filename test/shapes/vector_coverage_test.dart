import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/src/rendering/reveal_composition.dart';
import 'package:theme_reveal_kit/src/rendering/reveal_geometry.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

void main() {
  for (final shape in [
    const RevealShape.circle(),
    const RevealShape.triangle(),
    const RevealShape.star(),
  ]) {
    for (final fit in RevealMaskFit.values) {
      test(
        '${shape.runtimeType} ${shape.resolve().isComplex} $fit coverage uses final rotation and finds the grid minimum',
        () {
          final resolved = shape.resolve();
          const viewport = Size(320, 580);
          const origin = Offset(83, 257);
          const rotation = .61;
          const alignment = Alignment(.1, -.1);
          final result = solveCoverage(
            containsUnit: resolved.containsUnit,
            unitBounds: resolved.bounds,
            viewport: viewport,
            origin: origin,
            rotation: rotation,
            alignment: alignment,
            fit: fit,
          );
          bool covers(double size) {
            final placement = Affine.placement(
              origin: origin,
              size: size,
              rotation: rotation,
              alignment: alignment,
              bounds: resolved.bounds,
              fit: fit,
              viewport: viewport,
            );
            for (var y = 0; y <= 10; y++) {
              for (var x = 0; x <= 10; x++) {
                if (!resolved.containsUnit(
                  placement.inverseTransform(
                    Offset(x * viewport.width / 10, y * viewport.height / 10),
                  ),
                )) {
                  return false;
                }
              }
            }
            return true;
          }

          expect(result.canCover, isTrue);
          expect(covers(result.size), isTrue);
          expect(covers(result.size * .995), isFalse);
        },
      );
    }
  }

  test(
    'ring cannot cover even with its anchor between grid samples; every requested strategy dissolves',
    () {
      final ring = RevealShape.customPath(
        builder: (_) => Path()
          ..fillType = PathFillType.evenOdd
          ..addOval(const Rect.fromLTWH(-50, -50, 100, 100))
          ..addOval(const Rect.fromLTWH(-10, -10, 20, 20)),
      ).resolve();
      const viewport = Size(400, 600);
      final result = solveCoverage(
        containsUnit: ring.containsUnit,
        unitBounds: ring.bounds,
        viewport: viewport,
        origin: const Offset(183, 271),
      );
      expect(result.canCover, isFalse);
      expect(
        result.size,
        closeTo(math.sqrt(400 * 400 + 600 * 600) * 1.5, 1e-8),
      );
      for (final requested in [
        RevealCompletionStrategy.auto,
        RevealCompletionStrategy.preserveShape,
        RevealCompletionStrategy.morphToFullscreen,
        RevealCompletionStrategy.expandAndDissolve,
        RevealCompletionStrategy.custom(
          (path, progress, viewport, origin) => path,
        ),
      ]) {
        expect(
          resolveCompletionStrategy(requested: requested, canCover: false),
          RevealCompletionStrategy.expandAndDissolve,
        );
      }
      expect(
        resolveCompletionStrategy(
          requested: RevealCompletionStrategy.auto,
          canCover: true,
        ),
        RevealCompletionStrategy.preserveShape,
      );
      expect(
        resolveCompletionStrategy(
          requested: RevealCompletionStrategy.auto,
          canCover: true,
          morphToFullscreen: true,
        ),
        RevealCompletionStrategy.morphToFullscreen,
      );
    },
  );

  test(
    'fill, rotation and alignment share exact painter/coverage placement',
    () {
      final rect = const RevealShape.rectangle(aspectRatio: 2).resolve();
      const viewport = Size(400, 400);
      const origin = Offset(30, 40);
      for (final fit in RevealMaskFit.values) {
        final affine = Affine.placement(
          origin: origin,
          size: 200,
          bounds: rect.bounds,
          fit: fit,
          viewport: viewport,
          rotation: math.pi / 2,
          alignment: Alignment.topLeft,
        );
        final path = rect.path.transform(affine.matrix);
        expect(
          (affine.transform(rect.bounds.topLeft) - origin).distance,
          lessThan(1e-6),
        );
        expect(path.getBounds().height, closeTo(200, 1e-5));
        expect(
          path.getBounds().width,
          closeTo(fit == RevealMaskFit.fill ? 200 : 100, 1e-5),
        );
        final original = affine.inverseTransform(
          affine.transform(const Offset(.2, -.1)),
        );
        expect((original - const Offset(.2, -.1)).distance, lessThan(1e-8));
      }
    },
  );

  test('new config fields survive copyWith', () {
    const config = RevealAnimationConfig(
      maskFit: RevealMaskFit.fill,
      completionStrategy: RevealCompletionStrategy.morphToFullscreen,
      morphToFullscreen: true,
      completionStart: .6,
      edgeColor: Colors.red,
      edgeWidth: 2,
      glowColor: Colors.green,
      glowRadius: 6,
      feather: 3,
    );
    final copy = config.copyWith(duration: const Duration(seconds: 1));
    expect(copy.maskFit, RevealMaskFit.fill);
    expect(copy.completionStrategy, RevealCompletionStrategy.morphToFullscreen);
    expect(copy.morphToFullscreen, isTrue);
    expect(copy.completionStart, .6);
    expect(copy.edgeColor, Colors.red);
    expect(copy.edgeWidth, 2);
    expect(copy.glowColor, Colors.green);
    expect(copy.glowRadius, 6);
    expect(copy.feather, 3);
    final changed = copy.copyWith(
      maskFit: RevealMaskFit.contain,
      completionStrategy: RevealCompletionStrategy.auto,
      morphToFullscreen: false,
      completionStart: .8,
      edgeColor: Colors.blue,
      edgeWidth: 1,
      glowColor: Colors.yellow,
      glowRadius: 2,
      feather: 1,
    );
    expect(changed.maskFit, RevealMaskFit.contain);
    expect(changed.completionStrategy, RevealCompletionStrategy.auto);
    expect(changed.morphToFullscreen, isFalse);
    expect(changed.completionStart, .8);
    expect(changed.edgeColor, Colors.blue);
    expect(changed.edgeWidth, 1);
    expect(changed.glowColor, Colors.yellow);
    expect(changed.glowRadius, 2);
    expect(changed.feather, 1);
  });
}
