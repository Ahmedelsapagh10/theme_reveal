import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/src/shapes/raster_mask_resolver.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

import '../support/mask_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => RevealShape.clearCache());
  tearDown(() {
    RevealShape.clearCache();
    RasterMaskResolver.debugOnCreate = null;
    RasterMaskResolver.debugOnDispose = null;
  });

  test(
    'transparent is empty; partial alpha survives; an opaque image is a rectangle',
    () async {
      final empty = await pngFixture(8, 8, (_) {});
      await expectLater(
        RevealShape.bytes(empty).resolveAsync(),
        throwsA(isA<RevealShapeException>()),
      );
      for (final alpha in [128, 255]) {
        final bytes = await pngFixture(
          8,
          4,
          (canvas) => canvas.drawRect(
            const Rect.fromLTWH(0, 0, 8, 4),
            Paint()..color = Color.fromARGB(alpha, 10, 30, 50),
          ),
        );
        final shape = await RevealShape.bytes(bytes).resolveAsync();
        expect(shape.isRaster, isTrue);
        expect(shape.bounds, const Rect.fromLTWH(-.5, -.25, 1, .5));
        expect(shape.containsUnit(Offset.zero), isTrue);
        expect(shape.containsUnit(const Offset(.49, .24)), isTrue);
        final rgba = (await shape.alphaImage!.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        expect(rgba.getUint8(3), alpha);
      }
    },
  );

  test(
    'threshold and trim use surviving pixels and preserve transparent holes',
    () async {
      final bytes = await pngFixture(10, 10, (canvas) {
        canvas.drawRect(
          const Rect.fromLTWH(2, 2, 6, 6),
          Paint()
            ..color = const Color(0x80ffffff)
            ..isAntiAlias = false,
        );
        canvas.drawRect(
          const Rect.fromLTWH(4, 4, 2, 2),
          Paint()
            ..blendMode = BlendMode.clear
            ..isAntiAlias = false,
        );
      });
      final trimmed = await RevealShape.bytes(
        bytes,
        alphaThreshold: 128,
      ).resolveAsync();
      final framed = await RevealShape.bytes(bytes, trim: false).resolveAsync();
      expect(trimmed.alphaImage!.width, 6);
      expect(framed.alphaImage!.width, 10);
      expect(trimmed.containsUnit(Offset.zero), isFalse);
      expect(trimmed.containsUnit(const Offset(.4, 0)), isTrue);
      expect(framed.containsUnit(const Offset(.4, 0)), isFalse);
      await expectLater(
        RevealShape.bytes(bytes, alphaThreshold: 129).resolveAsync(),
        throwsA(isA<RevealShapeException>()),
      );
      for (final threshold in [0, 256]) {
        await expectLater(
          RevealShape.bytes(bytes, alphaThreshold: threshold).resolveAsync(),
          throwsA(isA<RevealShapeException>()),
        );
      }
    },
  );

  test(
    'decode caps longest side at 256 and rejects inputs over 8 MiB',
    () async {
      final bytes = await pngFixture(
        1024,
        512,
        (canvas) => canvas.drawColor(Colors.white, BlendMode.src),
      );
      final shape = await RevealShape.bytes(bytes).resolveAsync();
      expect(shape.alphaImage!.width, 256);
      expect(shape.alphaImage!.height, 128);
      expect(
        () => RevealShape.bytes(Uint8List(8 * 1024 * 1024 + 1)),
        throwsA(isA<RevealShapeException>()),
      );
      final bundle = MaskBundle({'huge': Uint8List(8 * 1024 * 1024 + 1)});
      await expectLater(
        RevealShape.pngAsset('huge', bundle: bundle).resolveAsync(),
        throwsA(isA<RevealShapeException>()),
      );
    },
  );

  test(
    'input bytes are copied; cache is shared by source/options and concurrent loads',
    () async {
      final bytes = await pngFixture(
        4,
        4,
        (canvas) => canvas.drawColor(Colors.white, BlendMode.src),
      );
      final original = Uint8List.fromList(bytes);
      final shape = RevealShape.bytes(bytes);
      bytes[0] = 0;
      final a = await shape.resolveAsync();
      expect(await RevealShape.bytes(original).resolveAsync(), same(a));
      final bundle = MaskBundle({'packages/brand/logo.png': original});
      final first = RevealShape.pngAsset(
        'logo.png',
        package: 'brand',
        bundle: bundle,
      );
      final second = RevealShape.pngAsset(
        'logo.png',
        package: 'brand',
        bundle: bundle,
      );
      final both = await Future.wait([
        first.resolveAsync(),
        second.resolveAsync(),
      ]);
      expect(both.first, same(both.last));
      expect(bundle.loads, ['packages/brand/logo.png']);
      expect(
        await RevealShape.pngAsset(
          'logo.png',
          package: 'brand',
          bundle: bundle,
          trim: false,
        ).resolveAsync(),
        isNot(same(both.first)),
      );
      expect(
        await RevealShape.pngAsset(
          'logo.png',
          package: 'brand',
          bundle: bundle,
          alphaThreshold: 200,
        ).resolveAsync(),
        isNot(same(both.first)),
      );
    },
  );

  test(
    'source pixel cap rejects oversized image headers before creating a codec',
    () async {
      final original = await pngFixture(
        1,
        1,
        (canvas) => canvas.drawColor(Colors.white, BlendMode.src),
      );
      final bytes = Uint8List.fromList(original);
      final data = ByteData.sublistView(bytes);
      data.setUint32(16, 8192);
      data.setUint32(20, 8192);
      var crc = 0xffffffff;
      for (final byte in bytes.sublist(12, 29)) {
        crc ^= byte;
        for (var i = 0; i < 8; i++) {
          crc = (crc & 1) != 0 ? 0xedb88320 ^ (crc >> 1) : crc >> 1;
        }
      }
      data.setUint32(29, crc ^ 0xffffffff);
      final created = <Object>[];
      RasterMaskResolver.debugOnCreate = created.add;
      await expectLater(
        RevealShape.bytes(bytes).resolveAsync(),
        throwsA(
          isA<RevealShapeException>().having(
            (error) => error.message,
            'message',
            contains('16 megapixel'),
          ),
        ),
      );
      expect(created.whereType<ui.Codec>(), isEmpty);
      for (final buffer in created.whereType<ui.ImmutableBuffer>()) {
        expect(buffer.debugDisposed, isTrue);
      }
    },
  );

  test(
    'eviction disposes cached image while retained active handles remain usable',
    () async {
      final bytes = await pngFixture(
        4,
        4,
        (canvas) => canvas.drawColor(Colors.white, BlendMode.src),
      );
      final cached = await RevealShape.bytes(bytes).resolveAsync();
      final image = cached.alphaImage!;
      final retained = cached.retain();
      for (var i = 0; i < 12; i++) {
        RevealShape.rectangle(aspectRatio: i + 1).resolve();
      }
      expect(RevealShape.debugCacheLength, 12);
      expect(image.debugDisposed, isTrue);
      expect(cached.isDisposed, isTrue);
      expect(retained.alphaImage!.debugDisposed, isFalse);
      expect(retained.containsUnit(Offset.zero), isTrue);
      retained.dispose();
      retained.dispose();
      expect(retained.alphaImage!.debugDisposed, isTrue);
      expect(() => cached.retain(), throwsA(isA<RevealShapeException>()));
    },
  );

  test(
    'all temporary buffers, descriptors, codecs and images dispose on success/failure',
    () async {
      final created = <Object>[];
      final disposed = <Object>[];
      RasterMaskResolver.debugOnCreate = created.add;
      RasterMaskResolver.debugOnDispose = disposed.add;
      final bytes = await pngFixture(
        4,
        4,
        (canvas) => canvas.drawColor(Colors.white, BlendMode.src),
      );
      final result = await RasterMaskResolver.decode(bytes);
      expect(created.whereType<ui.Codec>().length, 2);
      expect(created.whereType<ui.ImageDescriptor>().length, 2);
      expect(created.whereType<ui.ImmutableBuffer>().length, 2);
      expect(disposed.toSet(), created.toSet());
      for (final image in created.whereType<ui.Image>()) {
        expect(image.debugDisposed, isTrue);
      }
      for (final buffer in created.whereType<ui.ImmutableBuffer>()) {
        expect(buffer.debugDisposed, isTrue);
      }
      expect(result.image.debugDisposed, isFalse);
      result.image.dispose();
      created.clear();
      disposed.clear();
      await expectLater(
        RasterMaskResolver.decode(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<RevealShapeException>()),
      );
      expect(disposed.toSet(), created.toSet());
      created.clear();
      disposed.clear();
      final transparent = await pngFixture(4, 4, (_) {});
      await expectLater(
        RasterMaskResolver.decode(transparent),
        throwsA(isA<RevealShapeException>()),
      );
      expect(disposed.toSet(), created.toSet());
    },
  );

  test(
    'icon uses the real glyph silhouette; missing/empty glyphs are rejected',
    () async {
      final loader = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await loader.load();
      final icon = await const RevealShape.icon(Icons.star).resolveAsync();
      expect(icon.isRaster, isTrue);
      expect(icon.alphaImage!.width, lessThanOrEqualTo(256));
      expect(icon.containsUnit(Offset.zero), isTrue);
      expect(icon.containsUnit(const Offset(.49, .49)), isFalse);
      for (final data in [
        const IconData(0, fontFamily: 'MaterialIcons'),
        const IconData(0x10ffff, fontFamily: 'MaterialIcons'),
        const IconData(0xe87d, fontFamily: 'DefinitelyMissingFont'),
      ]) {
        await expectLater(
          RevealShape.icon(data).resolveAsync(),
          throwsA(isA<RevealShapeException>()),
        );
      }
    },
  );

  test(
    'icon rasterization releases its temporary and replacement-glyph images',
    () async {
      final images = <ui.Image>[];
      final previous = ui.Image.onCreate;
      ui.Image.onCreate = (image) {
        images.add(image);
        previous?.call(image);
      };
      try {
        final shape = await const RevealShape.icon(
          Icons.favorite,
        ).resolveAsync();
        expect(images.where((image) => !image.debugDisposed).toList(), [
          shape.alphaImage,
        ]);
        RevealShape.clearCache();
        expect(images.every((image) => image.debugDisposed), isTrue);
      } finally {
        ui.Image.onCreate = previous;
      }
    },
  );
}
