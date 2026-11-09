import 'package:shared_preferences/shared_preferences.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';
import 'package:flutter/material.dart' show ThemeMode;

/// The real app and the raw-value demo share this storage and key.
class ExampleThemeStorage implements ThemeStorage {
  ExampleThemeStorage({
    this.key = 'theme_reveal_kit.mode',
    ThemePreferencesBackend? backend,
  }) : backend = backend ?? _PreferencesBackend();
  final String key;
  final ThemePreferencesBackend backend;
  late final _storage = SharedPrefsThemeStorage(key: key, backend: backend);

  Future<String?> readRaw() => backend.getString(key);
  Future<void> writeInvalid() => backend.setString(key, 'invalid-theme-mode');
  @override
  Future<ThemeMode?> read() => _storage.read();
  @override
  Future<void> write(ThemeMode mode) => _storage.write(mode);
}

class _PreferencesBackend implements ThemePreferencesBackend {
  final _preferences = SharedPreferencesAsync();
  @override
  Future<String?> getString(String key) => _preferences.getString(key);
  @override
  Future<bool?> getBool(String key) => _preferences.getBool(key);
  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);
  @override
  Future<void> remove(String key) => _preferences.remove(key);
}
