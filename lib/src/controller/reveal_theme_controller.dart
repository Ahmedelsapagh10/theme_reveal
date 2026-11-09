import 'package:flutter/material.dart';

import '../persistence/shared_prefs_theme_storage.dart';
import '../persistence/theme_storage.dart';

/// Receives storage failures without blocking or reverting the live theme.
typedef ThemePersistenceErrorCallback =
    void Function(Object error, StackTrace stackTrace);

/// Owns theme preference independently of the reveal animation engine.
class RevealThemeController extends ChangeNotifier with WidgetsBindingObserver {
  /// Synchronous initialization does not read storage. For restoration before
  /// runApp, await [create] after WidgetsFlutterBinding.ensureInitialized().
  RevealThemeController({
    ThemeMode defaultMode = ThemeMode.system,
    ThemeStorage? storage,
    this.onPersistenceError,
  }) : _mode = defaultMode,
       _defaultMode = defaultMode,
       _storage = storage ?? SharedPrefsThemeStorage() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Creates a controller and restores storage before returning.
  ///
  /// Initialize Flutter bindings before calling this with platform storage.
  /// Missing or invalid values use defaultMode; failures invoke onPersistenceError.
  static Future<RevealThemeController> create({
    ThemeMode defaultMode = ThemeMode.system,
    ThemeStorage? storage,
    ThemePersistenceErrorCallback? onPersistenceError,
  }) async {
    final controller = RevealThemeController(
      defaultMode: defaultMode,
      storage: storage,
      onPersistenceError: onPersistenceError,
    );
    await controller.reloadFromStorage();
    return controller;
  }

  final ThemeStorage _storage;
  final ThemeMode _defaultMode;

  /// Optional listener for read/write failures; callback errors are reported to Flutter.
  final ThemePersistenceErrorCallback? onPersistenceError;
  ThemeMode _mode;
  Object? _lastPersistenceError;
  Future<void> _writes = Future<void>.value();
  int _revision = 0;
  bool _disposed = false;

  /// The selected light, dark or system preference.
  ThemeMode get themeMode => _mode;

  /// Most recent storage failure, cleared after a successful read or write.
  Object? get lastPersistenceError => _lastPersistenceError;

  /// Effective brightness, observing platform brightness when in system mode.
  Brightness get effectiveBrightness => switch (_mode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
  };

  /// Whether the effective brightness is dark.
  bool get isDark => effectiveBrightness == Brightness.dark;

  /// Explicit light/dark mode opposite to the current effective brightness.
  ThemeMode get oppositeMode => isDark ? ThemeMode.light : ThemeMode.dark;

  /// Updates listeners immediately and queues a serialized storage write.
  void setThemeMode(ThemeMode mode) {
    if (_disposed || _mode == mode) return;
    _mode = mode;
    _revision++;
    // Enqueue before notifying: reentrant listeners preserve write ordering.
    _writes = _writes.then((_) async {
      try {
        await _storage.write(mode);
        _lastPersistenceError = null;
      } catch (error, stack) {
        _report(error, stack);
      }
    });
    notifyListeners();
  }

  /// Selects the opposite explicit light/dark mode and persists it.
  void toggleTheme() => setThemeMode(oppositeMode);

  /// Follows platform brightness and persists the system preference.
  void resetToSystem() => setThemeMode(ThemeMode.system);

  /// Drains writes, including those scheduled while a previous write completed.
  Future<void> flush() async {
    Future<void> pending;
    do {
      pending = _writes;
      await pending;
    } while (!identical(pending, _writes));
  }

  /// Drains writes, then reloads storage with missing/invalid fallback.
  ///
  /// Stale reads are ignored if another mode change or reload occurs. Storage
  /// errors are retained and reported instead of escaping to the caller.
  Future<void> reloadFromStorage() async {
    if (_disposed) return;
    final revision = ++_revision;
    await flush();
    try {
      final mode = await _storage.read() ?? _defaultMode;
      if (_disposed || revision != _revision) return;
      _lastPersistenceError = null;
      if (_mode != mode) {
        _mode = mode;
        notifyListeners();
      }
    } catch (error, stack) {
      if (!_disposed && revision == _revision) _report(error, stack);
    }
  }

  void _report(Object error, StackTrace stack) {
    _lastPersistenceError = error;
    if (_disposed) return;
    try {
      onPersistenceError?.call(error, stack);
    } catch (callbackError, callbackStack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: callbackError,
          stack: callbackStack,
          library: 'theme_reveal_kit',
          context: ErrorDescription('reporting a persistence error'),
        ),
      );
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (!_disposed && _mode == ThemeMode.system) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
