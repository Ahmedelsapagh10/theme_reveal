import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

class RecordingStorage implements ThemeStorage {
  ThemeMode? value;
  Object? readError;
  Object? writeError;
  Completer<void>? gate;
  final writes = <ThemeMode>[];
  int active = 0;
  int maxActive = 0;

  @override
  Future<ThemeMode?> read() async {
    if (readError != null) throw readError!;
    return value;
  }

  @override
  Future<void> write(ThemeMode mode) async {
    active++;
    if (active > maxActive) maxActive = active;
    try {
      await gate?.future;
      if (writeError != null) throw writeError!;
      writes.add(mode);
      value = mode;
    } finally {
      active--;
    }
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('create restores before returning; first launch uses default', () async {
    final storage = MemoryThemeStorage();
    final first = await RevealThemeController.create(
      defaultMode: ThemeMode.dark,
      storage: storage,
    );
    expect(first.themeMode, ThemeMode.dark);
    first.dispose();
    storage.value = ThemeMode.light;
    final restored = await RevealThemeController.create(storage: storage);
    expect(restored.themeMode, ThemeMode.light);
    restored.dispose();
  });

  test('sync constructor never reads and notifies once per change', () async {
    final storage = RecordingStorage()..value = ThemeMode.dark;
    final controller = RevealThemeController(storage: storage);
    var notifications = 0;
    controller.addListener(() => notifications++);
    expect(controller.themeMode, ThemeMode.system);
    controller.setThemeMode(ThemeMode.light);
    controller.setThemeMode(ThemeMode.light);
    expect(notifications, 1);
    expect(controller.effectiveBrightness, Brightness.light);
    expect(controller.oppositeMode, ThemeMode.dark);
    controller.toggleTheme();
    expect(controller.isDark, isTrue);
    controller.resetToSystem();
    expect(notifications, 3);
    await controller.flush();
    expect(storage.value, ThemeMode.system);
    controller.dispose();
  });

  test('rapid writes serialize while UI changes immediately', () async {
    final storage = RecordingStorage()..gate = Completer<void>();
    final controller = RevealThemeController(storage: storage);
    controller.setThemeMode(ThemeMode.dark);
    controller.setThemeMode(ThemeMode.light);
    controller.resetToSystem();
    expect(controller.themeMode, ThemeMode.system);
    await Future<void>.delayed(Duration.zero);
    expect(storage.active, 1);
    storage.gate!.complete();
    await controller.flush();
    expect(storage.maxActive, 1);
    expect(storage.writes, [ThemeMode.dark, ThemeMode.light, ThemeMode.system]);
    controller.dispose();
  });

  test('reentrant listeners preserve the same write order', () async {
    final storage = RecordingStorage();
    final controller = RevealThemeController(storage: storage);
    controller.addListener(() {
      if (controller.themeMode == ThemeMode.dark) {
        controller.setThemeMode(ThemeMode.light);
      }
    });
    controller.setThemeMode(ThemeMode.dark);
    await controller.flush();
    expect(storage.writes, [ThemeMode.dark, ThemeMode.light]);
    controller.dispose();
  });

  test(
    'failed reads preserve default and report; failed writes recover',
    () async {
      final storage = RecordingStorage()..readError = StateError('read');
      final errors = <Object>[];
      final controller = await RevealThemeController.create(
        storage: storage,
        defaultMode: ThemeMode.dark,
        onPersistenceError: (error, _) => errors.add(error),
      );
      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.lastPersistenceError, storage.readError);
      storage.writeError = StateError('write');
      controller.setThemeMode(ThemeMode.light);
      await controller.flush();
      expect(controller.themeMode, ThemeMode.light);
      expect(errors.length, 2);
      storage.writeError = null;
      controller.setThemeMode(ThemeMode.dark);
      await controller.flush();
      expect(controller.lastPersistenceError, isNull);
      controller.dispose();
    },
  );

  test('system brightness notifies only in system mode', () {
    final controller = RevealThemeController(storage: MemoryThemeStorage());
    var notifications = 0;
    controller.addListener(() => notifications++);
    binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    expect(controller.isDark, isTrue);
    expect(notifications, 1);
    controller.setThemeMode(ThemeMode.light);
    binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    expect(notifications, 2);
    controller.dispose();
    binding.platformDispatcher.clearPlatformBrightnessTestValue();
  });

  test('reload waits for pending writes and ignores stale reads', () async {
    final storage = RecordingStorage()..gate = Completer<void>();
    final controller = RevealThemeController(storage: storage);
    controller.setThemeMode(ThemeMode.dark);
    final reload = controller.reloadFromStorage();
    controller.setThemeMode(ThemeMode.light);
    storage.gate!.complete();
    await reload;
    expect(controller.themeMode, ThemeMode.light);
    await controller.flush();
    controller.dispose();
  });

  test(
    'dispose unregisters, drains existing writes, suppresses callbacks',
    () async {
      final storage = RecordingStorage()..gate = Completer<void>();
      var errors = 0;
      final controller = RevealThemeController(
        storage: storage,
        onPersistenceError: (_, _) => errors++,
      );
      controller.setThemeMode(ThemeMode.dark);
      controller.dispose();
      controller.dispose();
      controller.toggleTheme();
      storage.writeError = StateError('disposed');
      storage.gate!.complete();
      await controller.flush();
      expect(errors, 0);
      expect(controller.themeMode, ThemeMode.dark);
    },
  );
}
