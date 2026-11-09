import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

final revealShapes = <String, RevealShape>{
  'Circle': const RevealShape.circle(),
  'Ellipse': const RevealShape.ellipse(),
  'Triangle': const RevealShape.triangle(),
  'Star': const RevealShape.star(),
  'Heart': const RevealShape.heart(),
  'Diamond': const RevealShape.diamond(),
  'Hexagon': const RevealShape.hexagon(),
  'Polygon': const RevealShape.polygon(sides: 7),
  'Rectangle': const RevealShape.rectangle(),
  'Rounded rectangle': const RevealShape.roundedRectangle(),
  'Icon': const RevealShape.icon(Icons.star),
  'SVG': const RevealShape.svgAsset('assets/logo.svg'),
  'PNG': const RevealShape.pngAsset('assets/logo.png'),
  'JSON': const RevealShape.jsonAsset('assets/custom_shape.json'),
  'Custom path': RevealShape.customPath(
    builder: (size) => Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Offset.zero & size)
      ..addOval(
        Rect.fromCenter(
          center: size.center(Offset.zero),
          width: size.width * .4,
          height: size.height * .4,
        ),
      ),
  ),
};

RevealCompletionStrategy _customStrategy(double start) =>
    RevealCompletionStrategy.custom((path, progress, viewport, origin) {
      final amount = ((progress - start) / (1 - start)).clamp(0.0, 1.0);
      final rectangle = Rect.lerp(
        Rect.fromCenter(center: origin, width: 0, height: 0),
        Offset.zero & viewport,
        amount,
      )!;
      return Path.combine(
        PathOperation.union,
        path,
        Path()..addRect(rectangle),
      );
    });

final revealStrategies = <String, RevealCompletionStrategy>{
  'Auto': RevealCompletionStrategy.auto,
  'Preserve shape': RevealCompletionStrategy.preserveShape,
  'Morph to fullscreen': RevealCompletionStrategy.morphToFullscreen,
  'Expand and dissolve': RevealCompletionStrategy.expandAndDissolve,
  'Custom': _customStrategy(.7),
};

const revealCurves = <String, Curve>{
  'Ease in/out cubic': Curves.easeInOutCubic,
  'Linear': Curves.linear,
  'Ease in': Curves.easeIn,
  'Ease out': Curves.easeOut,
  'Bounce out': Curves.bounceOut,
};

const revealAlignments = <String, Alignment>{
  'Center': Alignment.center,
  'Top left': Alignment.topLeft,
  'Top center': Alignment.topCenter,
  'Top right': Alignment.topRight,
  'Center left': Alignment.centerLeft,
  'Center right': Alignment.centerRight,
  'Bottom left': Alignment.bottomLeft,
  'Bottom center': Alignment.bottomCenter,
  'Bottom right': Alignment.bottomRight,
};

class RevealPreferences extends ChangeNotifier {
  String _shapeName = 'Circle';
  String _strategyName = 'Auto';
  String _originName = 'Button center';
  double _originX = .5;
  double _originY = .5;
  RevealAnimationConfig _config = const RevealAnimationConfig();
  final originKey = GlobalKey();

  String get shapeName => _shapeName;
  String get strategyName => _strategyName;
  String get originName => _originName;
  double get originX => _originX;
  double get originY => _originY;
  RevealShape get shape => revealShapes[_shapeName]!;
  RevealAnimationConfig get config => _config;

  static const originNames = [
    'Button center',
    'Gesture',
    'Screen center',
    'Top left',
    'Top right',
    'Bottom left',
    'Bottom right',
    'Top start',
    'Top end',
    'Bottom start',
    'Bottom end',
    'Normalized',
    'Offset',
    'Keyed marker',
  ];
  static const presets = [
    'Classic Circle',
    'Triangle Expansion',
    'Star Reveal',
    'Logo Reveal',
    'Soft Reveal',
    'Minimal Fast',
  ];

  void selectShape(String name) {
    if (!revealShapes.containsKey(name)) throw ArgumentError.value(name);
    _shapeName = name;
    notifyListeners();
  }

  void selectStrategy(String name) {
    if (!revealStrategies.containsKey(name)) throw ArgumentError.value(name);
    _strategyName = name;
    updateConfig(_config.copyWith(completionStrategy: revealStrategies[name]));
  }

