import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

import 'app.dart';
import 'example_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = ExampleThemeStorage();
  final controller = await RevealThemeController.create(
    defaultMode: ThemeMode.dark,
    storage: storage,
  );
  runApp(RevealExampleApp(controller: controller, storage: storage));
}
