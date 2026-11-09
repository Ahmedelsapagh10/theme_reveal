import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../animation/reveal_animation_config.dart';
import '../animation/transition_state.dart';
import '../controller/reveal_theme_controller.dart';
import '../shapes/reveal_shape.dart';
import 'reveal_theme_trigger.dart';

/// Animation of the decorative button logo when the theme changes.
enum RevealLogoAnimation {
  /// Keep the decorative logo static (default).
  none,

  /// Scale from 80% to full size over 200ms.
  scale,

  /// Rotate from -45 degrees to upright over 200ms.
  rotate,

  /// Fade from transparent to opaque over 200ms.
  fade,
}

/// Immutable decoration and icon styling, independent of the reveal mask.
@immutable
class RevealButtonStyle {
  /// Creates the default 48px moon/sun appearance and press animation.
  const RevealButtonStyle({
    this.size = 48,
    this.backgroundColor,
    this.foregroundColor,
    this.border,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.lightIcon = Icons.light_mode_outlined,
    this.darkIcon = Icons.dark_mode_outlined,
    this.iconSize = 24,
    this.pressScale = .92,
    this.pressDuration = const Duration(milliseconds: 120),
  }) : assert(size > 0),
       assert(iconSize > 0),
       assert(pressScale > 0 && pressScale <= 1);

  /// Visual square size; the trigger targets at least 48px when constraints permit.
  final double size;

  /// Background override; otherwise uses the active theme container color.
  final Color? backgroundColor;

  /// Icon/indicator color override; otherwise follows theme and enabled state.
  final Color? foregroundColor;

  /// Optional decoration border.
  final BoxBorder? border;

  /// Decoration corner radius; does not change reveal geometry.
  final BorderRadius borderRadius;

  /// Icon displayed while the effective theme is light.
  final IconData lightIcon;

  /// Icon displayed while the effective theme is dark.
  final IconData darkIcon;

  /// Icon/indicator size and aspect-preserving decorative-logo fitting box.
  final double iconSize;

  /// Visual scale while pressed, in (0, 1].
  final double pressScale;

  /// Press/release animation duration unless motion is reduced.
  final Duration pressDuration;
}

/// A compact button; its decoration is independent of the reveal mask.
class RevealThemeButton extends StatefulWidget {
  /// Creates a compact controller-driven theme toggle with a circular mask by default.
  const RevealThemeButton({
    super.key,
    required this.controller,
    this.revealShape = const RevealShape.circle(),
    this.animation = const RevealAnimationConfig(),
    this.style = const RevealButtonStyle(),
    this.logo,
    this.logoAnimation = RevealLogoAnimation.none,
    this.tooltip,
    this.semanticLabel,
    this.enabled = true,
    this.busy = false,
  });

  /// Controller whose theme this button toggles.
  final RevealThemeController controller;

  /// Reveal silhouette, independent of the displayed icon or logo.
  final RevealShape revealShape;

  /// Reveal, origin, repeat and reduced-motion configuration.
  final RevealAnimationConfig animation;

  /// Visual decoration and icon styling.
  final RevealButtonStyle style;

  /// Decorative content fitted inside [RevealButtonStyle.iconSize], preserving
  /// its aspect ratio. This is NOT the reveal mask; use [revealShape] for that.
  final Widget? logo;

  /// Decorative logo animation on effective theme changes; defaults to none.
  final RevealLogoAnimation logoAnimation;

  /// Tooltip override; defaults to a theme-dependent switch label.
  final String? tooltip;

  /// Localized semantic label override; defaults to a theme-dependent switch label.
  final String? semanticLabel;

  /// Whether pointer, keyboard and semantic activation are allowed.
  final bool enabled;

  /// Shows progress, announces Busy and disables activation.
  ///
  /// This is caller-controlled; reduced-motion indicators are static.
  final bool busy;

  @override
  State<RevealThemeButton> createState() => _RevealThemeButtonState();
}

