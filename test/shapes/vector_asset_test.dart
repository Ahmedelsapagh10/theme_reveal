import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

import '../support/mask_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(RevealShape.clearCache);

  test(
    'SVG nested transforms, all transform kinds, viewBox and rounded rect framing',
    () {
      final cases = <String, Offset>{
        'matrix(2 0 0 1 5 4)': const Offset(-.05, -.21),
        'translate(5 7) scale(2 3)': const Offset(-.05, .32),
        'rotate(90 50 50)': const Offset(.25, -.3),
        'skewX(45)': const Offset(-.05, -.25),
        'skewY(45)': const Offset(-.3, -.05),
      };
      for (final entry in cases.entries) {
        final shape = RevealShape.svgString(
          '<svg viewBox="0 0 100 100"><g transform="${entry.key}"><rect x="10" y="20" width="20" height="10"/></g></svg>',
        ).resolve();
        expect(shape.bounds, const Rect.fromLTWH(-.5, -.5, 1, 1));
        expect(shape.containsUnit(entry.value), isTrue, reason: entry.key);
      }
      final nested = const RevealShape.svgString(
        '<svg viewBox="10 20 100 100"><g transform="translate(20 30)"><g transform="scale(2)"><rect x="5" y="5" width="10" height="10"/></g></g></svg>',
      ).resolve();
      expect(nested.containsUnit(const Offset(-.2, -.2)), isTrue);
      expect(nested.containsUnit(const Offset(.2, .2)), isFalse);
      final round = const RevealShape.svgString(
        '<svg width="100px" height="100"><rect width="100" height="100" rx="20" ry="40"/></svg>',
      ).resolve();
      expect(round.containsUnit(const Offset(-.49, -.49)), isFalse);
      expect(round.containsUnit(Offset.zero), isTrue);
    },
  );

  test(
    'SVG even-odd attribute/style holes survive and independent shapes union',
    () {
      for (final rule in [
        'fill-rule="evenodd"',
        'style="fill-rule: evenodd; fill:black"',
      ]) {
        final shape = RevealShape.svgString(
          '<svg viewBox="0 0 100 100"><g $rule><path d="M0 0H100V100H0Z M30 30H70V70H30Z"/></g></svg>',
        ).resolve();
        expect(shape.containsUnit(Offset.zero), isFalse);
        expect(shape.containsUnit(const Offset(.4, 0)), isTrue);
      }
      final union = const RevealShape.svgString(
        '<svg viewBox="0 0 100 100"><path fill-rule="evenodd" d="M0 0H100V100H0Z M30 30H70V70H30Z"/><rect x="45" y="45" width="10" height="10"/></svg>',
      ).resolve();
      expect(union.containsUnit(Offset.zero), isTrue);
      expect(union.containsUnit(const Offset(.15, .15)), isFalse);
    },
  );

  test('SVG circle, ellipse, polygon, polyline, fill none and display none', () {
    for (final geometry in [
      '<circle cx="50" cy="50" r="30"/>',
      '<ellipse cx="50" cy="50" rx="30" ry="20"/>',
      '<polygon points="10,90 50,10 90,90"/>',
      '<polyline points="10 90 50 10 90 90"/>',
    ]) {
      final shape = RevealShape.svgString(
        '<svg viewBox="0 0 100 100">$geometry<g display="none"><rect width="100" height="100"/></g><rect width="100" height="100" fill="none"/></svg>',
      ).resolve();
      expect(shape.containsUnit(Offset.zero), isTrue);
      expect(shape.containsUnit(const Offset(-.49, -.49)), isFalse);
    }
  });

  test(
    'unsupported SVG features are skipped and reported, never loaded or executed',
    () {
      final shape = const RevealShape.svgString('''<svg viewBox="0 0 100 100">
      <defs><linearGradient id="g"><stop offset="0"/></linearGradient><clipPath id="c"><circle r="5"/></clipPath></defs>
      <script>throw new Error('must never execute')</script><use href="https://example.invalid/shape.svg"/>
      <text x="1" y="1">skip</text><mask id="m"/><filter id="f"/>
      <rect width="100" height="100" fill="url(#g)"/>
      <rect width="100" height="100" clip-path="url(#c)"/>
      <path d="M0 0H100" fill="none" stroke="black"/>
      <rect x="40" y="40" width="20" height="20"/>
    </svg>''').resolve();
      expect(shape.containsUnit(Offset.zero), isTrue);
      expect(shape.containsUnit(const Offset(.4, .4)), isFalse);
      final warnings = shape.warnings.join(' ');
      for (final name in [
        'linearGradient',
        'clipPath',
        'script',
        'use',
        'text',
        'mask',
        'filter',
        'gradient/resource',
        'clip-path',
        'stroke-only',
      ]) {
        expect(warnings, contains(name));
      }
      expect(() => shape.warnings.add('mutate'), throwsUnsupportedError);
    },
  );

  test(
    'invalid/empty SVG, external entity declarations and limits fail clearly',
    () {
      final invalid = [
        '',
        '<svg>',
        '<path d="M0 0H10V10Z"/>',
        '<svg/>',
        '<svg viewBox="0 0 0 10"><rect width="10" height="10"/></svg>',
        '<svg><path d="nonsense"/></svg>',
        '<svg><rect width="-1" height="5"/></svg>',
        '<svg><g transform="rotate(1 2)"><rect width="5" height="5"/></g></svg>',
        '<svg><g transform="translate(1) garbage"><rect width="5" height="5"/></g></svg>',
        '<svg><g transform="skewX(90)"><rect width="5" height="5"/></g></svg>',
        '<!DOCTYPE svg [<!ENTITY x SYSTEM "https://example.invalid">]><svg>&x;</svg>',
        '<svg>${'<rect width="1" height="1"/>' * 2000}</svg>',
        '<svg>${' ' * (1024 * 1024)}</svg>',
      ];
      for (final source in invalid) {
        expect(
          RevealShape.svgString(source).resolve,
          throwsA(isA<RevealShapeException>()),
        );
      }
    },
  );

  test(
    'JSON path schema supports holes, multiple paths, transforms and viewBox',
    () {
      final shape = RevealShape.jsonString(
        jsonEncode({
          'type': 'path',
          'viewBox': [0, 0, 100, 100],
          'paths': [
            {'d': 'M0 0H100V100H0Z M30 30H70V70H30Z', 'fillRule': 'evenOdd'},
            {'d': 'M0 0H10V10H0Z', 'transform': 'translate(45 45)'},
            {
              'd': 'M0 0H5V5H0Z',
              'transform': [1, 0, 0, 1, 80, 80],
            },
          ],
        }),
      ).resolve();
      expect(shape.containsUnit(Offset.zero), isTrue);
      expect(shape.containsUnit(const Offset(.15, .15)), isFalse);
      expect(shape.containsUnit(const Offset(.32, .32)), isTrue);
      expect(shape.bounds, const Rect.fromLTWH(-.5, -.5, 1, 1));
      expect(shape.warnings, isEmpty);
    },
  );

  test(
    'JSON predefined shape names and parameters resolve through vector factories',
    () {
      for (final name in [
        'circle',
        'ellipse',
        'rectangle',
        'roundedRectangle',
        'triangle',
        'star',
        'heart',
        'diamond',
        'hexagon',
        'polygon',
      ]) {
        final shape = RevealShape.jsonString(
          jsonEncode({
            'type': 'shape',
            'shape': name,
            'viewBox': [0, 0, 100, 100],
          }),
        ).resolve();
        expect(shape.containsUnit(Offset.zero), isTrue);
        expect(shape.bounds, const Rect.fromLTWH(-.5, -.5, 1, 1));
      }
      final ellipse = const RevealShape.jsonString(
        '{"type":"shape","shape":"ellipse","parameters":{"aspectRatio":2}}',
      ).resolve();
      expect(ellipse.bounds.width, 1);
      expect(ellipse.bounds.height, .5);
    },
  );

  test(
    'JSON validation rejects malformed schema, unsupported fields, empty paths and limits',
    () {
      final invalid = [
        '',
        '{',
        '[]',
        '{}',
        '{"type":"animation"}',
        '{"type":"path","paths":[]}',
        '{"type":"path","paths":[{"d":""}]}',
        '{"type":"path","paths":[{"d":"M0 0H5V5Z","fillRule":"wrong"}]}',
        '{"type":"path","paths":[{"d":"garbage"}]}',
        '{"type":"path","paths":[{"d":"M0 0H5V5Z","transform":[1,2]}]}',
        '{"type":"shape","shape":"star","parameters":{"points":2.5}}',
        '{"type":"shape","shape":"star","parameters":{"innerRadius":0}}',
        '{"type":"shape","shape":"circle","parameters":{"script":"x"}}',
        '{"type":"shape","shape":"unknown"}',
        '{"type":"shape","shape":"circle","viewBox":[0,0,-1,1]}',
        '{"type":"shape","shape":"circle","extra":true}',
        jsonEncode({
          'type': 'path',
          'paths': List.generate(2001, (_) => {'d': 'M0 0H5V5Z'}),
        }),
        '{${' ' * (1024 * 1024)}}',
      ];
      for (final source in invalid) {
        expect(
          RevealShape.jsonString(source).resolve,
          throwsA(isA<RevealShapeException>()),
        );
      }
      expect(
        () => const RevealShape.jsonString(
          '{"v":"5.7","fr":30,"ip":0,"op":100,"layers":[]}',
        ).resolve(),
        throwsA(
          isA<RevealShapeException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Lottie'), contains('PNG/SVG')),
          ),
        ),
      );
    },
  );

  test(
    'SVG/JSON assets share source cache and honor bundle/package paths',
    () async {
      final svg = Uint8List.fromList(
        utf8.encode(
          '<svg viewBox="0 0 10 10"><rect width="10" height="10"/></svg>',
        ),
      );
      final json = Uint8List.fromList(
        utf8.encode('{"type":"shape","shape":"star"}'),
      );
      final bundle = MaskBundle({
        'packages/brand/logo.svg': svg,
        'shape.json': json,
      });
      final first = await RevealShape.svgAsset(
        'logo.svg',
        package: 'brand',
        bundle: bundle,
      ).resolveAsync();
      expect(
        await RevealShape.svgAsset(
          'logo.svg',
          package: 'brand',
          bundle: bundle,
        ).resolveAsync(),
        same(first),
      );
      expect(
        (await RevealShape.jsonAsset(
          'shape.json',
          bundle: bundle,
        ).resolveAsync()).containsUnit(Offset.zero),
        isTrue,
      );
      expect(bundle.loads, ['packages/brand/logo.svg', 'shape.json']);
      await expectLater(
        RevealShape.svgAsset('absent', bundle: bundle).resolveAsync(),
        throwsA(isA<RevealShapeException>()),
      );
      final text = '<svg><rect width="10" height="10"/></svg>';
      expect(
        RevealShape.svgString(text).resolve(),
        same(RevealShape.svgString(text).resolve()),
      );
    },
  );
}
