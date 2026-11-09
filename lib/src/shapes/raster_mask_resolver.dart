import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'reveal_shape.dart';

/// Internal bounded alpha data and its owned native mask image.
class RasterMaskData {
  /// Creates a decoded mask, alpha bytes, dimensions and threshold.
  const RasterMaskData(
    this.image,
    this.alpha,
    this.width,
    this.height,
    this.threshold,
  );

  /// Owned alpha image passed to the resolution cache.
  final ui.Image image;

  /// Row-major per-pixel alpha retained for coverage sampling.
  final Uint8List alpha;

  /// Decoded dimensions and the minimum surviving alpha value.
  final int width, height, threshold;
}

/// Bounded decode and alpha extraction. Only the returned mask image survives.
abstract final class RasterMaskResolver {
  /// Maximum encoded input bytes (8 MiB).
  static const maxBytes = 8 * 1024 * 1024;

  /// Maximum source image area (16 megapixels).
  static const maxSourcePixels = 16 * 1024 * 1024;

  /// Maximum decoded longest side (256 pixels).
  static const maxSide = 256;

  /// Debug-only resource creation instrumentation for disposal tests.
  @visibleForTesting
  static void Function(Object)? debugOnCreate;

  /// Debug-only resource disposal instrumentation.
  @visibleForTesting
  static void Function(Object)? debugOnDispose;

  static T _created<T extends Object>(T resource) {
    assert(() {
      debugOnCreate?.call(resource);
      return true;
    }());
    return resource;
  }

  static void _disposed(Object resource) {
    assert(() {
      debugOnDispose?.call(resource);
      return true;
    }());
  }

  /// Rejects alpha thresholds outside 1–255.
  static void validateThreshold(int threshold) {
    if (threshold < 1 || threshold > 255) {
      throw const RevealShapeException(
        'alphaThreshold must be between 1 and 255.',
      );
    }
  }

