import 'package:flutter/material.dart';

import 'reveal_preferences.dart';

class ExampleDropdown<T> extends StatelessWidget {
  const ExampleDropdown({
    super.key,
    required this.id,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String id;
  final String label;
  final T value;
  final Map<String, T> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    child: DropdownButtonFormField<T>(
      key: ValueKey(id),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final entry in options.entries)
          DropdownMenuItem(value: entry.value, child: Text(entry.key)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    ),
  );
}

class ShapePickers extends StatelessWidget {
  const ShapePickers({super.key, required this.preferences, this.prefix = ''});
  final RevealPreferences preferences;
  final String prefix;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          ExampleDropdown<String>(
            id: '${prefix}shape-picker',
            label: 'Reveal shape',
            value: preferences.shapeName,
            options: {for (final name in revealShapes.keys) name: name},
            onChanged: preferences.selectShape,
          ),
          ExampleDropdown<String>(
            id: '${prefix}strategy-picker',
            label: 'Completion strategy',
            value: preferences.strategyName,
            options: {for (final name in revealStrategies.keys) name: name},
            onChanged: preferences.selectStrategy,
          ),
        ],
      ),
      if (['Custom path', 'SVG', 'PNG'].contains(preferences.shapeName))
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'This mask has a hole. The engine uses dissolve to finish every strategy safely.',
          ),
        ),
    ],
  );
}
