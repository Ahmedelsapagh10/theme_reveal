import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/src/rendering/reveal_composition.dart';
import 'package:theme_reveal_kit/src/rendering/reveal_geometry.dart';
import 'package:theme_reveal_kit/src/rendering/reveal_painter.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

import '../support/mask_fixtures.dart';
import 'vector_painter_test.dart' show raster, pixel, viewport, origin;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image oldFrame;
  late Uint8List ring;
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.red, BlendMode.src);
    final picture = recorder.endRecording();
    oldFrame = await picture.toImage(64, 64);
    picture.dispose();
    ring = await pngFixture(32, 32, (canvas) {
      canvas.drawCircle(
        const Offset(16, 16),
        15,
        Paint()
          ..color = Colors.white
          ..isAntiAlias = false,
      );
      canvas.drawCircle(
        const Offset(16, 16),
        6,
        Paint()
          ..blendMode = BlendMode.clear
          ..isAntiAlias = false,
      );
    });
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  tearDownAll(() {
    RevealShape.clearCache();
    oldFrame.dispose();
  });

  Future<Uint8List> paint(
    ResolvedShape shape,
    RevealCompletionStrategy requested,
    double progress, {
    bool effects = false,
  }) async {
    final coverage = solveCoverage(
      containsUnit: shape.containsUnit,
      unitBounds: shape.bounds,
      viewport: viewport,
      origin: origin,
    );
    final strategy = resolveCompletionStrategy(
      requested: requested,
      canCover: coverage.canCover,
    );
    final placement = Affine.placement(
      origin: origin,
      size: 48,
      bounds: shape.bounds,
    );
    final composition = composeReveal(
      shapePath: shape.path.transform(placement.matrix),
      progress: progress,
      viewport: viewport,
      origin: origin,
      strategy: strategy,
      isComplex: shape.isComplex,
    );
    return raster(
      (canvas) => RevealPainter(
        snapshot: oldFrame,
        cutout: composition.cutout,
        opacity: composition.opacity,
        alphaMask: shape.alphaImage,
        maskBounds: shape.bounds,
        maskPlacement: placement,
        rasterUsesCustomPath: strategy.builder != null,
        rasterCompletionCutout:
            strategy == RevealCompletionStrategy.morphToFullscreen
            ? composeReveal(
                shapePath: Path(),
                progress: progress,
                viewport: viewport,
                origin: origin,
                strategy: strategy,
                isComplex: true,
              ).cutout
            : null,
        edgeColor: effects ? Colors.green : null,
        edgeWidth: effects ? 4 : 0,
        glowColor: effects ? Colors.green : null,
        glowRadius: effects ? 10 : 0,
        feather: effects ? 8 : 0,
      ).paint(canvas, viewport),
    );
  }

  test(
    'all asset sources and every strategy leave no old pixels at progress 1',
    () async {
      const svg =
          '<svg viewBox="0 0 100 100"><path fill-rule="evenodd" d="M0 0H100V100H0Z M30 30H70V70H30Z"/></svg>';
      const json =
          '{"type":"path","viewBox":[0,0,100,100],"paths":[{"d":"M50 0L100 100H0Z"}]}';
      final bundle = MaskBundle({
        'logo.png': ring,
        'logo.svg': Uint8List.fromList(utf8.encode(svg)),
        'shape.json': Uint8List.fromList(utf8.encode(json)),
      });
      final sources = [
        RevealShape.bytes(ring),
        const RevealShape.icon(Icons.star),
        const RevealShape.svgString(svg),
        const RevealShape.jsonString(json),
        RevealShape.pngAsset('logo.png', bundle: bundle),
        RevealShape.svgAsset('logo.svg', bundle: bundle),
        RevealShape.jsonAsset('shape.json', bundle: bundle),
      ];
      for (final source in sources) {
        final shape = (await source.resolveAsync()).retain();
        try {
          for (final strategy in [
            RevealCompletionStrategy.auto,
            RevealCompletionStrategy.preserveShape,
            RevealCompletionStrategy.morphToFullscreen,
            RevealCompletionStrategy.expandAndDissolve,
            RevealCompletionStrategy.custom(
              (path, progress, viewport, origin) => path,
            ),
          ]) {
            final bytes = await paint(shape, strategy, 1, effects: true);
            for (var i = 0; i < bytes.length; i += 4) {
              expect(bytes.sublist(i, i + 4), [0, 0, 255, 255]);
            }
          }
        } finally {
          shape.dispose();
        }
      }
    },
  );

  test(
    'PNG cutout respects the alpha silhouette and transparent center; effects are ignored',
    () async {
      final shape = (await RevealShape.bytes(ring).resolveAsync()).retain();
      try {
        final ordinary = await paint(shape, RevealCompletionStrategy.auto, .25);
        final effects = await paint(
          shape,
          RevealCompletionStrategy.auto,
          .25,
          effects: true,
        );
        expect(pixel(ordinary, 32, 32).first, greaterThan(200));
        expect(pixel(ordinary, 50, 32)[2], greaterThan(200));
        expect(effects, orderedEquals(ordinary));
        final result = solveCoverage(
          containsUnit: shape.containsUnit,
          unitBounds: shape.bounds,
          viewport: viewport,
          origin: origin,
        );
        expect(result.canCover, isFalse);
        expect(
          resolveCompletionStrategy(
            requested: RevealCompletionStrategy.auto,
            canCover: result.canCover,
          ),
          RevealCompletionStrategy.expandAndDissolve,
        );
      } finally {
        shape.dispose();
      }
    },
  );

  test(
    'partially transparent PNG reveals proportionally rather than using a rectangular binary mask',
    () async {
      final bytes = await pngFixture(
        16,
        16,
        (canvas) => canvas.drawColor(const Color(0x80ffffff), BlendMode.src),
      );
      final shape = (await RevealShape.bytes(bytes).resolveAsync()).retain();
      try {
        final pixels = await paint(
          shape,
          RevealCompletionStrategy.preserveShape,
          .2,
        );
        final center = pixel(pixels, 32, 32);
        expect(center[0], inInclusiveRange(100, 155));
        expect(center[2], inInclusiveRange(100, 155));
      } finally {
        shape.dispose();
      }
    },
  );
}