  void updateConfig(RevealAnimationConfig value) {
    _config = _strategyName == 'Custom'
        ? value.copyWith(
            completionStrategy: _customStrategy(value.completionStart),
          )
        : value;
    notifyListeners();
  }

  void selectOrigin(String name, {double? x, double? y}) {
    if (!originNames.contains(name)) throw ArgumentError.value(name);
    _originName = name;
    _originX = x ?? _originX;
    _originY = y ?? _originY;
    if (name == 'Normalized') {
      _originX = _originX.clamp(0, 1);
      _originY = _originY.clamp(0, 1);
    }
    final origin = switch (name) {
      'Gesture' => const RevealOrigin.gesture(),
      'Screen center' => const RevealOrigin.screenCenter(),
      'Top left' => const RevealOrigin.topLeft(),
      'Top right' => const RevealOrigin.topRight(),
      'Bottom left' => const RevealOrigin.bottomLeft(),
      'Bottom right' => const RevealOrigin.bottomRight(),
      'Top start' => const RevealOrigin.topStart(),
      'Top end' => const RevealOrigin.topEnd(),
      'Bottom start' => const RevealOrigin.bottomStart(),
      'Bottom end' => const RevealOrigin.bottomEnd(),
      'Normalized' => RevealOrigin.normalized(
        _originX.clamp(0, 1),
        _originY.clamp(0, 1),
      ),
      'Offset' => RevealOrigin.offset(_originX, _originY),
      'Keyed marker' => RevealOrigin.fromKey(originKey),
      _ => const RevealOrigin.buttonCenter(),
    };
    updateConfig(_config.copyWith(origin: origin));
  }

  // copyWith retains nullable colors; construct explicitly to clear either one.
  void setColors({required Color? edge, required Color? glow}) {
    final c = _config;
    updateConfig(
      RevealAnimationConfig(
        enabled: c.enabled,
        duration: c.duration,
        curve: c.curve,
        delay: c.delay,
        completionDelay: c.completionDelay,
        origin: c.origin,
        initialSize: c.initialSize,
        startRotation: c.startRotation,
        endRotation: c.endRotation,
        alignment: c.alignment,
        maskFit: c.maskFit,
        completionStrategy: c.completionStrategy,
        morphToFullscreen: c.morphToFullscreen,
        completionStart: c.completionStart,
        edgeColor: edge,
        edgeWidth: c.edgeWidth,
        glowColor: glow,
        glowRadius: c.glowRadius,
        feather: c.feather,
        repeatPolicy: c.repeatPolicy,
        reducedMotion: c.reducedMotion,
      ),
    );
  }

  void reset() => applyPreset('Classic Circle');

  void applyPreset(String name) {
    if (!presets.contains(name)) throw ArgumentError.value(name);
    _shapeName = switch (name) {
      'Triangle Expansion' => 'Triangle',
      'Star Reveal' => 'Star',
      'Logo Reveal' => 'PNG',
      _ => 'Circle',
    };
    _strategyName = name == 'Triangle Expansion'
        ? 'Morph to fullscreen'
        : 'Auto';
    _originName = 'Button center';
    _originX = _originY = .5;
    _config = switch (name) {
      'Triangle Expansion' => const RevealAnimationConfig(
        duration: Duration(milliseconds: 950),
        completionStrategy: RevealCompletionStrategy.morphToFullscreen,
      ),
      'Star Reveal' => const RevealAnimationConfig(
        duration: Duration(milliseconds: 1000),
        startRotation: -math.pi / 4,
        endRotation: math.pi / 4,
      ),
      'Logo Reveal' => const RevealAnimationConfig(
        duration: Duration(milliseconds: 900),
      ),
      'Soft Reveal' => const RevealAnimationConfig(
        feather: 12,
        edgeColor: Colors.indigo,
        edgeWidth: 2,
        glowColor: Colors.indigo,
        glowRadius: 10,
      ),
      'Minimal Fast' => const RevealAnimationConfig(
        duration: Duration(milliseconds: 250),
        curve: Curves.linear,
      ),
      _ => const RevealAnimationConfig(),
    };
    notifyListeners();
  }
}
