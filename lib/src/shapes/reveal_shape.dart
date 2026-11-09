import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show IconData;

import 'raster_mask_resolver.dart';
import 'vector_asset_parser.dart';

import '../utils/reveal_exception.dart';

/// Invalid, empty, unsupported or failed-to-load reveal geometry.
class RevealShapeException extends RevealException {
  /// Creates a readable shape error and optional underlying cause.
  const RevealShapeException(super.message, [super.cause]);

  @override
  String toString() =>
      'RevealShapeException: $message${cause == null ? '' : ' ($cause)'}';
}

enum _ShapeKind {
  circle,
  ellipse,
  rectangle,
  roundedRectangle,
  triangle,
  star,
  heart,
  diamond,
  hexagon,
  polygon,
  custom,
  icon,
  pngAsset,
  bytes,
  svgAsset,
  svgString,
  jsonAsset,
  jsonString,
}

/// Immutable mask description. The shared LRU cache retains at most 12
/// resolved shapes. A custom builder must be deterministic for its shape instance.
@immutable
class RevealShape {
  /// Creates the default circular vector silhouette.
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// const RevealShape.circle();
  /// ```
  const RevealShape.circle() : this._(_ShapeKind.circle);

  /// Creates an ellipse with width/height aspectRatio (default 1.5).
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// const RevealShape.ellipse(aspectRatio: 2);
  /// ```
  const RevealShape.ellipse({double aspectRatio = 1.5})
    : this._(_ShapeKind.ellipse, aspectRatio: aspectRatio);

  /// Creates a rectangle with width/height aspectRatio (default 1.5).
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// const RevealShape.rectangle(aspectRatio: 2);
  /// ```
  const RevealShape.rectangle({double aspectRatio = 1.5})
    : this._(_ShapeKind.rectangle, aspectRatio: aspectRatio);

  /// [cornerRadius] is in normalized longest-side units, clamped to half the
  /// shortest side. [aspectRatio] is width / height, before placement rotation.
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// const RevealShape.roundedRectangle(cornerRadius: .2);
  /// ```
  const RevealShape.roundedRectangle({
    double cornerRadius = .16,
    double aspectRatio = 1.5,
  }) : this._(
         _ShapeKind.roundedRectangle,
         aspectRatio: aspectRatio,
         cornerRadius: cornerRadius,
       );

  /// Creates an upright equilateral triangle.
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// const RevealShape.triangle();
  /// ```
  const RevealShape.triangle() : this._(_ShapeKind.triangle);

  /// Creates a regular star with 2–512 points and 0 < innerRadius < 1.
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// const RevealShape.star(points: 5, innerRadius: .45);
  /// ```
  const RevealShape.star({int points = 5, double innerRadius = .45})
    : this._(_ShapeKind.star, points: points, innerRadius: innerRadius);

  /// Creates a filled cubic-curve heart.
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// const RevealShape.heart();
  /// ```
  const RevealShape.heart() : this._(_ShapeKind.heart);

  /// Creates a four-vertex diamond.
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// const RevealShape.diamond();
  /// ```
  const RevealShape.diamond() : this._(_ShapeKind.diamond);

  /// Creates a regular six-sided polygon.
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// const RevealShape.hexagon();
  /// ```
  const RevealShape.hexagon() : this._(_ShapeKind.hexagon);

  /// Creates a regular polygon with 3–512 sides.
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// const RevealShape.polygon(sides: 8);
  /// ```
  const RevealShape.polygon({required int sides})
    : this._(_ShapeKind.polygon, points: sides);

  /// Invoked with Size(100, 100), then normalized by its own bounds. Filled open
  /// contours are allowed; empty, non-finite and zero-area geometry is rejected.
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// RevealShape.customPath(
  ///   builder: (size) => Path()..addOval(Offset.zero & size),
  /// );
  /// ```
  const RevealShape.customPath({required Path Function(Size) builder})
    : this._(_ShapeKind.custom, builder: builder);

  /// Rasterizes and tightly trims a loaded icon-font glyph.
  ///
  /// Custom fonts must be loaded first. Missing-glyph/empty masks are errors;
  /// a fallback font containing the glyph may still render it.
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// const RevealShape.icon(Icons.favorite);
  /// ```
  const RevealShape.icon(IconData icon) : this._(_ShapeKind.icon, source: icon);

