import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../animation/reveal_animation_config.dart';
import '../animation/theme_reveal_viewport.dart';
import '../controller/reveal_theme_controller.dart';
import '../shapes/reveal_shape.dart';

/// Makes arbitrary visual content an accessible theme toggle. The trigger owns
/// activation; interactive children are treated as decoration to avoid two taps.
class RevealThemeTrigger extends StatefulWidget {
  /// Wraps child as a theme toggle; child input/semantics are decorative.
  const RevealThemeTrigger({
    super.key,
    required this.controller,
    required this.child,
    this.revealShape = const RevealShape.circle(),
    this.animation = const RevealAnimationConfig(),
    this.enabled = true,
    this.semanticLabel,
    this.semanticValue,
    this.onPressedChanged,
  });

  /// Controller whose theme this trigger toggles.
  final RevealThemeController controller;

  /// Arbitrary visual content; the trigger owns input, focus and semantics.
  final Widget child;

  /// Mask description forwarded to the viewport.
  final RevealShape revealShape;

  /// Reveal and interaction motion policy forwarded to the engine.
  final RevealAnimationConfig animation;

  /// Whether the trigger accepts pointer, keyboard and semantic activation.
  final bool enabled;

  /// Semantic label override; defaults to Switch to light/dark theme.
  final String? semanticLabel;

  /// Optional semantic status such as Busy.
  final String? semanticValue;

  /// Reports press/release state; disabled updates notify after the build frame.
  final ValueChanged<bool>? onPressedChanged;

  @override
  State<RevealThemeTrigger> createState() => _RevealThemeTriggerState();
}

class _RevealThemeTriggerState extends State<RevealThemeTrigger> {
  Offset? _pointerDown;
  bool _focused = false;
  bool _hasFocus = false;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _activate([Offset? globalPosition]) async {
    if (!widget.enabled) return;
    final viewport = ThemeRevealViewport.maybeOf(context);
    if (viewport == null) {
      widget.controller.toggleTheme();
    } else {
      await viewport.toggleTheme(
        widget.controller,
        from: context,
        globalPosition: globalPosition,
        shape: widget.revealShape,
        config: widget.animation,
      );
    }
  }

  @override
  void didUpdateWidget(RevealThemeTrigger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _pointerDown = null;
      // A consumer may update its own state when the press is released.
      // didUpdateWidget runs during build, so notify after that frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.enabled) widget.onPressedChanged?.call(false);
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      focusable: widget.enabled,
      focused: widget.enabled ? _hasFocus : null,
      onFocus: widget.enabled ? _focusNode.requestFocus : null,
      label:
          widget.semanticLabel ??
          'Switch to ${widget.controller.isDark ? 'light' : 'dark'} theme',
      value: widget.semanticValue,
      onTap: widget.enabled ? () => unawaited(_activate()) : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        focusNode: _focusNode,
        onFocusChange: (focused) => setState(() => _hasFocus = focused),
        enabled: widget.enabled,
        mouseCursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              unawaited(_activate());
              return null;
            },
          ),
        },
        onShowFocusHighlight: (focused) => setState(() => _focused = focused),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: widget.enabled
              ? (details) {
                  _pointerDown = details.globalPosition;
                  widget.onPressedChanged?.call(true);
                }
              : null,
          onTapUp: widget.enabled
              ? (_) => widget.onPressedChanged?.call(false)
              : null,
          onTapCancel: () {
            _pointerDown = null;
            widget.onPressedChanged?.call(false);
          },
          onTap: widget.enabled
              ? () {
                  final position = _pointerDown;
                  _pointerDown = null;
                  unawaited(_activate(position));
                }
              : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: _focused
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : null,
              ),
              child: ExcludeFocus(child: IgnorePointer(child: widget.child)),
            ),
          ),
        ),
      ),
    ),
  );
}
