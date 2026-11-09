import 'package:flutter/material.dart';

/// Storage implementations return null for missing or invalid preferences.
abstract interface class ThemeStorage {
  /// Reads a preference, returning null for missing or invalid data.
  Future<ThemeMode?> read();

  /// Persists a valid preference; errors are handled by the controller.
  Future<void> write(ThemeMode mode);
}

/// The stable, case-sensitive disk representation of a theme preference.
abstract final class ThemeModeCodec {
  /// Encodes the exact strings light, dark and system.
  static String encode(ThemeMode mode) => mode.name;

  /// Decodes those case-sensitive strings, returning null for anything else.
  static ThemeMode? decode(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => null,
  };
}

/// In-memory storage for tests, temporary sessions and custom-storage examples.
class MemoryThemeStorage implements ThemeStorage {
  /// Creates storage with an optional initial preference.
  MemoryThemeStorage([this.value]);

  /// Current stored preference; null represents an absent value.
  ThemeMode? value;

  @override
  Future<ThemeMode?> read() async => value;

  @override
  Future<void> write(ThemeMode mode) async => value = mode;
}
