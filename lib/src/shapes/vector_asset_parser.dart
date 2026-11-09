import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:path_drawing/path_drawing.dart';
import 'package:xml/xml.dart';

import '../rendering/reveal_geometry.dart';
import 'reveal_shape.dart';

/// Internal parsed geometry, optional framing and unsupported-feature warnings.
class VectorMaskData {
  /// Creates a filled vector parse result.
  const VectorMaskData(this.path, this.frame, this.warnings);

  /// Union of supported filled source geometry.
  final Path path;

  /// Optional SVG/JSON viewBox framing rectangle.
  final Rect? frame;

  /// Unsupported features skipped while parsing SVG geometry.
  final List<String> warnings;
}

/// Data-only SVG/JSON parsing. No script execution, CSS engine or URL loading.
abstract final class VectorAssetParser {
  /// Maximum UTF-8 vector input size (1 MiB).
  static const maxBytes = 1024 * 1024;

  /// Maximum SVG elements or JSON paths (2000).
  static const maxElements = 2000;
  static final _number = RegExp(
    r'[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?',
  );

  static void _size(String source) {
    if (source.length > maxBytes || utf8.encode(source).length > maxBytes) {
      throw const RevealShapeException('Vector input exceeds the 1 MiB limit.');
    }
  }

  /// Parses a finite numeric list with comma/whitespace separators.
  static List<double> numbers(String source) {
    if (source
        .replaceAll(_number, '')
        .replaceAll(RegExp(r'[\s,]'), '')
        .isNotEmpty) {
      throw RevealShapeException('Invalid numeric list: $source');
    }
    final result = _number
        .allMatches(source)
        .map((match) => double.parse(match[0]!))
        .toList();
    if (result.any((value) => !value.isFinite)) {
      throw const RevealShapeException('Numbers must be finite.');
    }
    return result;
  }

  static Affine _multiply(Affine l, Affine r) => Affine(
    l.a * r.a + l.c * r.b,
    l.b * r.a + l.d * r.b,
    l.a * r.c + l.c * r.d,
    l.b * r.c + l.d * r.d,
    l.a * r.tx + l.c * r.ty + l.tx,
    l.b * r.tx + l.d * r.ty + l.ty,
  );
  static const _identity = Affine(1, 0, 0, 1, 0, 0);

  /// Parses supported SVG transforms in SVG composition order.
  static Affine transform(String? source) {
    if (source == null || source.trim().isEmpty) return _identity;
    final pattern = RegExp(r'([a-zA-Z]+)\s*\(([^()]*)\)');
    var result = _identity;
    var end = 0;
    for (final match in pattern.allMatches(source)) {
      if (source
          .substring(end, match.start)
          .replaceAll(RegExp(r'[\s,]'), '')
          .isNotEmpty) {
        throw const RevealShapeException('Invalid SVG transform syntax.');
      }
      final values = numbers(match[2]!);
      final name = match[1]!;
      Affine next;
      if (name == 'matrix' && values.length == 6) {
        next = Affine(
          values[0],
          values[1],
          values[2],
          values[3],
          values[4],
          values[5],
        );
      } else if (name == 'translate' &&
          (values.length == 1 || values.length == 2)) {
        next = Affine(
          1,
          0,
          0,
          1,
          values[0],
          values.length == 2 ? values[1] : 0,
        );
      } else if (name == 'scale' &&
          (values.length == 1 || values.length == 2)) {
        next = Affine(
          values[0],
          0,
          0,
          values.length == 2 ? values[1] : values[0],
          0,
          0,
        );
      } else if (name == 'rotate' &&
          (values.length == 1 || values.length == 3)) {
        final angle = values[0] * math.pi / 180;
        next = Affine(
          math.cos(angle),
          math.sin(angle),
          -math.sin(angle),
          math.cos(angle),
          0,
          0,
        );
        if (values.length == 3) {
          next = _multiply(
            Affine(1, 0, 0, 1, values[1], values[2]),
            _multiply(next, Affine(1, 0, 0, 1, -values[1], -values[2])),
          );
        }
      } else if ((name == 'skewX' || name == 'skewY') && values.length == 1) {
        final tangent = math.tan(values[0] * math.pi / 180);
        if (math.cos(values[0] * math.pi / 180).abs() < 1e-12) {
          throw const RevealShapeException('Skew transform is singular.');
        }
        next = name == 'skewX'
            ? Affine(1, 0, tangent, 1, 0, 0)
            : Affine(1, tangent, 0, 1, 0, 0);
      } else {
        throw RevealShapeException(
          'Unsupported or malformed transform: $name.',
        );
      }
      result = _multiply(result, next);
      end = match.end;
    }
    if (end == 0 ||
        source.substring(end).replaceAll(RegExp(r'[\s,]'), '').isNotEmpty) {
      throw const RevealShapeException('Invalid SVG transform syntax.');
    }
    return result;
  }

