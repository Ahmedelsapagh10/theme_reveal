import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

import 'reveal_preferences.dart';

class IntegrationsTab extends StatelessWidget {
  const IntegrationsTab({
    super.key,
    required this.controller,
    required this.preferences,
    required this.onOpenSettings,
  });
  final RevealThemeController controller;
  final RevealPreferences preferences;
  final VoidCallback onOpenSettings;

  Widget _card(
    BuildContext context,
    String title,
    String explanation,
    Widget child,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(explanation),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('integrations-scroll'),
    padding: const EdgeInsets.all(24),
    children: [
      Text('Integrations', style: Theme.of(context).textTheme.headlineMedium),
      _card(
        context,
        'Managed mode',
        'This app uses RevealThemeBuilder around MaterialApp. The controller restores the theme before the first frame; the viewport is installed in MaterialApp.builder.',
        RevealThemeButton(
          key: const ValueKey('managed-theme-button'),
          controller: controller,
          revealShape: preferences.shape,
          animation: preferences.config,
          logo: const FlutterLogo(),
          logoAnimation: RevealLogoAnimation.rotate,
          tooltip:
              'Toggle with a decorative logo (the mask is selected separately)',
        ),
      ),
      _card(
        context,
        'Custom storage',
        'ExampleThemeStorage implements ThemeStorage and delegates mode encoding to SharedPrefsThemeStorage. Its injectable backend also lets the persistence lab inspect and corrupt the same raw preference.',
        OutlinedButton(
          onPressed: onOpenSettings,
          child: const Text('Inspect storage in Settings'),
        ),
      ),
      _card(
        context,
        'Your own button',
        'RevealThemeTrigger gives any child a theme-dependent label, a 48px target, pointer origin and Enter/Space activation.',
        RevealThemeTrigger(
          key: const ValueKey('custom-theme-trigger'),
          controller: controller,
          revealShape: preferences.shape,
          animation: preferences.config,
          child: Chip(
            avatar: const Icon(Icons.palette_outlined),
            label: Text('Custom control · ${preferences.shapeName}'),
          ),
        ),
      ),
      _card(
        context,
        'Asset & Path masks',
        'Select a silhouette below. All theme controls share this selection. The SVG, PNG and custom Path have holes and finish with dissolve; the decorative Flutter logo above is not the mask.',
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final shape in ['SVG', 'PNG', 'Custom path'])
              ChoiceChip(
                key: ValueKey('integration-$shape'),
                label: Text(shape),
                selected: preferences.shapeName == shape,
                onSelected: (_) => preferences.selectShape(shape),
              ),
          ],
        ),
      ),
      _card(
        context,
        'Programmatic theme change',
        'The viewport setThemeMode helper applies the selected shape and config to the live app.',
        Builder(
          builder: (buttonContext) => FilledButton.tonal(
            key: const ValueKey('integration-programmatic'),
            onPressed: () => ThemeRevealViewport.of(buttonContext).setThemeMode(
              controller,
              controller.oppositeMode,
              from: buttonContext,
              shape: preferences.shape,
              config: preferences.config,
            ),
            child: const Text('Set the opposite theme'),
          ),
        ),
      ),
      _card(
        context,
        'External state',
        'A separate runnable entry uses a ValueNotifier<ThemeMode> and viewport.reveal. Its callback emits the new state before completing; no RevealThemeController is required.',
        const SelectableText(
          'flutter run -t lib/external_main.dart',
          key: ValueKey('external-entry-command'),
        ),
      ),
    ],
  );
}