  /// Decodes a bundled alpha mask, capped at 8 MiB, 16 MP input and 256px output.
  ///
  /// alphaThreshold is 1–255; trim removes transparent margins. Partial alpha
  /// is preserved above threshold. Fully opaque input is a rectangle.
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// const RevealShape.pngAsset('assets/logo.png', trim: true);
  /// ```
  const RevealShape.pngAsset(
    String asset, {
    String? package,
    AssetBundle? bundle,
    int alphaThreshold = 1,
    bool trim = true,
  }) : this._(
         _ShapeKind.pngAsset,
         source: asset,
         package: package,
         bundle: bundle,
         alphaThreshold: alphaThreshold,
         trim: trim,
       );

  /// Copies encoded image bytes and decodes their first frame as an alpha mask.
  ///
  /// Uses the same limits, alpha threshold and trimming as pngAsset. Empty or
  /// oversized byte input throws immediately; other failures occur on resolution.
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// final data = await rootBundle.load('assets/logo.png');
  /// RevealShape.bytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  /// ```
  factory RevealShape.bytes(
    Uint8List bytes, {
    int alphaThreshold = 1,
    bool trim = true,
  }) {
    if (bytes.isEmpty || bytes.length > RasterMaskResolver.maxBytes) {
      /// Creates a readable shape error and optional underlying cause.
      throw const RevealShapeException(
        'Raster input must contain 1–8388608 bytes.',
      );
    }
    return RevealShape._(
      _ShapeKind.bytes,
      source: _ByteSource(Uint8List.fromList(bytes)),
      alphaThreshold: alphaThreshold,
      trim: trim,
    );
  }

  /// Loads a bounded SVG filled silhouette from an app or package asset bundle.
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// const RevealShape.svgAsset('assets/logo.svg');
  /// ```
  const RevealShape.svgAsset(
    String asset, {
    String? package,
    AssetBundle? bundle,
  }) : this._(
         _ShapeKind.svgAsset,
         source: asset,
         package: package,
         bundle: bundle,
       );

  /// Describes a bounded, data-only SVG silhouette; unsupported features warn.
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// const RevealShape.svgString(
  ///   '<svg viewBox="0 0 10 10"><circle cx="5" cy="5" r="5"/></svg>',
  /// );
  /// ```
  const RevealShape.svgString(String source)
    : this._(_ShapeKind.svgString, source: source);

  /// Loads a strict path/shape JSON document from an app or package asset bundle.
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// const RevealShape.jsonAsset('assets/custom_shape.json');
  /// ```
  const RevealShape.jsonAsset(
    String asset, {
    String? package,
    AssetBundle? bundle,
  }) : this._(
         _ShapeKind.jsonAsset,
         source: asset,
         package: package,
         bundle: bundle,
       );

  /// Describes a strict path/shape JSON document; Lottie input is rejected.
  ///
  /// ```dart
  /// // Pass this shape to RevealThemeButton.revealShape or viewport.reveal(shape: ...).
  /// const RevealShape.jsonString('{"type":"shape","shape":"heart"}');
  /// ```
  const RevealShape.jsonString(String source)
    : this._(_ShapeKind.jsonString, source: source);

  const RevealShape._(
    this._kind, {
    double aspectRatio = 1,
    double cornerRadius = 0,
    int points = 5,
    double innerRadius = .45,
    Path Function(Size)? builder,
    Object? source,
    String? package,
    AssetBundle? bundle,
    int alphaThreshold = 1,
    bool trim = true,
  }) : _aspectRatio = aspectRatio,
       _cornerRadius = cornerRadius,
       _points = points,
       _innerRadius = innerRadius,
       _builder = builder,
       _source = source,
       _package = package,
       _bundle = bundle,
       _alphaThreshold = alphaThreshold,
       _trim = trim;

  final _ShapeKind _kind;
  final double _aspectRatio;
  final double _cornerRadius;
  final int _points;
  final double _innerRadius;
  final Path Function(Size)? _builder;
  final Object? _source;
  final String? _package;
  final AssetBundle? _bundle;
  final int _alphaThreshold;
  final bool _trim;
  static final _cache = <Object, ResolvedShape>{};
  static final _pending = <Object, Future<ResolvedShape>>{};

  /// Number of completed entries in the shared 12-entry LRU (testing only).
  @visibleForTesting
  static int get debugCacheLength => _cache.length;