  static Rect _frame(List<double> values) {
    if (values.length != 4 ||
        values.any((v) => !v.isFinite) ||
        values[2] <= 0 ||
        values[3] <= 0) {
      throw const RevealShapeException(
        'viewBox must contain [x, y, positiveWidth, positiveHeight].',
      );
    }
    return Rect.fromLTWH(values[0], values[1], values[2], values[3]);
  }

  /// Parses a bounded, resource-free SVG filled silhouette.
  static VectorMaskData svg(String source) {
    _size(source);
    if (RegExp(
      r'<!\s*(DOCTYPE|ENTITY)',
      caseSensitive: false,
    ).hasMatch(source)) {
      throw const RevealShapeException(
        'SVG document types and entity declarations are not supported.',
      );
    }
    try {
      final document = XmlDocument.parse(source);
      final root = document.rootElement;
      if (root.name.local != 'svg') {
        throw const RevealShapeException('SVG root must be <svg>.');
      }
      if (document.descendants.whereType<XmlElement>().length > maxElements) {
        throw const RevealShapeException('SVG exceeds the 2000 element limit.');
      }
      final warnings = <String>{};
      final box = root.getAttribute('viewBox');
      Rect? frame = box == null ? null : _frame(numbers(box));
      if (frame == null &&
          root.getAttribute('width') != null &&
          root.getAttribute('height') != null) {
        frame = _frame([
          0,
          0,
          _length(root.getAttribute('width')!),
          _length(root.getAttribute('height')!),
        ]);
      }
      Path combined = Path();
      void visit(
        XmlElement element,
        Affine parent,
        Map<String, String> inherited, {
        bool isRoot = false,
      }) {
        final tag = element.name.local;
        final style = Map<String, String>.from(inherited);
        for (final name in [
          'fill',
          'fill-rule',
          'stroke',
          'display',
          'clip-path',
          'mask',
          'filter',
          'opacity',
          'fill-opacity',
        ]) {
          final value = element.getAttribute(name);
          if (value != null) style[name] = value.trim();
        }
        for (final declaration in (element.getAttribute('style') ?? '').split(
          ';',
        )) {
          final colon = declaration.indexOf(':');
          if (colon > 0) {
            style[declaration.substring(0, colon).trim()] = declaration
                .substring(colon + 1)
                .trim();
          }
        }
        if (style['display'] == 'none' ||
            style['opacity'] == '0' ||
            style['fill-opacity'] == '0') {
          return;
        }
        for (final name in ['clip-path', 'mask', 'filter']) {
          if (style[name] != null && style[name] != 'none') {
            warnings.add('$name: affected geometry skipped');
            return;
          }
        }
        if ([
          'defs',
          'linearGradient',
          'radialGradient',
          'clipPath',
          'mask',
          'filter',
          'use',
          'text',
          'script',
          'style',
          'image',
          'foreignObject',
        ].contains(tag)) {
          warnings.add('$tag: unsupported feature skipped');
          // Definitions are never painted, but still report their unsupported children.
          if (tag == 'defs') {
            for (final child in element.descendants.whereType<XmlElement>()) {
              warnings.add('${child.name.local}: definition skipped');
            }
          }
          return;
        }
        if (tag == 'title' || tag == 'desc' || tag == 'metadata') return;
        final matrix = _multiply(
          parent,
          transform(element.getAttribute('transform')),
        );
        if (tag == 'g' || (isRoot && tag == 'svg')) {
          for (final child in element.childElements) {
            visit(child, matrix, style);
          }
          return;
        }
        if (style['fill'] == 'none') {
          if (style['stroke'] != null && style['stroke'] != 'none') {
            warnings.add('$tag: stroke-only geometry skipped');
          }
          return;
        }
        if ((style['fill'] ?? '').contains('url(')) {
          warnings.add('$tag: gradient/resource fill geometry skipped');
          return;
        }
        final path = _elementPath(element, warnings);
        if (path == null) return;
        final rule = style['fill-rule'] ?? 'nonzero';
        if (rule != 'nonzero' && rule != 'evenodd') {
          throw RevealShapeException('Unsupported SVG fill-rule: $rule.');
        }
        path.fillType = rule == 'evenodd'
            ? PathFillType.evenOdd
            : PathFillType.nonZero;
        combined = Path.combine(
          PathOperation.union,
          combined,
          path.transform(matrix.matrix),
        );
      }

      visit(root, _identity, const {}, isRoot: true);
      if (frame != null) {
        combined = Path.combine(
          PathOperation.intersect,
          combined,
          Path()..addRect(frame),
        );
      }
      return VectorMaskData(combined, frame, warnings.toList(growable: false));
    } on RevealShapeException {
      rethrow;
    } catch (error) {
      throw RevealShapeException('Invalid SVG geometry or XML.', error);
    }
  }

