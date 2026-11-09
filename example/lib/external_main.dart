import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

import 'reveal_preferences.dart';
import 'shape_pickers.dart';

void main() => runApp(const ExternalThemeExampleApp());

class ExternalThemeExampleApp extends StatefulWidget {
  const ExternalThemeExampleApp({super.key, this.preferences});
  final RevealPreferences? preferences;
  @override
  State<ExternalThemeExampleApp> createState() =>
      _ExternalThemeExampleAppState();
}

class _ExternalThemeExampleAppState extends State<ExternalThemeExampleApp> {
  final _mode = ValueNotifier(ThemeMode.light);
  late final _preferences = widget.preferences ?? RevealPreferences();
  int _counter = 0;

  @override
  void dispose() {
    _mode.dispose();
    if (widget.preferences == null) _preferences.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: _mode,
    builder: (context, mode, _) => MaterialApp(
      title: 'External theme state',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
      ),
      themeMode: mode,
      themeAnimationDuration: Duration.zero,
      builder: (context, child) => ThemeRevealViewport(child: child!),
      home: Scaffold(
        appBar: AppBar(title: const Text('External theme state')),
        body: ListenableBuilder(
          listenable: _preferences,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'ValueNotifier owns the theme. The viewport captures the old frame and reveals this same live application.',
              ),
              const SizedBox(height: 24),
              ShapePickers(preferences: _preferences, prefix: 'external-'),
              const SizedBox(height: 24),
              Builder(
                builder: (buttonContext) => FilledButton.icon(
                  key: const ValueKey('external-theme-toggle'),
                  icon: const Icon(Icons.contrast),
                  label: Text('Current mode: ${mode.name}'),
                  onPressed: () => ThemeRevealViewport.of(buttonContext).reveal(
                    from: buttonContext,
                    shape: _preferences.shape,
                    config: _preferences.config,
                    onThemeChange: () {
                      // Emit before completing; the engine waits two more frames.
                      _mode.value = _mode.value == ThemeMode.light
                          ? ThemeMode.dark
                          : ThemeMode.light;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  title: Text('Retained counter: $_counter'),
                  trailing: IconButton(
                    key: const ValueKey('external-counter'),
                    tooltip: 'Increment counter',
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() => _counter++),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
