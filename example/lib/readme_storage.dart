// snippet:storage:file
// 1) Connect your own asynchronous string storage through these callbacks.
import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

class AppThemeStorage implements ThemeStorage {
  AppThemeStorage({required this.load, required this.save});
  final Future<String?> Function() load;
  final Future<void> Function(String) save;
  @override
  Future<ThemeMode?> read() async => ThemeModeCodec.decode(await load());
  @override
  Future<void> write(ThemeMode mode) => save(ThemeModeCodec.encode(mode));
}

// end:storage
