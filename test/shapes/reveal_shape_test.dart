import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

void main() {
  final builtins = <String, RevealShape>{
    'circle': const RevealShape.circle(),
    'ellipse': const RevealShape.ellipse(),
    'rectangle': const RevealShape.rectangle(),
    'roundedRectangle': const RevealShape.roundedRectangle(),
    'triangle': const RevealShape.triangle(),
    'star': const RevealShape.star(),
    'heart': const RevealShape.heart(),
    'diamond': const RevealShape.diamond(),
    'hexagon': const RevealShape.hexagon(),
    'polygon': const RevealShape.polygon(sides: 7),
  };

  for (final entry in builtins.entries) {
    test('${entry.key} resolves to centered, filled, normalized geometry', () {
      final shape = entry.value.resolve();
      expect(
        math.max(shape.bounds.width, shape.bounds.height),
        closeTo(1, 1e-6),
      );
      expect(shape.bounds.center.distance, lessThan(1e-6));
      expect(shape.containsUnit(Offset.zero), isTrue);
      expect(shape.containsUnit(const Offset(2, 2)), isFalse);
      expect(shape.path.computeMetrics().single.length, greaterThan(0));
      expect(identical(entry.value.resolve(), shape), isTrue);
    });
  }

  test(
    'aspect ratios, rounded corners and star parameters affect the silhouette',
    () {
      for (final shape in [
        const RevealShape.ellipse(aspectRatio: 2),
        const RevealShape.rectangle(aspectRatio: .5),
      ]) {
        final bounds = shape.resolve().bounds;
        expect(math.max(bounds.width, bounds.height), 1);
        expect(math.min(bounds.width, bounds.height), .5);
      }
      final rect = const RevealShape.roundedRectangle(
        aspectRatio: 2,
        cornerRadius: 0,
      ).resolve();
      final round = const RevealShape.roundedRectangle(
        aspectRatio: 2,
        cornerRadius: .2,
      ).resolve();
      expect(rect.containsUnit(const Offset(.49, .24)), isTrue);
      expect(round.containsUnit(const Offset(.49, .24)), isFalse);
      final small = const RevealShape.star(innerRadius: .2).resolve();
      final large = const RevealShape.star(innerRadius: .8).resolve();
      var differences = 0;
      for (var y = -5; y <= 5; y++) {
        for (var x = -5; x <= 5; x++) {
          if (small.containsUnit(Offset(x / 10, y / 10)) !=
              large.containsUnit(Offset(x / 10, y / 10))) {
            differences++;
          }
        }
      }
      expect(differences, greaterThan(0));
    },
  );

  test(
    'custom paths normalize translations and preserve even-odd holes and components',
    () {
      final rect = RevealShape.customPath(
        builder: (size) {
          expect(size, const Size(100, 100));
          return Path()..addRect(const Rect.fromLTWH(100, 200, 80, 40));
        },
      ).resolve();
      expect(rect.bounds, const Rect.fromLTWH(-.5, -.25, 1, .5));
      final ring = RevealShape.customPath(
        builder: (_) => Path()
          ..fillType = PathFillType.evenOdd
          ..addOval(const Rect.fromLTWH(0, 0, 100, 100))
          ..addOval(const Rect.fromLTWH(25, 25, 50, 50)),
      ).resolve();
      expect(ring.isComplex, isTrue);
      expect(ring.containsUnit(Offset.zero), isFalse);
      expect(ring.containsUnit(const Offset(.4, 0)), isTrue);
      final islands = RevealShape.customPath(
        builder: (_) => Path()
          ..addRect(const Rect.fromLTWH(0, 0, 20, 20))
          ..addRect(const Rect.fromLTWH(80, 80, 20, 20)),
      ).resolve();
      expect(islands.containsUnit(const Offset(-.4, -.4)), isTrue);
      expect(islands.containsUnit(Offset.zero), isFalse);
    },
  );

  test(
    'invalid parameters and empty, degenerate, non-finite custom paths are rejected',
    () {
      final invalid = <RevealShape>[
        const RevealShape.ellipse(aspectRatio: 0),
        const RevealShape.rectangle(aspectRatio: double.infinity),
        const RevealShape.roundedRectangle(cornerRadius: -1),
        const RevealShape.polygon(sides: 2),
        const RevealShape.star(points: 1),
        const RevealShape.star(innerRadius: 0),
        const RevealShape.star(innerRadius: double.nan),
        RevealShape.customPath(builder: (_) => Path()),
        RevealShape.customPath(
          builder: (_) => Path()
            ..moveTo(0, 0)
            ..lineTo(10, 10),
        ),
        RevealShape.customPath(
          builder: (_) => Path()..addRect(const Rect.fromLTWH(0, 0, 0, 10)),
        ),
        RevealShape.customPath(
          builder: (_) => Path()
            ..addRect(const Rect.fromLTWH(0, 0, 10, 10))
            ..lineTo(double.nan, 20),
        ),
        RevealShape.customPath(
          builder: (_) => Path()..lineTo(double.infinity, 20),
        ),
        RevealShape.customPath(
          builder: (_) => throw StateError('builder failed'),
        ),
      ];
      for (final shape in invalid) {
        expect(shape.resolve, throwsA(isA<RevealShapeException>()));
      }
    },
  );

  test('path copies protect cached geometry from caller mutations', () {
    final source = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
    final shape = RevealShape.customPath(builder: (_) => source);
    final resolved = shape.resolve();
    source.reset();
    resolved.path.reset();
    expect(shape.resolve().containsUnit(Offset.zero), isTrue);
  });

  test(
    'identity LRU cache is capped at 12, refreshes hits and evicts old resolutions',
    () {
      var builds = 0;
      final first = RevealShape.customPath(
        builder: (_) {
          builds++;
          return Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
        },
      );
      final firstResult = first.resolve();
      final others = List.generate(
        11,
        (_) => RevealShape.customPath(
          builder: (_) => Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10)),
        ),
      );
      final secondResult = others.first.resolve();
      for (final shape in others.skip(1)) {
        shape.resolve();
      }
      expect(first.resolve(), same(firstResult));
      RevealShape.customPath(
        builder: (_) => Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10)),
      ).resolve();
      expect(first.resolve(), same(firstResult));
      expect(others.first.resolve(), isNot(same(secondResult)));
      for (var i = 0; i < 12; i++) {
        RevealShape.customPath(
          builder: (_) => Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10)),
        ).resolve();
      }
      expect(RevealShape.debugCacheLength, 12);
      expect(first.resolve(), isNot(same(firstResult)));
      expect(builds, 2);
    },
  );
}
