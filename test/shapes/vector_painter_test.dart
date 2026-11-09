import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/src/rendering/reveal_composition.dart';
import 'package:theme_reveal_kit/src/rendering/reveal_geometry.dart';
import 'package:theme_reveal_kit/src/rendering/reveal_painter.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

const viewport = Size(64, 64);
const origin = Offset(32, 32);

Future<Uint8List> raster(void Function(Canvas) paint) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xff0000ff), BlendMode.src);
  paint(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 64);
  try {
    return (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

List<int> pixel(Uint8List bytes, int x, int y) =>
    bytes.sublist((y * 64 + x) * 4, (y * 64 + x) * 4 + 4);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image oldFrame;
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xffff0000), BlendMode.src);
    final picture = recorder.endRecording();
    oldFrame = await picture.toImage(64, 64);
    picture.dispose();
  });
  tearDownAll(() => oldFrame.dispose());

  final custom = RevealCompletionStrategy.custom(
    (path, progress, viewport, origin) => Path(),
  );
  final strategies = [
    RevealCompletionStrategy.auto,
    RevealCompletionStrategy.preserveShape,
    RevealCompletionStrategy.morphToFullscreen,
    RevealCompletionStrategy.expandAndDissolve,
    custom,
  ];
  for (final requested in strategies) {
    test(
      '${requested.name} leaves no old or effect pixels at progress 1',
      () async {
        // Deliberately incomplete mask, including a transparent center, so a
        // successful endpoint cannot accidentally pass through full coverage.
        final shape = RevealShape.customPath(
          builder: (_) => Path()
            ..fillType = PathFillType.evenOdd
            ..addOval(const Rect.fromLTWH(0, 0, 100, 100))
            ..addOval(const Rect.fromLTWH(30, 30, 40, 40)),
        ).resolve();
        for (final canCover in [true, false]) {
          final strategy = resolveCompletionStrategy(
            requested: requested,
            canCover: canCover,
          );
          final composition = composeReveal(
            shapePath: shape.path.transform(
              Affine.placement(origin: origin, size: 80).matrix,
            ),
            progress: 1,
            viewport: viewport,
            origin: origin,
            strategy: strategy,
            isComplex: true,
          );
          final bytes = await raster(
            (canvas) => RevealPainter(
              snapshot: oldFrame,
              cutout: composition.cutout,
              opacity: composition.opacity,
              edgeColor: Colors.green,
              edgeWidth: 4,
              glowColor: Colors.green,
              glowRadius: 5,
              feather: 4,
            ).paint(canvas, viewport),
          );
          for (var i = 0; i < bytes.length; i += 4) {
            expect(bytes.sublist(i, i + 4), [0, 0, 255, 255]);
          }
        }
      },
    );
  }

  test(
    'all strategies fade continuously into their transparent endpoint',
    () async {
      for (final requested in strategies) {
        final strategy = resolveCompletionStrategy(
          requested: requested,
          canCover: true,
        );
        var previousRed = 255;
        for (final progress in [
          .70,
          .74,
          .78,
          .82,
          .86,
          .88,
          .90,
          .94,
          .97,
          .99,
          .999,
          1.0,
        ]) {
          final composition = composeReveal(
            shapePath: Path(),
            progress: progress,
            viewport: viewport,
            origin: origin,
            strategy: strategy,
            isComplex: true,
          );
          final bytes = await raster(
            (canvas) => RevealPainter(
              snapshot: oldFrame,
              cutout: composition.cutout,
              opacity: composition.opacity,
            ).paint(canvas, viewport),
          );
          final red = pixel(bytes, 0, 0).first;
          expect(red, lessThanOrEqualTo(previousRed));
          expect(previousRed - red, lessThanOrEqualTo(90));
          if (progress == .999) expect(red, lessThanOrEqualTo(3));
          previousRed = red;
        }
        expect(previousRed, 0);
      }
    },
  );

  test('morph is a continuous circle union beginning at completionStart', () {
    final original = Path()..addRect(const Rect.fromLTWH(30, 30, 4, 4));
    RevealComposition at(double progress) => composeReveal(
      shapePath: original,
      progress: progress,
      viewport: viewport,
      origin: origin,
      strategy: RevealCompletionStrategy.morphToFullscreen,
      isComplex: false,
    );
    expect(at(.7).cutout.contains(const Offset(10, 32)), isFalse);
    expect(at(.85).cutout.contains(const Offset(10, 32)), isTrue);
    expect(at(.85).cutout.contains(origin), isTrue);
    expect(at(.999).cutout.contains(const Offset(1, 1)), isTrue);
  });

  test(
    'custom builder receives placed path, raw progress, viewport and origin',
    () {
      final placed = Path()..addRect(const Rect.fromLTWH(20, 20, 20, 20));
      final strategy = RevealCompletionStrategy.custom((
        path,
        progress,
        size,
        from,
      ) {
        expect(path.contains(const Offset(30, 30)), isTrue);
        expect(progress, .4);
        expect(size, viewport);
        expect(from, origin);
        return Path()..addRect(Offset.zero & size);
      });
      final composition = composeReveal(
        shapePath: placed,
        progress: .4,
        viewport: viewport,
        origin: origin,
        strategy: strategy,
        isComplex: false,
      );
      expect(composition.cutout.contains(const Offset(1, 1)), isTrue);
      expect(placed.contains(const Offset(1, 1)), isFalse);
    },
  );

  test(
    'feather softens the vector cutout; edge and glow paint real boundary pixels',
    () async {
      final cutout = Path()..addRect(const Rect.fromLTWH(20, 20, 24, 24));
      Future<Uint8List> paint({
        double feather = 0,
        Color? edge,
        double glow = 0,
      }) => raster(
        (canvas) => RevealPainter(
          snapshot: oldFrame,
          cutout: cutout,
          opacity: 1,
          feather: feather,
          edgeColor: edge,
          edgeWidth: 4,
          glowColor: Colors.green,
          glowRadius: glow,
        ).paint(canvas, viewport),
      );
      final plain = await paint();
      final soft = await paint(feather: 4);
      final edged = await paint(edge: const Color(0xff00ff00));
      final glowing = await paint(glow: 4);
      expect(
        pixel(soft, 20, 32).first,
        greaterThan(pixel(plain, 20, 32).first),
      );
      expect(pixel(soft, 17, 32).first, lessThan(pixel(plain, 17, 32).first));
      expect(pixel(edged, 20, 32)[1], greaterThan(0));
      expect(pixel(glowing, 16, 32)[1], greaterThan(0));
    },
  );

  test(
    'default circle pixels remain identical to the M2 painting pipeline',
    () async {
      final normalized = const RevealShape.circle().resolve();
      for (final raw in [0.0, .2, .5, .98, 1.0]) {
        final progress = Curves.easeInOutCubic.transform(raw);
        final placement = Affine.placement(
          origin: const Offset(21, 43),
          size: 120 * progress,
        );
        final composition = composeReveal(
          shapePath: normalized.path.transform(placement.matrix),
          progress: raw,
          viewport: viewport,
          origin: origin,
          strategy: RevealCompletionStrategy.preserveShape,
          isComplex: false,
        );
        final actual = await raster(
          (canvas) => RevealPainter(
            snapshot: oldFrame,
            cutout: composition.cutout,
            opacity: composition.opacity,
          ).paint(canvas, viewport),
        );
        final expected = await raster((canvas) {
          final opacity = raw < .97 ? 1.0 : ((1 - raw) / .03).clamp(0.0, 1.0);
          canvas.saveLayer(
            Offset.zero & viewport,
            Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
          );
          canvas.drawImageRect(
            oldFrame,
            const Rect.fromLTWH(0, 0, 64, 64),
            Offset.zero & viewport,
            Paint()..filterQuality = FilterQuality.low,
          );
          canvas.drawPath(
            (Path()..addOval(const Rect.fromLTWH(-.5, -.5, 1, 1))).transform(
              placement.matrix,
            ),
            Paint()..blendMode = BlendMode.dstOut,
          );
          canvas.restore();
        });
        expect(actual, orderedEquals(expected));
      }
    },
  );
}
