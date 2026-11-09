// snippet:managed:file
// 1) Import Flutter and Theme Reveal Kit.
import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

Future<void> main() async {
  // 2) Restore the saved preference before showing the app.
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await RevealThemeController.create();
  // 3) Keep the controller for the app lifetime; dispose widget-owned controllers.
  runApp(
    RevealThemeBuilder(
      controller: controller,
      builder: (context, settings) => MaterialApp(
        // YOUR CODE: replace these themes and the home screen.
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        // 4) Keep all three settings below.
        themeMode: settings.themeMode,
        themeAnimationDuration: settings.themeAnimationDuration,
        builder: settings.builder,
        home: Scaffold(
          body: Center(child: RevealThemeButton(controller: controller)),
        ),
      ),
    ),
  );
}

// end:managed