  static double _length(String value) {
    final text = value.trim().replaceFirst(RegExp(r'px$'), '');
    final result = double.tryParse(text);
    if (result == null || !result.isFinite) {
      throw RevealShapeException(
        'Unsupported SVG length: $value (use numbers or px).',
      );
    }
    return result;
  }

  static Path? _elementPath(XmlElement element, Set<String> warnings) {
    double value(String name, [double fallback = 0]) =>
        element.getAttribute(name) == null
        ? fallback
        : _length(element.getAttribute(name)!);
    final tag = element.name.local;
    switch (tag) {
      case 'path':
        final data = element.getAttribute('d');
        return data == null || data.trim().isEmpty
            ? null
            : parseSvgPathData(data);
      case 'rect':
        final width = value('width'), height = value('height');
        if (width < 0 || height < 0) {
          throw const RevealShapeException(
            'SVG rect dimensions must not be negative.',
          );
        }
        if (width == 0 || height == 0) return null;
        final rect = Rect.fromLTWH(value('x'), value('y'), width, height);
        final rx = value('rx', value('ry')), ry = value('ry', rx);
        if (rx < 0 || ry < 0) {
          throw const RevealShapeException(
            'SVG corner radii must not be negative.',
          );
        }
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.elliptical(
              math.min(rx, width / 2),
              math.min(ry, height / 2),
            ),
          ),
        );
      case 'circle':
      case 'ellipse':
        final rx = tag == 'circle' ? value('r') : value('rx');
        final ry = tag == 'circle' ? rx : value('ry');
        if (rx < 0 || ry < 0) {
          throw const RevealShapeException('SVG radii must not be negative.');
        }
        if (rx == 0 || ry == 0) return null;
        return Path()..addOval(
          Rect.fromCenter(
            center: Offset(value('cx'), value('cy')),
            width: rx * 2,
            height: ry * 2,
          ),
        );
      case 'polygon':
      case 'polyline':
        final points = numbers(element.getAttribute('points') ?? '');
        if (points.length.isOdd) {
          throw const RevealShapeException(
            'SVG polygon/polyline requires at least three coordinate pairs.',
          );
        }
        if (points.length < 6) {
          return null; // No filled area for fewer than 3 points.
        }
        final path = Path()..moveTo(points[0], points[1]);
        for (var i = 2; i < points.length; i += 2) {
          path.lineTo(points[i], points[i + 1]);
        }
        return path..close();
      default:
        warnings.add('$tag: unsupported element skipped');
        return null;
    }
  }

  /// Parses strict path/shape JSON and rejects Lottie documents explicitly.
  static VectorMaskData json(String source) {
    _size(source);
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        throw const RevealShapeException('Shape JSON must be an object.');
      }
      if (decoded.containsKey('layers') &&
          (decoded.containsKey('fr') ||
              decoded.containsKey('ip') ||
              decoded.containsKey('op') ||
              decoded.containsKey('v'))) {
        throw const RevealShapeException(
          'This is a Lottie file. Export a frame as PNG/SVG before using it as a reveal mask.',
        );
      }
      final type = decoded['type'];
      final frame = decoded['viewBox'] == null
          ? null
          : _frame(_jsonNumbers(decoded['viewBox'], 'viewBox', 4));
      Path path;
      if (type == 'path') {
        _keys(decoded, {'type', 'viewBox', 'paths'}, 'root');
        final paths = decoded['paths'];
        if (paths is! List || paths.isEmpty || paths.length > maxElements) {
          throw const RevealShapeException(
            'paths must contain 1–2000 path objects.',
          );
        }
        path = Path();
        for (var i = 0; i < paths.length; i++) {
          final item = paths[i];
          if (item is! Map<String, dynamic>) {
            throw RevealShapeException('paths[$i] must be an object.');
          }
          _keys(item, {'d', 'fillRule', 'transform'}, 'paths[$i]');
          if (item['d'] is! String || (item['d'] as String).trim().isEmpty) {
            throw RevealShapeException(
              'paths[$i].d must be a non-empty SVG path string.',
            );
          }
          final rule = item['fillRule'] ?? 'nonZero';
          if (rule != 'nonZero' && rule != 'evenOdd') {
            throw RevealShapeException(
              'paths[$i].fillRule must be nonZero or evenOdd.',
            );
          }
          final part = parseSvgPathData(item['d'] as String)
            ..fillType = rule == 'evenOdd'
                ? PathFillType.evenOdd
                : PathFillType.nonZero;
          final value = item['transform'];
          final Affine matrix;
          if (value == null || value is String) {
            matrix = transform(value as String?);
          } else {
            final numbers = _jsonNumbers(value, 'paths[$i].transform', 6);
            matrix = Affine(
              numbers[0],
              numbers[1],
              numbers[2],
              numbers[3],
              numbers[4],
              numbers[5],
            );
          }
          path = Path.combine(
            PathOperation.union,
            path,
            part.transform(matrix.matrix),
          );
        }
      } else if (type == 'shape') {
        _keys(decoded, {'type', 'viewBox', 'shape', 'parameters'}, 'root');
        final parameters = decoded['parameters'] ?? <String, dynamic>{};
        if (parameters is! Map<String, dynamic>) {
          throw const RevealShapeException('parameters must be an object.');
        }
        final shape = _predefined(decoded['shape'], parameters).resolve();
        path = shape.path;
        if (frame != null) {
          final scale = math.min(
            frame.width / shape.bounds.width,
            frame.height / shape.bounds.height,
          );
          path = path.transform(
            Affine(scale, 0, 0, scale, frame.center.dx, frame.center.dy).matrix,
          );
        }
      } else {
        throw const RevealShapeException(
          'Shape JSON type must be path or shape.',
        );
      }
      if (frame != null) {
        path = Path.combine(
          PathOperation.intersect,
          path,
          Path()..addRect(frame),
        );
      }
      return VectorMaskData(path, frame, const []);
    } on RevealShapeException {
      rethrow;
    } catch (error) {
      throw RevealShapeException('Invalid shape JSON or path data.', error);
    }
  }

  static void _keys(
    Map<String, dynamic> map,
    Set<String> allowed,
    String context,
  ) {
    final unknown = map.keys.where((key) => !allowed.contains(key));
    if (unknown.isNotEmpty) {
      throw RevealShapeException(
        'Unknown $context field(s): ${unknown.join(', ')}.',
      );
    }
  }

  static List<double> _jsonNumbers(Object? value, String context, int count) {
    if (value is! List ||
        value.length != count ||
        value.any((v) => v is! num || !v.isFinite)) {
      throw RevealShapeException(
        '$context must contain $count finite numbers.',
      );
    }
    return value.cast<num>().map((v) => v.toDouble()).toList();
  }

  static RevealShape _predefined(Object? name, Map<String, dynamic> p) {
    final allowed = switch (name) {
      'circle' || 'triangle' || 'heart' || 'diamond' || 'hexagon' => <String>{},
      'ellipse' || 'rectangle' => {'aspectRatio'},
      'roundedRectangle' => {'aspectRatio', 'cornerRadius'},
      'star' => {'points', 'innerRadius'},
      'polygon' => {'sides'},
      _ => throw RevealShapeException('Unknown predefined shape: $name.'),
    };
    _keys(p, allowed, 'parameters');
    double number(String key, double fallback) {
      final value = p[key] ?? fallback;
      if (value is! num || !value.isFinite) {
        throw RevealShapeException('parameters.$key must be finite.');
      }
      return value.toDouble();
    }

    int integer(String key, int fallback) {
      final value = p[key] ?? fallback;
      if (value is! int) {
        throw RevealShapeException('parameters.$key must be an integer.');
      }
      return value;
    }

    return switch (name) {
      'circle' => const RevealShape.circle(),
      'ellipse' => RevealShape.ellipse(aspectRatio: number('aspectRatio', 1.5)),
      'rectangle' => RevealShape.rectangle(
        aspectRatio: number('aspectRatio', 1.5),
      ),
      'roundedRectangle' => RevealShape.roundedRectangle(
        aspectRatio: number('aspectRatio', 1.5),
        cornerRadius: number('cornerRadius', .16),
      ),
      'triangle' => const RevealShape.triangle(),
      'star' => RevealShape.star(
        points: integer('points', 5),
        innerRadius: number('innerRadius', .45),
      ),
      'heart' => const RevealShape.heart(),
      'diamond' => const RevealShape.diamond(),
      'hexagon' => const RevealShape.hexagon(),
      'polygon' => RevealShape.polygon(sides: integer('sides', 6)),
      _ => throw RevealShapeException('Unknown predefined shape: $name.'),
    };
  }
}
