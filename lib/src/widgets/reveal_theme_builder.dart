import 'package:flutter/material.dart';

import '../animation/theme_reveal_viewport.dart';
import '../controller/reveal_theme_controller.dart';
import '../utils/reveal_exception.dart';

/// Managed MaterialApp settings; pass all three members to MaterialApp.
@immutable
class RevealThemeSettings {
  const RevealThemeSettings._(this.themeMode, this.builder);

  /// Controller-selected MaterialApp theme mode.
  final ThemeMode themeMode;

  /// Always zero so the real new theme is ready beneath the snapshot.
  Duration get themeAnimationDuration => Duration.zero;

  /// Installs the permanent reveal viewport above Navigator.
  final TransitionBuilder builder;
}

/// Keeps the viewport wrapper identity stable across normal theme rebuilds.
class RevealThemeBuilder extends StatefulWidget {
  /// Rebuilds app settings from controller changes while preserving viewport identity.
  const RevealThemeBuilder({
    super.key,
    required this.controller,
    required this.builder,
    this.onError,
  });

  /// Controller supplying the theme preference.
  final RevealThemeController controller;

  /// Builds MaterialApp using the supplied themeMode, zero duration and builder.
  final Widget Function(BuildContext context, RevealThemeSettings settings)
  builder;

  /// Receives engine errors and fallback notifications.
  final RevealErrorCallback? onError;

  @override
  State<RevealThemeBuilder> createState() => _RevealThemeBuilderState();
}

class _RevealThemeBuilderState extends State<RevealThemeBuilder> {
  Widget _viewportBuilder(BuildContext context, Widget? child) =>
      ThemeRevealViewport(
        onError: widget.onError,
        child: child ?? const SizedBox.shrink(),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => widget.builder(
      context,
      RevealThemeSettings._(widget.controller.themeMode, _viewportBuilder),
    ),
  );
}
