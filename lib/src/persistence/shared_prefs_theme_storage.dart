import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_storage.dart';

/// Injectable platform boundary; tests need no preferences platform channel.
abstract interface class ThemePreferencesBackend {
  /// Reads a raw mode string, or null when absent.
  Future<String?> getString(String key);

  /// Reads an optional legacy bool preference.
  Future<bool?> getBool(String key);

  /// Writes a raw mode string.
  Future<void> setString(String key, String value);

  /// Removes a migrated legacy key after the new value is saved.
  Future<void> remove(String key);
}

class _AsyncPreferencesBackend implements ThemePreferencesBackend {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

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

/// Theme storage backed by SharedPreferencesAsync with optional legacy migration.
class SharedPrefsThemeStorage implements ThemeStorage {
  /// Uses key for mode strings and an optional injectable platform backend.
  SharedPrefsThemeStorage({
    this.key = 'theme_reveal_kit.mode',
    this.legacyBoolKey,
    ThemePreferencesBackend? backend,
  }) : _backend = backend ?? _AsyncPreferencesBackend();

  /// Preference key used for the encoded mode string.
  final String key;

  /// When the current key is absent, true migrates to dark, false to light.
  /// This key must be accessible by the supplied backend (including its prefix).
  final String? legacyBoolKey;
  final ThemePreferencesBackend _backend;

  @override
  Future<ThemeMode?> read() async {
    final value = await _backend.getString(key);
    if (value != null) return ThemeModeCodec.decode(value);
    final legacy = legacyBoolKey;
    if (legacy == null) return null;
    final oldValue = await _backend.getBool(legacy);
    if (oldValue == null) return null;
    final mode = oldValue ? ThemeMode.dark : ThemeMode.light;
    await write(mode);
    // Retain the old value if the new write fails, allowing a later retry.
    await _backend.remove(legacy);
    return mode;
  }

  @override
  Future<void> write(ThemeMode mode) =>
      _backend.setString(key, ThemeModeCodec.encode(mode));
}
