import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

import 'reveal_preferences.dart';
import 'shape_pickers.dart';

class PlaygroundTab extends StatelessWidget {
  const PlaygroundTab({
    super.key,
    required this.controller,
    required this.preferences,
  });
  final RevealThemeController controller;
  final RevealPreferences preferences;

  Widget _slider(
    String id,
    String label,
    double value,
    double max,
    ValueChanged<double> onChanged, {
    String unit = '',
    int? divisions,
  }) => SizedBox(
    width: 280,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(value.abs() < 1 ? 2 : 0)}$unit'),
        Slider(
          key: ValueKey(id),
          value: value.clamp(0, max),
          max: max,
          divisions: divisions,
          semanticFormatterCallback: (value) => '$label $value$unit',
          onChanged: onChanged,
        ),
      ],
    ),
  );

  Widget _rotation(
    String id,
    String label,
    double radians,
    ValueChanged<double> changed,
  ) => SizedBox(
    width: 280,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${(radians * 180 / math.pi).round()}°'),
        Slider(
          key: ValueKey(id),
          value: (radians * 180 / math.pi).clamp(-180, 180),
          min: -180,
          max: 180,
          divisions: 72,
          onChanged: (value) => changed(value * math.pi / 180),
        ),
      ],
    ),
  );

  Widget _section(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 16, runSpacing: 16, children: children),
        ],
      ),
    ),
  );

  static const _colors = <String, Color?>{
    'None': null,
    'Indigo': Colors.indigo,
    'Amber': Colors.amber,
    'White': Colors.white,
    'Pink': Colors.pink,
  };
  String _colorName(Color? color) => _colors.entries
      .firstWhere(
        (entry) => entry.value == color,
        orElse: () => _colors.entries.first,
      )
      .key;

  @override
  Widget build(BuildContext context) {
    final c = preferences.config;
    void update(RevealAnimationConfig value) => preferences.updateConfig(value);
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                RevealThemeButton(
                  key: const ValueKey('playground-theme-button'),
                  controller: controller,
                  revealShape: preferences.shape,
                  animation: c,
                ),
                Text(
                  '${preferences.shapeName} · ${c.duration.inMilliseconds} ms',
                  key: const ValueKey('config-summary'),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('center-reveal'),
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('Reveal from screen center'),
                  onPressed: () => ThemeRevealViewport.of(context).toggleTheme(
                    controller,
                    shape: preferences.shape,
                    config: c.copyWith(
                      origin: const RevealOrigin.screenCenter(),
                    ),
                  ),
                ),
                SizedBox(
                  key: preferences.originKey,
                  width: 24,
                  height: 24,
                  child: const Tooltip(
                    message: 'Keyed origin marker',
                    child: Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            key: const PageStorageKey('playground-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Playground',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Text(
                'Changes are shared with every theme control in this app.',
              ),
              _section('Presets', [
                for (final preset in RevealPreferences.presets)
                  ActionChip(
                    key: ValueKey('preset-$preset'),
                    label: Text(preset),
                    onPressed: () => preferences.applyPreset(preset),
                  ),
                OutlinedButton(
                  key: const ValueKey('reset-preferences'),
                  onPressed: preferences.reset,
                  child: const Text('Reset to Defaults'),
                ),
              ]),
              _section('Shape & completion', [
                ShapePickers(preferences: preferences, prefix: 'playground-'),
                _slider(
                  'completion-start',
                  'Completion start',
                  c.completionStart,
                  .95,
                  (v) => update(c.copyWith(completionStart: v)),
                  divisions: 19,
                ),
                SizedBox(
                  width: 280,
                  child: SwitchListTile(
                    key: const ValueKey('morph-shortcut'),
                    title: const Text('Morph shortcut'),
                    subtitle: const Text(
                      'Overrides the selected strategy when coverage permits',
                    ),
                    value: c.morphToFullscreen,
                    onChanged: (v) => update(c.copyWith(morphToFullscreen: v)),
                  ),
                ),
              ]),
              _section('Timing & motion', [
                SizedBox(
                  width: 280,
                  child: SwitchListTile(
                    key: const ValueKey('animation-enabled'),
                    title: const Text('Enable reveal'),
                    value: c.enabled,
                    onChanged: (v) => update(c.copyWith(enabled: v)),
                  ),
                ),
                _slider(
                  'duration',
                  'Duration',
                  c.duration.inMilliseconds.toDouble(),
                  2000,
                  (v) => update(
                    c.copyWith(duration: Duration(milliseconds: v.round())),
                  ),
                  unit: ' ms',
                  divisions: 40,
                ),
                ExampleDropdown<Curve>(
                  id: 'curve',
                  label: 'Curve',
                  value: c.curve,
                  options: revealCurves,
                  onChanged: (v) => update(c.copyWith(curve: v)),
                ),
                _slider(
                  'delay',
                  'Delay',
                  c.delay.inMilliseconds.toDouble(),
                  2000,
                  (v) => update(
                    c.copyWith(delay: Duration(milliseconds: v.round())),
                  ),
                  unit: ' ms',
                  divisions: 40,
                ),
                _slider(
                  'completion-delay',
                  'Completion delay',
                  c.completionDelay.inMilliseconds.toDouble(),
                  2000,
                  (v) => update(
                    c.copyWith(
                      completionDelay: Duration(milliseconds: v.round()),
                    ),
                  ),
                  unit: ' ms',
                  divisions: 40,
                ),
                ExampleDropdown<RevealRepeatPolicy>(
                  id: 'repeat-policy',
                  label: 'Repeat policy',
                  value: c.repeatPolicy,
                  options: {
                    for (final v in RevealRepeatPolicy.values) v.name: v,
                  },
                  onChanged: (v) => update(c.copyWith(repeatPolicy: v)),
                ),
                ExampleDropdown<RevealReducedMotion>(
                  id: 'reduced-motion',
                  label: 'Reduced motion',
                  value: c.reducedMotion,
                  options: {
                    for (final v in RevealReducedMotion.values) v.name: v,
                  },
                  onChanged: (v) => update(c.copyWith(reducedMotion: v)),
                ),
              ]),
              _section('Placement', [
                ExampleDropdown<String>(
                  id: 'origin',
                  label: 'Origin',
                  value: preferences.originName,
                  options: {
                    for (final v in RevealPreferences.originNames) v: v,
                  },
                  onChanged: preferences.selectOrigin,
                ),
                if ([
                  'Normalized',
                  'Offset',
                ].contains(preferences.originName)) ...[
                  _slider(
                    'origin-x',
                    'Origin X',
                    preferences.originX,
                    preferences.originName == 'Normalized' ? 1 : 1200,
                    (v) =>
                        preferences.selectOrigin(preferences.originName, x: v),
                  ),
                  _slider(
                    'origin-y',
                    'Origin Y',
                    preferences.originY,
                    preferences.originName == 'Normalized' ? 1 : 1200,
                    (v) =>
                        preferences.selectOrigin(preferences.originName, y: v),
                  ),
                ],
                _slider(
                  'initial-size',
                  'Initial size',
                  c.initialSize,
                  240,
                  (v) => update(c.copyWith(initialSize: v)),
                  unit: ' px',
                ),
                _rotation(
                  'start-rotation',
                  'Start rotation',
                  c.startRotation,
                  (v) => update(c.copyWith(startRotation: v)),
                ),
                _rotation(
                  'end-rotation',
                  'End rotation',
                  c.endRotation,
                  (v) => update(c.copyWith(endRotation: v)),
                ),
                ExampleDropdown<RevealMaskFit>(
                  id: 'mask-fit',
                  label: 'Mask fit',
                  value: c.maskFit,
                  options: {for (final v in RevealMaskFit.values) v.name: v},
                  onChanged: (v) => update(c.copyWith(maskFit: v)),
                ),
                ExampleDropdown<Alignment>(
                  id: 'alignment',
                  label: 'Alignment',
                  value: c.alignment,
                  options: revealAlignments,
                  onChanged: (v) => update(c.copyWith(alignment: v)),
                ),
              ]),
              _section('Vector edge effects', [
                const SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Edge, glow and feather apply to vector shapes. Icon/PNG raster masks ignore them.',
                  ),
                ),
                ExampleDropdown<String>(
                  id: 'edge-color',
                  label: 'Edge color',
                  value: _colorName(c.edgeColor),
                  options: {for (final v in _colors.keys) v: v},
                  onChanged: (v) => preferences.setColors(
                    edge: _colors[v],
                    glow: c.glowColor,
                  ),
                ),
                _slider(
                  'edge-width',
                  'Edge width',
                  c.edgeWidth,
                  12,
                  (v) => update(c.copyWith(edgeWidth: v)),
                  unit: ' px',
                ),
                ExampleDropdown<String>(
                  id: 'glow-color',
                  label: 'Glow color',
                  value: _colorName(c.glowColor),
                  options: {for (final v in _colors.keys) v: v},
                  onChanged: (v) => preferences.setColors(
                    edge: c.edgeColor,
                    glow: _colors[v],
                  ),
                ),
                _slider(
                  'glow-radius',
                  'Glow radius',
                  c.glowRadius,
                  30,
                  (v) => update(c.copyWith(glowRadius: v)),
                  unit: ' px',
                ),
                _slider(
                  'feather',
                  'Feather',
                  c.feather,
                  30,
                  (v) => update(c.copyWith(feather: v)),
                  unit: ' px',
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}
