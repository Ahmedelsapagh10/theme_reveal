import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/src/rendering/reveal_geometry.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

void main() {
  test('circle resolves to normalized geometry', () {
    final resolved = const RevealShape.circle().resolve();
    expect(resolved.bounds, const Rect.fromLTWH(-.5, -.5, 1, 1));
    expect(resolved.containsUnit(Offset.zero), isTrue);
    expect(resolved.containsUnit(const Offset(.49, .49)), isFalse);
  });

  test('Affine transforms, alignment and inverse agree', () {
    final affine = Affine.placement(
      origin: const Offset(100, 50),
      size: 20,
      rotation: math.pi / 2,
      alignment: Alignment.topLeft,
    );
    expect(affine.transform(const Offset(-.5, -.5)).dx, closeTo(100, 1e-8));
    expect(affine.transform(const Offset(-.5, -.5)).dy, closeTo(50, 1e-8));
    const point = Offset(.1, -.3);
    final restored = affine.inverseTransform(affine.transform(point));
    expect(restored.dx, closeTo(point.dx, 1e-8));
    expect(restored.dy, closeTo(point.dy, 1e-8));
  });

  test(
    'coverage finds smallest circle covering all corners, including external origins',
    () {
      const viewport = Size(400, 700);
      for (final origin in [
        const Offset(200, 350),
        Offset.zero,
        const Offset(370, 630),
        const Offset(-100, 900),
      ]) {
        final circle = const RevealShape.circle().resolve();
        final result = solveCoverage(
          containsUnit: circle.containsUnit,
          unitBounds: circle.bounds,
          viewport: viewport,
          origin: origin,
        );
        final corners = [
          Offset.zero,
          const Offset(400, 0),
          const Offset(0, 700),
          const Offset(400, 700),
        ];
        final expected = corners
            .map((point) => (point - origin).distance * 2)
            .reduce(math.max);
        expect(result.canCover, isTrue);
        // Flutter's oval Path is represented by conics; allow subpixel tolerance.
        expect(result.size, closeTo(expected, .1));
        final placement = Affine.placement(origin: origin, size: result.size);
        for (final corner in corners) {
          expect(
            circle.containsUnit(placement.inverseTransform(corner)),
            isTrue,
          );
        }
      }
    },
  );

  test('config copyWith preserves unspecified values', () {
    const original = RevealAnimationConfig(
      duration: Duration(milliseconds: 900),
      initialSize: 12,
      startRotation: 1,
      endRotation: 2,
      alignment: Alignment.topCenter,
    );
    final copy = original.copyWith(
      enabled: false,
      delay: const Duration(milliseconds: 40),
      completionDelay: const Duration(milliseconds: 20),
      origin: const RevealOrigin.gesture(),
      repeatPolicy: RevealRepeatPolicy.queueLatest,
      reducedMotion: RevealReducedMotion.never,
    );
    expect(copy.duration, original.duration);
    expect(copy.curve, original.curve);
    expect(copy.initialSize, 12);
    expect(copy.startRotation, 1);
    expect(copy.endRotation, 2);
    expect(copy.alignment, Alignment.topCenter);
    expect(copy.enabled, isFalse);
    expect(copy.delay.inMilliseconds, 40);
    expect(copy.completionDelay.inMilliseconds, 20);
    expect(copy.repeatPolicy, RevealRepeatPolicy.queueLatest);
    expect(copy.reducedMotion, RevealReducedMotion.never);
  });
}