  /// Decodes the first bounded image frame, extracts alpha and disposes temporaries.
  static Future<RasterMaskData> decode(
    Uint8List bytes, {
    int alphaThreshold = 1,
    bool trim = true,
  }) async {
    validateThreshold(alphaThreshold);
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const RevealShapeException(
        'Raster input must contain 1–8388608 bytes (8 MiB maximum).',
      );
    }
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      buffer = _created(await ui.ImmutableBuffer.fromUint8List(bytes));
      descriptor = _created(await ui.ImageDescriptor.encoded(buffer));
      if (descriptor.width <= 0 ||
          descriptor.height <= 0 ||
          descriptor.width * descriptor.height > maxSourcePixels) {
        throw const RevealShapeException(
          'Raster source exceeds the 16 megapixel decode limit.',
        );
      }
      final scale = math.min(
        1.0,
        maxSide / math.max(descriptor.width, descriptor.height),
      );
      codec = _created(
        await descriptor.instantiateCodec(
          targetWidth: math.max(1, (descriptor.width * scale).floor()),
          targetHeight: math.max(1, (descriptor.height * scale).floor()),
        ),
      );
      image = _created((await codec.getNextFrame()).image);
      return await _extract(image, alphaThreshold: alphaThreshold, trim: trim);
    } on RevealShapeException {
      rethrow;
    } catch (error) {
      throw RevealShapeException('Could not decode raster mask.', error);
    } finally {
      if (image != null) {
        image.dispose();
        _disposed(image);
      }
      if (codec != null) {
        codec.dispose();
        _disposed(codec);
      }
      if (descriptor != null) {
        descriptor.dispose();
        _disposed(descriptor);
      }
      if (buffer != null) {
        buffer.dispose();
        _disposed(buffer);
      }
    }
  }

  static Future<RasterMaskData> _extract(
    ui.Image image, {
    required int alphaThreshold,
    required bool trim,
  }) async {
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgba == null) {
      throw const RevealShapeException('Raster pixels could not be read.');
    }
    var left = image.width, top = image.height, right = -1, bottom = -1;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        if (rgba.getUint8((y * image.width + x) * 4 + 3) >= alphaThreshold) {
          left = math.min(left, x);
          top = math.min(top, y);
          right = math.max(right, x);
          bottom = math.max(bottom, y);
        }
      }
    }
    if (right < left) {
      throw const RevealShapeException(
        'Raster mask is empty at the selected alpha threshold.',
      );
    }
    if (!trim) {
      left = 0;
      top = 0;
      right = image.width - 1;
      bottom = image.height - 1;
    }
    final width = right - left + 1, height = bottom - top + 1;
    final alpha = Uint8List(width * height);
    final pixels = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final a = rgba.getUint8(((y + top) * image.width + x + left) * 4 + 3);
        final value = a >= alphaThreshold ? a : 0;
        final index = y * width + x;
        alpha[index] = value;
        // White RGB with the original surviving alpha; no color segmentation.
        pixels[index * 4] = 255;
        pixels[index * 4 + 1] = 255;
        pixels[index * 4 + 2] = 255;
        pixels[index * 4 + 3] = value;
      }
    }
    return RasterMaskData(
      await _fromPixels(pixels, width, height),
      alpha,
      width,
      height,
      alphaThreshold,
    );
  }

  static Future<ui.Image> _fromPixels(
    Uint8List pixels,
    int width,
    int height,
  ) async {
    final buffer = _created(await ui.ImmutableBuffer.fromUint8List(pixels));
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = _created(
        ui.ImageDescriptor.raw(
          buffer,
          width: width,
          height: height,
          pixelFormat: ui.PixelFormat.rgba8888,
        ),
      );
      codec = _created(await descriptor.instantiateCodec());
      return (await codec.getNextFrame()).image;
    } finally {
      if (codec != null) {
        codec.dispose();
        _disposed(codec);
      }
      if (descriptor != null) {
        descriptor.dispose();
        _disposed(descriptor);
      }
      buffer.dispose();
      _disposed(buffer);
    }
  }

  /// Rasterizes a loaded icon glyph and rejects empty/missing-glyph masks.
  static Future<RasterMaskData> icon(IconData icon) async {
    if (icon.codePoint <= 0 ||
        icon.codePoint > 0x10ffff ||
        (icon.codePoint >= 0xd800 && icon.codePoint <= 0xdfff)) {
      throw const RevealShapeException(
        'Icon code point is not a valid visible glyph.',
      );
    }
    final mask = await _glyph(icon, icon.codePoint);
    RasterMaskData? missing;
    try {
      // TextPainter can draw a replacement box instead of an absent glyph.
      // Compare its tight alpha mask as well as rejecting genuinely empty masks.
      try {
        missing = await _glyph(icon, 0x10ffff);
      } on RevealShapeException {
        /* Some fonts have no replacement glyph. */
      }
      if (missing != null &&
          mask.width == missing.width &&
          mask.height == missing.height &&
          listEquals(mask.alpha, missing.alpha)) {
        throw const RevealShapeException(
          'Icon glyph is missing. Load the requested font before resolving this mask.',
        );
      }
      return mask;
    } catch (_) {
      mask.image.dispose();
      rethrow;
    } finally {
      missing?.image.dispose();
    }
  }

  static Future<RasterMaskData> _glyph(IconData icon, int codePoint) async {
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(codePoint),
        style: TextStyle(
          fontSize: 160,
          color: const Color(0xffffffff),
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontFamilyFallback: icon.fontFamilyFallback,
        ),
      ),
    );
    ui.Picture? picture;
    ui.Image? image;
    try {
      painter.layout();
      final width = (painter.width + 64).ceil(),
          height = (painter.height + 64).ceil();
      if (width <= 0 || height <= 0 || width > 1024 || height > 1024) {
        throw const RevealShapeException(
          'Icon glyph has invalid or excessive layout bounds.',
        );
      }
      final scale = math.min(1.0, maxSide / math.max(width, height));
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(scale);
      painter.paint(canvas, const Offset(32, 32));
      picture = _created(recorder.endRecording());
      image = _created(
        await picture.toImage(
          math.max(1, (width * scale).ceil()),
          math.max(1, (height * scale).ceil()),
        ),
      );
      return await _extract(image, alphaThreshold: 1, trim: true);
    } finally {
      if (image != null) {
        image.dispose();
        _disposed(image);
      }
      if (picture != null) {
        picture.dispose();
        _disposed(picture);
      }
      painter.dispose();
    }
  }
}
