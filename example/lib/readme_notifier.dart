// snippet:notifier:file
// 1) Import the widgets and start the app.
import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

void main() => runApp(const NotifierThemeApp());

class NotifierThemeApp extends StatefulWidget {
  const NotifierThemeApp({super.key});
  @override
  State<NotifierThemeApp> createState() => _NotifierThemeAppState();
}

class _NotifierThemeAppState extends State<NotifierThemeApp> {
  // 2) This notifier owns the preference; add your persistence here if needed.
  final mode = ValueNotifier(ThemeMode.system);
  @override
  void dispose() {
    mode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: mode,
    builder: (context, value, _) => MaterialApp(
      // YOUR CODE: replace the themes and screen content.
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: value,
      // 3) Keep the viewport and disable competing theme interpolation.
      themeAnimationDuration: Duration.zero,
      builder: (context, child) => ThemeRevealViewport(child: child!),
      home: Scaffold(
        body: Builder(
          builder: (buttonContext) => FilledButton(
            // 4) Update the notifier only inside onThemeChange.
            onPressed: () => ThemeRevealViewport.of(buttonContext).reveal(
              from: buttonContext,
              onThemeChange: () => mode.value = value == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark,
            ),
            child: const Text('Change theme'),
          ),
        ),
      ),
    ),
  );
}

// end:notifier