class _RevealThemeButtonState extends State<RevealThemeButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late bool _dark;
  AnimationController? _logoController;
  AnimationController get _logoAnimation =>
      _logoController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
        value: 1,
        animationBehavior: AnimationBehavior.preserve,
      );

  bool get _reduced => switch (widget.animation.reducedMotion) {
    RevealReducedMotion.system => MediaQuery.disableAnimationsOf(context),
    RevealReducedMotion.always => true,
    RevealReducedMotion.never => false,
  };

  @override
  void initState() {
    super.initState();
    _dark = widget.controller.isDark;
    widget.controller.addListener(_themeChanged);
  }

  void _themeChanged() {
    final dark = widget.controller.isDark;
    if (dark == _dark) return;
    _dark = dark;
    if (widget.logo != null &&
        widget.logoAnimation != RevealLogoAnimation.none &&
        !_reduced) {
      _logoAnimation.forward(from: 0);
    } else {
      _logoController?.value = 1;
    }
  }

  @override
  void didUpdateWidget(RevealThemeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_themeChanged);
      _dark = widget.controller.isDark;
      widget.controller.addListener(_themeChanged);
      _logoController?.value = 1;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_themeChanged);
    _logoController?.dispose();
    super.dispose();
  }

  Widget _buildLogo(RevealButtonStyle style, bool reduced) => AnimatedBuilder(
    animation: _logoAnimation,
    child: SizedBox.square(
      dimension: style.iconSize,
      child: FittedBox(fit: BoxFit.contain, child: widget.logo),
    ),
    builder: (context, child) {
      final progress = reduced ? 1.0 : _logoAnimation.value;
      return switch (widget.logoAnimation) {
        RevealLogoAnimation.none => child!,
        RevealLogoAnimation.scale => Transform.scale(
          scale: .8 + .2 * progress,
          child: child,
        ),
        RevealLogoAnimation.rotate => Transform.rotate(
          angle: -math.pi / 4 * (1 - progress),
          child: child,
        ),
        RevealLogoAnimation.fade => Opacity(opacity: progress, child: child),
      };
    },
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final dark = widget.controller.isDark;
      final style = widget.style;
      final colors = Theme.of(context).colorScheme;
      final reduced = _reduced;
      final foreground =
          style.foregroundColor ??
          (widget.enabled
              ? colors.onPrimaryContainer
              : Theme.of(context).disabledColor);
      final label =
          widget.semanticLabel ?? 'Switch to ${dark ? 'light' : 'dark'} theme';
      return Tooltip(
        message: widget.tooltip ?? label,
        excludeFromSemantics: true,
        child: RevealThemeTrigger(
          controller: widget.controller,
          revealShape: widget.revealShape,
          animation: widget.animation,
          enabled: widget.enabled && !widget.busy,
          semanticLabel: label,
          semanticValue: widget.busy ? 'Busy' : null,
          onPressedChanged: (pressed) {
            if (mounted && pressed != _pressed) {
              setState(() => _pressed = pressed);
            }
          },
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: AnimatedScale(
              scale: _pressed && widget.enabled && !widget.busy
                  ? style.pressScale
                  : 1,
              duration: reduced ? Duration.zero : style.pressDuration,
              child: Container(
                width: style.size,
                height: style.size,
                decoration: BoxDecoration(
                  color:
                      style.backgroundColor ??
                      (widget.enabled
                          ? colors.primaryContainer
                          : colors.surfaceContainerHighest),
                  border: style.border,
                  borderRadius: style.borderRadius,
                ),
                alignment: Alignment.center,
                child: widget.logo != null && !widget.busy
                    ? _buildLogo(style, reduced)
                    : AnimatedSwitcher(
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) =>
                            RotationTransition(
                              turns: Tween<double>(
                                begin: -.125,
                                end: 0,
                              ).animate(animation),
                              child: ScaleTransition(
                                scale: animation,
                                child: child,
                              ),
                            ),
                        child: widget.busy
                            ? SizedBox(
                                key: const ValueKey('busy'),
                                width: style.iconSize,
                                height: style.iconSize,
                                child: CircularProgressIndicator(
                                  value: reduced ? .5 : null,
                                  strokeWidth: 2,
                                  color: foreground,
                                ),
                              )
                            : Icon(
                                dark ? style.darkIcon : style.lightIcon,
                                key: ValueKey(dark),
                                size: style.iconSize,
                                color: foreground,
                              ),
                      ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
