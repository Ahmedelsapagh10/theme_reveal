import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

class FakeBackend implements ThemePreferencesBackend {
  final values = <String, Object>{};
  bool failWrites = false;

  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) throw StateError('disk unavailable');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('codec round trips exactly; invalid values safely return null', () {
    for (final mode in ThemeMode.values) {
      expect(ThemeModeCodec.decode(ThemeModeCodec.encode(mode)), mode);
    }
    for (final value in [null, '', 'DARK', 'true', 'unknown']) {
      expect(ThemeModeCodec.decode(value), isNull);
    }
  });

  test('custom key, all modes, absent and invalid values', () async {
    final backend = FakeBackend();
    final storage = SharedPrefsThemeStorage(key: 'custom', backend: backend);
    expect(await storage.read(), isNull);
    for (final mode in ThemeMode.values) {
      await storage.write(mode);
      expect(await storage.read(), mode);
      expect(backend.values['custom'], mode.name);
    }
    backend.values['custom'] = 'invalid';
    final controller = await RevealThemeController.create(storage: storage);
    expect(controller.themeMode, ThemeMode.system);
    controller.dispose();
  });

  test(
    'legacy true/false migrate once; existing value takes precedence',
    () async {
      for (final old in [true, false]) {
        final backend = FakeBackend()..values['old'] = old;
        final storage = SharedPrefsThemeStorage(
          key: 'new',
          legacyBoolKey: 'old',
          backend: backend,
        );
        expect(await storage.read(), old ? ThemeMode.dark : ThemeMode.light);
        expect(backend.values.containsKey('old'), isFalse);
        backend.values['old'] = !old;
        expect(await storage.read(), old ? ThemeMode.dark : ThemeMode.light);
      }
    },
  );

  test('failed migration retains legacy preference for retry', () async {
    final backend = FakeBackend()
      ..values['old'] = true
      ..failWrites = true;
    final storage = SharedPrefsThemeStorage(
      key: 'new',
      legacyBoolKey: 'old',
      backend: backend,
    );
    await expectLater(storage.read(), throwsStateError);
    expect(backend.values['old'], true);
    backend.failWrites = false;
    expect(await storage.read(), ThemeMode.dark);
  });
}