  /// Low-level guidance: true for icons, encoded bytes and bundled assets.
  ///
  /// The engine chooses resolve/resolveAsync automatically; applications
  /// normally pass this description directly to their theme control.
  bool get requiresAsync => switch (_kind) {
    _ShapeKind.icon ||
    _ShapeKind.pngAsset ||
    _ShapeKind.bytes ||
    _ShapeKind.svgAsset ||
    _ShapeKind.jsonAsset => true,
    _ => false,
  };
  Object get _key => _source == null
      ? this
      : (
          _kind,
          _source,
          _package,
          _bundle ?? rootBundle,
          _alphaThreshold,
          _trim,
        );
  static ResolvedShape? _cached(Object key) {
    final value = _cache.remove(key);
    if (value != null && !value.isDisposed) {
      _cache[key] = value;
      return value;
    }
    return null;
  }

  static ResolvedShape _store(Object key, ResolvedShape result) {
    _cache.remove(key)?.dispose();
    _cache[key] = result;
    if (_cache.length > 12) _cache.remove(_cache.keys.first)?.dispose();
    return result;
  }

  /// Clears completed cache entries. Active reveals own retained image handles;
  /// in-flight asset loads may populate the cache after this call returns.
  static void clearCache() {
    for (final value in _cache.values) {
      value.dispose();
    }
    _cache.clear();
  }

  /// Low-level synchronous vector resolution for engine/advanced use.
  ///
  /// Controls resolve automatically. Asset-backed masks require [resolveAsync].
  /// The result is cache-owned; retain it before independently owning a raster
  /// handle and never dispose a borrowed cache result.
  ResolvedShape resolve() {
    if (requiresAsync) {
      /// Creates a readable shape error and optional underlying cause.
      throw const RevealShapeException(
        'This mask needs asynchronous loading. Use resolveAsync().',
      );
    }
    final key = _key;
    final cached = _cached(key);
    if (cached != null) return cached;
    try {
      return _store(key, _resolve());
    } on RevealShapeException {
      rethrow;
    } catch (error) {
      throw RevealShapeException('Could not resolve the vector shape.', error);
    }
  }

  /// Low-level engine resolution for any source, sharing cached/pending loads.
  ///
  /// Application controls resolve automatically. The returned result is
  /// cache-owned: do not dispose it; retain it for independently owned use.
  /// Throws RevealShapeException on invalid or failed input.
  Future<ResolvedShape> resolveAsync() {
    if (!requiresAsync) return Future.sync(resolve);
    final key = _key;
    final cached = _cached(key);
    if (cached != null) return Future.value(cached);
    return _pending.putIfAbsent(key, () async {
      try {
        return _store(key, await _load());
      } on RevealShapeException {
        rethrow;
      } catch (error) {
        throw RevealShapeException('Could not load asset mask.', error);
      } finally {
        _pending.remove(key);
      }
    });
  }

