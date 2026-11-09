// snippet:settings:file
// 1) Use the controller restored in your managed main.dart.
import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final RevealThemeController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    // YOUR CODE: replace the title and add your other settings.
    appBar: AppBar(title: const Text('Settings')),
    body: ListTile(
      title: const Text('Appearance'),
      // 2) Keep this page below the managed MaterialApp.
      trailing: RevealThemeButton(controller: controller),
    ),
  );
}

// end:settings
