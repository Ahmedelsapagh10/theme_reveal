// Run: flutter run
// See README.md: Managed (complete main.dart).
import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

import 'app.dart';
import 'example_storage.dart';

Future<void> main() async {
  // 1) Initialize Flutter before reading the saved preference.
  WidgetsFlutterBinding.ensureInitialized();
  // 2) YOUR CODE: use the default storage or your own ThemeStorage adapter.
  final storage = ExampleThemeStorage();
  // 3) Restore before runApp; choose your fallback mode here.
  final controller = await RevealThemeController.create(
    defaultMode: ThemeMode.dark,
    storage: storage,
  );
  // 4) YOUR CODE: replace this screen with your app. Keep the three managed
  // MaterialApp settings shown in the README. The app owns this controller.
  runApp(RevealExampleApp(controller: controller, storage: storage));
}