  Future<Uint8List> _asset(int limit) async {
    final asset = _source! as String;
    final path = _package == null ? asset : 'packages/$_package/$asset';
    final data = await (_bundle ?? rootBundle).load(path);
    if (data.lengthInBytes > limit) {
      throw RevealShapeException('Asset exceeds the $limit byte limit.');
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<ResolvedShape> _load() async {
    if (_kind == _ShapeKind.icon) {
      return ResolvedShape.raster(
        await RasterMaskResolver.icon(_source! as IconData),
      );
    }
    if (_kind == _ShapeKind.bytes || _kind == _ShapeKind.pngAsset) {
      final bytes = _kind == _ShapeKind.bytes
          ? (_source! as _ByteSource).bytes
          : await _asset(RasterMaskResolver.maxBytes);
      return ResolvedShape.raster(
        await RasterMaskResolver.decode(
          bytes,
          alphaThreshold: _alphaThreshold,
          trim: _trim,
        ),
      );
    }
    final source = utf8.decode(await _asset(VectorAssetParser.maxBytes));
    return _vector(
      _kind == _ShapeKind.svgAsset
          ? VectorAssetParser.svg(source)
          : VectorAssetParser.json(source),
    );
  }

  static ResolvedShape _vector(VectorMaskData data) => ResolvedShape(
    data.path,
    frame: data.frame,
    warnings: data.warnings,
    isComplex: true,
  );

  ResolvedShape _resolve() {
    if (_kind == _ShapeKind.svgString) {
      return _vector(VectorAssetParser.svg(_source! as String));
    }
    if (_kind == _ShapeKind.jsonString) {
      return _vector(VectorAssetParser.json(_source! as String));
    }
    if (!_aspectRatio.isFinite ||
        _aspectRatio <= 0 ||
        !_cornerRadius.isFinite ||
        _cornerRadius < 0) {
      /// Creates a readable shape error and optional underlying cause.
      throw const RevealShapeException(
        'Aspect ratio must be positive and corner radius non-negative, both finite.',
      );
    }
    if ((_kind == _ShapeKind.star &&
            (_points < 2 ||
                _points > 512 ||
                !_innerRadius.isFinite ||
                _innerRadius <= 0 ||
                _innerRadius >= 1)) ||
        (_kind == _ShapeKind.polygon && (_points < 3 || _points > 512))) {
      /// Creates a readable shape error and optional underlying cause.
      throw const RevealShapeException(
        'Use 2–512 star points with 0 < innerRadius < 1, or 3–512 polygon sides.',
      );
    }
    final width = _aspectRatio >= 1 ? 1.0 : _aspectRatio;
    final height = _aspectRatio >= 1 ? 1 / _aspectRatio : 1.0;
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );
    final path = switch (_kind) {
      _ShapeKind.circle => Path()..addOval(const Rect.fromLTWH(-.5, -.5, 1, 1)),
      _ShapeKind.ellipse => Path()..addOval(rect),
      _ShapeKind.rectangle => Path()..addRect(rect),
      _ShapeKind.roundedRectangle =>
        Path()..addRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(
              math.min(_cornerRadius, math.min(width, height) / 2),
            ),
          ),
        ),
      _ShapeKind.triangle => _polygon(3),
      _ShapeKind.star => _polygon(_points * 2, innerRadius: _innerRadius),
      _ShapeKind.heart =>
        Path()
          ..moveTo(0, -.25)
          ..cubicTo(-.55, -.75, -.8, 0, 0, .5)
          ..cubicTo(.8, 0, .55, -.75, 0, -.25)
          ..close(),
      _ShapeKind.diamond =>
        Path()
          ..moveTo(0, -.5)
          ..lineTo(.5, 0)
          ..lineTo(0, .5)
          ..lineTo(-.5, 0)
          ..close(),
      _ShapeKind.hexagon => _polygon(6),
      _ShapeKind.polygon => _polygon(_points),
      _ShapeKind.custom => _builder!(const Size(100, 100)),

      /// Creates a readable shape error and optional underlying cause.
      _ => throw const RevealShapeException(
        'Asset mask requires async resolution.',
      ),
    };
    return ResolvedShape(
      path,
      containsUnit: _kind == _ShapeKind.circle
          ? (point) => point.distanceSquared <= .25
          : null,
      isComplex:
          _kind == _ShapeKind.custom ||
          _kind == _ShapeKind.star ||
          _kind == _ShapeKind.heart,
    );
  }

  static Path _polygon(int vertices, {double? innerRadius}) {
    final path = Path();
    for (var i = 0; i < vertices; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / vertices;
      final radius = .5 * (innerRadius != null && i.isOdd ? innerRadius : 1);
      final point = Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }
}

/// Normalized vector geometry: longest bounds side 1, centered at (0, 0).
/// Paths are defensively copied so callers cannot corrupt the resolution cache.
@immutable
class ResolvedShape {
  /// Low-level normalized vector construction used by resolution.
  ///
  /// An optional frame preserves framing margins. containsUnit, if supplied,
  /// receives normalized coordinates. Application controls need RevealShape only.
  factory ResolvedShape(
    Path path, {
    bool Function(Offset)? containsUnit,
    bool isComplex = false,
    Rect? frame,
    List<String> warnings = const [],
  }) {
    try {
      final geometryBounds = path.getBounds();
      if (!_finite(geometryBounds)) {
        /// Creates a readable shape error and optional underlying cause.
        throw const RevealShapeException('Path has non-finite geometry.');
      }
      final bounds = frame ?? geometryBounds;
      if (!_finite(bounds) || bounds.width <= 0 || bounds.height <= 0) {
        /// Creates a readable shape error and optional underlying cause.
        throw const RevealShapeException(
          'Path must have finite, non-degenerate bounds and a filled area.',
        );
      }
      // Path.combine rejects non-finite native geometry, including invalid
      // commands mixed with valid contours, and removes zero-area contours.
      final filled = Path.combine(PathOperation.union, path, Path());
      final filledBounds = filled.getBounds();
      if (!_finite(filledBounds) ||
          filledBounds.isEmpty ||
          filled.computeMetrics().isEmpty) {
        /// Creates a readable shape error and optional underlying cause.
        throw const RevealShapeException(
          'Path has no non-degenerate filled area.',
        );
      }
      final longest = math.max(bounds.width, bounds.height);
      final normalized = path
          .shift(-bounds.center)
          .transform(
            Float64List.fromList([
              1 / longest,
              0,
              0,
              0,
              0,
              1 / longest,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              0,
              0,
              1,
            ]),
          );
      final normalizedBounds = frame == null
          ? normalized.getBounds()
          : Rect.fromCenter(
              center: Offset.zero,
              width: bounds.width / longest,
              height: bounds.height / longest,
            );
      if (!_finite(normalizedBounds) || normalizedBounds.isEmpty) {
        /// Creates a readable shape error and optional underlying cause.
        throw const RevealShapeException(
          'Path cannot be normalized to finite geometry.',
        );
      }
      return ResolvedShape._(
        normalized,
        normalizedBounds,
        containsUnit,
        isComplex || path.computeMetrics().length > 1,
        List.unmodifiable(warnings),
        null,
      );
    } on RevealShapeException {
      rethrow;
    } catch (error) {
      throw RevealShapeException(
        'Path must contain valid, finite filled geometry.',
        error,
      );
    }
  }

