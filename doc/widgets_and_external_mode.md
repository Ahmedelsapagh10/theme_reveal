# Widgets and external theme state

`RevealThemeButton(controller: controller)` keeps the original 48px moon/sun
button and circular reveal. `RevealButtonStyle` controls its colors, border,
radius, icons, icon size and press animation. Smaller visual sizes still have a
48px interaction target when the parent permits it. Avoid tighter constraints.

`logo` replaces the icon with decorative content, fitted within `iconSize` using
`BoxFit.contain` to preserve its aspect ratio. It is **not the reveal mask**.
Choose `revealShape` separately to reveal with an asset or vector silhouette.
`logoAnimation` defaults to `RevealLogoAnimation.none`; `scale`, `rotate` and
`fade` animate the same logo child for 200ms on an effective theme change.

`busy: true` shows a progress indicator, announces “Busy”, and prevents activation.
`enabled: false` disables pointer, keyboard and semantic activation and uses
disabled colors unless explicit style colors were supplied. `tooltip` and
`semanticLabel` override the default theme-dependent “Switch to … theme” text;
localize these strings for your app. Logos and custom children are decorative;
their own semantics and input handlers are suppressed.

`RevealThemeTrigger` wraps any custom child and owns its tap, Enter/Space and
screen-reader activation. Its default origin is the child's interaction area
center. `RevealOrigin.gesture()` uses pointer-down coordinates, falling back to
the center for keyboard and semantic activation. Keyed and contextual origins
are converted from global to viewport coordinates, including scrolling,
SafeArea, transforms and nested navigators. Start/end origins follow RTL.

Reduced motion is configured by `animation.reducedMotion`: `system` follows
`MediaQuery.disableAnimations`, `always` changes instantly, and `never`
explicitly enables animation. The button follows the same policy for press,
icon and logo animations; reduced-motion busy indicators are static.
Theme colors (including a supplied high-contrast theme) and text scaling are
inherited from the app. Focus is shown with the theme's primary color.

## External mode

Install `ThemeRevealViewport` through `MaterialApp.builder`, and set
`themeAnimationDuration: Duration.zero`. Drive `themeMode` from your own state.
The viewport has no dependency on Cubit/BLoC or any other state manager.

```dart
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
```

`onThemeChange` **must complete after the new state has been emitted**, not merely
after scheduling a change. The engine then waits two end-of-frames before
revealing the live app. This also works with asynchronous stream-driven state.
The callback runs only for an accepted request; `Future<bool>` reports whether
the change was applied. Instant fallbacks return true; ignored/superseded,
disposed or failed callbacks return false. Optional `onError` receives errors.

For the package controller the same viewport state exposes
`toggleTheme(controller, from:, globalPosition:, shape:, config:)` and
`setThemeMode(controller, mode, from:, globalPosition:, shape:, config:)`.
These use the same capture, origin, accessibility and cleanup pipeline.
