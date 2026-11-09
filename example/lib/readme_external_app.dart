// snippet:external_setup:file
// 1) Import Flutter and the reveal widgets.
import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

// 2) Pass your current state and update callback from your state builder.
class ExternalThemeApp extends StatelessWidget {
  const ExternalThemeApp({
    super.key,
    required this.mode,
    required this.changeTheme,
  });
  final ThemeMode mode;
  final VoidCallback changeTheme;
  @override
  Widget build(BuildContext context) => MaterialApp(
    // YOUR CODE: supply your themes and home screen.
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    themeMode: mode,
    // 3) Keep zero duration and the viewport builder.
    themeAnimationDuration: Duration.zero,
    builder: (context, child) => ThemeRevealViewport(child: child!),
    home: Scaffold(
      body: Builder(
        builder: (buttonContext) => FilledButton(
          // 4) Change existing state only inside this callback.
          onPressed: () => ThemeRevealViewport.of(
            buttonContext,
          ).reveal(from: buttonContext, onThemeChange: changeTheme),
          child: const Text('Change theme'),
        ),
      ),
    ),
  );
}

// end:external_setup