  const ResolvedShape._(
    this._path,
    this.bounds,
    this._containsUnit,
    this.isComplex,
    this.warnings,
    this._raster,
  );
  final Path _path;
  final bool Function(Offset)? _containsUnit;

  /// Normalized framing bounds; their longest side is one.
  final Rect bounds;

  /// Whether geometry needs the longer terminal safety fade.
  final bool isComplex;

  /// Immutable parser warnings for skipped SVG features.
  final List<String> warnings;
  final _RasterHandle? _raster;

  /// Whether this result owns an alpha-image handle instead of a vector-only mask.
  bool get isRaster => _raster != null;

  /// Whether its raster image handle has been released.
  bool get isDisposed => _raster?.disposed ?? false;

  /// Borrowed raster image, or null for vectors; do not dispose this handle directly.
  Image? get alphaImage => _raster?.image;

  /// Internal raster normalization for the decode pipeline.
  ///
  /// @nodoc
  @internal
  factory ResolvedShape.raster(RasterMaskData mask) {
    final longest = math.max(mask.width, mask.height);
    final bounds = Rect.fromCenter(
      center: Offset.zero,
      width: mask.width / longest,
      height: mask.height / longest,
    );
    bool contains(Offset point) {
      if (point.dx < bounds.left ||
          point.dx > bounds.right ||
          point.dy < bounds.top ||
          point.dy > bounds.bottom) {
        return false;
      }
      final x = ((point.dx - bounds.left) / bounds.width * mask.width)
          .floor()
          .clamp(0, mask.width - 1);
      final y = ((point.dy - bounds.top) / bounds.height * mask.height)
          .floor()
          .clamp(0, mask.height - 1);
      return mask.alpha[y * mask.width + x] >= mask.threshold;
    }

    return ResolvedShape._(
      Path()..addRect(bounds),
      bounds,
      contains,
      true,
      const [],
      _RasterHandle(mask.image),
    );
  }

  /// A raster retain owns an independent native image handle; dispose it after
  /// use. Vector geometry is immutable and retaining it needs no extra resource.
  ResolvedShape retain() {
    if (_raster == null) return this;
    if (isDisposed) {
      /// Creates a readable shape error and optional underlying cause.
      throw const RevealShapeException(
        'Raster mask has been evicted or disposed. Resolve it again.',
      );
    }
    return ResolvedShape._(
      _path,
      bounds,
      _containsUnit,
      isComplex,
      warnings,
      _RasterHandle(_raster.image.clone()),
    );
  }

  /// Releases an independently retained raster handle; vectors need no release.
  ///
  /// Do not dispose cache-owned results returned by resolve/resolveAsync.
  void dispose() => _raster?.dispose();

  /// Defensive copy of normalized vector geometry or a raster placement rectangle.
  Path get path => Path.from(_path);

  /// Tests a normalized point against vector fill or thresholded raster alpha.
  bool containsUnit(Offset point) =>
      _containsUnit?.call(point) ?? _path.contains(point);

  static bool _finite(Rect bounds) =>
      bounds.left.isFinite &&
      bounds.top.isFinite &&
      bounds.right.isFinite &&
      bounds.bottom.isFinite;
}

class _RasterHandle {
  _RasterHandle(this.image);
  final Image image;
  bool disposed = false;
  void dispose() {
    if (!disposed) {
      disposed = true;
      image.dispose();
    }
  }
}

class _ByteSource {
  _ByteSource(this.bytes) : _hash = Object.hashAll(bytes);
  final Uint8List bytes;
  final int _hash;
  @override
  int get hashCode => _hash;
  @override
  bool operator ==(Object other) =>
      other is _ByteSource &&
      _hash == other._hash &&
      listEquals(bytes, other.bytes);
}
