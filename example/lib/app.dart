import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

import 'example_storage.dart';
import 'integrations_tab.dart';
import 'persistence_demo.dart';
import 'playground_tab.dart';
import 'reveal_preferences.dart';
import 'shape_pickers.dart';

class RevealExampleApp extends StatelessWidget {
  const RevealExampleApp({
    super.key,
    required this.controller,
    this.preferences,
    this.storage,
  });
  final RevealThemeController controller;
  final RevealPreferences? preferences;
  final ExampleThemeStorage? storage;

  @override
  Widget build(BuildContext context) => RevealThemeBuilder(
    controller: controller,
    onError: (error, stack) => debugPrint('Reveal fallback: $error'),
    builder: (context, settings) => MaterialApp(
      title: 'Theme Reveal Kit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xff5366d8),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xff5366d8),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: settings.themeMode,
      themeAnimationDuration: settings.themeAnimationDuration,
      builder: settings.builder,
      home: _ExampleHome(
        controller: controller,
        preferences: preferences,
        storage: storage,
      ),
    ),
  );
}

class _ExampleHome extends StatefulWidget {
  const _ExampleHome({
    required this.controller,
    this.preferences,
    this.storage,
  });
  final RevealThemeController controller;
  final RevealPreferences? preferences;
  final ExampleThemeStorage? storage;
  @override
  State<_ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<_ExampleHome> {
  int _tab = 0;
  double _progress = .65;
  bool _notifications = true;
  late final _preferences = widget.preferences ?? RevealPreferences();

  @override
  void dispose() {
    if (widget.preferences == null) _preferences.dispose();
    super.dispose();
  }

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
    NavigationDestination(icon: Icon(Icons.tune), label: 'Playground'),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      label: 'Settings',
    ),
    NavigationDestination(
      icon: Icon(Icons.extension_outlined),
      label: 'Integrations',
    ),
  ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _preferences,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        final tabs = IndexedStack(
          index: _tab,
          children: [
            ListView(
              key: const PageStorageKey('home-scroll'),
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Make a little change.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Open Settings for the compact theme button, or try every mask and motion control in Playground.',
                ),
                const SizedBox(height: 24),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.auto_awesome_outlined),
                    title: Text('One live application'),
                    subtitle: Text(
                      'Navigation, focus, and scroll state stay in place.',
                    ),
                  ),
                ),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.save_outlined),
                    title: Text('Remember your preference'),
                    subtitle: Text('Light, dark, or follow the system.'),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Your workspace',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Slider(
                  value: _progress,
                  label: '${(_progress * 100).round()}%',
                  onChanged: (value) => setState(() => _progress = value),
                ),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const Chip(
                      avatar: Icon(Icons.bolt),
                      label: Text('Live theme'),
                    ),
                    const Chip(
                      avatar: Icon(Icons.shield_outlined),
                      label: Text('State preserved'),
                    ),
                    FilledButton.tonal(
                      onPressed: () => setState(() => _progress = 1),
                      child: const Text('Mark all complete'),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Notifications'),
                  value: _notifications,
                  onChanged: (value) => setState(() => _notifications = value),
                ),
                for (var i = 1; i <= 8; i++)
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text('Activity $i'),
                    subtitle: const Text('Ready for a fresh perspective'),
                  ),
              ],
            ),
            PlaygroundTab(
              controller: widget.controller,
              preferences: _preferences,
            ),
            ListView(
              key: const PageStorageKey('settings-scroll'),
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(child: Text('Appearance')),
                            RevealThemeButton(
                              key: const ValueKey('settings-theme-button'),
                              controller: widget.controller,
                              revealShape: _preferences.shape,
                              animation: _preferences.config,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ListenableBuilder(
                          listenable: widget.controller,
                          builder: (context, _) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current mode: ${widget.controller.themeMode.name}',
                                key: const ValueKey('current-mode'),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final mode in ThemeMode.values)
                                    Builder(
                                      builder: (chipContext) => ChoiceChip(
                                        label: Text(mode.name),
                                        selected:
                                            widget.controller.themeMode == mode,
                                        onSelected: (_) =>
                                            ThemeRevealViewport.of(
                                              chipContext,
                                            ).setThemeMode(
                                              widget.controller,
                                              mode,
                                              from: chipContext,
                                              shape: _preferences.shape,
                                              config: _preferences.config,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                              if (widget.controller.lastPersistenceError !=
                                  null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Saving failed. Your theme still changed.',
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Your choice is saved automatically. Close and reopen the app to check restoration. System mode follows your device’s appearance.',
                        ),
                        const SizedBox(height: 20),
                        ShapePickers(preferences: _preferences),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          key: const ValueKey('open-playground'),
                          onPressed: () => setState(() => _tab = 1),
                          icon: const Icon(Icons.tune),
                          label: const Text('Open Playground'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.storage != null)
                  PersistenceDemo(
                    controller: widget.controller,
                    storage: widget.storage!,
                    preferences: _preferences,
                  ),
              ],
            ),
            IntegrationsTab(
              controller: widget.controller,
              preferences: _preferences,
              onOpenSettings: () => setState(() => _tab = 2),
            ),
          ],
        );
        return Scaffold(
          appBar: AppBar(title: const Text('Theme Reveal Kit')),
          body: Row(
            children: [
              if (wide) ...[
                NavigationRail(
                  selectedIndex: _tab,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (index) =>
                      setState(() => _tab = index),
                  destinations: [
                    for (final destination in _destinations)
                      NavigationRailDestination(
                        icon: destination.icon,
                        label: Text(destination.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(child: tabs),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _tab,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  onDestinationSelected: (index) =>
                      setState(() => _tab = index),
                  destinations: _destinations,
                ),
        );
      },
    ),
  );
}
