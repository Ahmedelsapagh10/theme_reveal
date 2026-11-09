// snippet:external
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

Future<bool> revealCubitMode(
  BuildContext context, {
  required ThemeMode mode,
  required FutureOr<void> Function(ThemeMode) updateMode,
  RevealAnimationConfig config = const RevealAnimationConfig(),
}) => ThemeRevealViewport.of(context).reveal(
  from: context,
  shape: const RevealShape.circle(),
  config: config,
  onThemeChange: () => updateMode(mode),
);
// end:external
