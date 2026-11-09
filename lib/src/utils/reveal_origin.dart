import 'package:flutter/material.dart';

import 'reveal_exception.dart';

enum _OriginKind { button, gesture, screen, corner, normalized, offset, key }

/// Resolves to the viewport's local coordinates, including transformed ancestors.
@immutable
class RevealOrigin {
  /// Uses the source widget center, or viewport center when no source is supplied.
  const RevealOrigin.buttonCenter() : this._(_OriginKind.button);

  /// Uses a global pointer position, falling back to the source center for keyboard input.
  const RevealOrigin.gesture() : this._(_OriginKind.gesture);

  /// Uses the viewport center, excluding native system UI outside the app.
  const RevealOrigin.screenCenter() : this._(_OriginKind.screen);

  /// Uses the physical top-left viewport corner.
  const RevealOrigin.topLeft() : this._(_OriginKind.corner, x: -1, y: -1);

  /// Uses the physical top-right viewport corner.
  const RevealOrigin.topRight() : this._(_OriginKind.corner, x: 1, y: -1);

  /// Uses the physical bottom-left viewport corner.
  const RevealOrigin.bottomLeft() : this._(_OriginKind.corner, x: -1, y: 1);

  /// Uses the physical bottom-right viewport corner.
  const RevealOrigin.bottomRight() : this._(_OriginKind.corner, x: 1, y: 1);

  /// Uses the top leading corner according to text direction.
  const RevealOrigin.topStart()
    : this._(_OriginKind.corner, x: -1, y: -1, directional: true);

  /// Uses the top trailing corner according to text direction.
  const RevealOrigin.topEnd()
    : this._(_OriginKind.corner, x: 1, y: -1, directional: true);

  /// Uses the bottom leading corner according to text direction.
  const RevealOrigin.bottomStart()
    : this._(_OriginKind.corner, x: -1, y: 1, directional: true);

  /// Uses the bottom trailing corner according to text direction.
  const RevealOrigin.bottomEnd()
    : this._(_OriginKind.corner, x: 1, y: 1, directional: true);

  /// Fractions of viewport width and height; (0, 0) is its top-left corner.
  const RevealOrigin.normalized(double x, double y)
    : this._(_OriginKind.normalized, x: x, y: y);

  /// Logical pixels from the viewport's top-left corner.
  const RevealOrigin.offset(double dx, double dy)
    : this._(_OriginKind.offset, x: dx, y: dy);

  /// Uses the keyed render box center; an unattached key is a reveal error.
  const RevealOrigin.fromKey(GlobalKey key) : this._(_OriginKind.key, key: key);

  const RevealOrigin._(
    this._kind, {
    double x = 0,
    double y = 0,
    bool directional = false,
    GlobalKey? key,
  }) : _x = x,
       _y = y,
       _directional = directional,
       _key = key;

  final _OriginKind _kind;
  final double _x;
  final double _y;
  final bool _directional;
  final GlobalKey? _key;

  /// Low-level coordinate resolution used by the engine.
  ///
  /// Converts global/source coordinates into viewport-local logical pixels.
  /// Supply textDirection for directional corners. Throws RevealException for
  /// non-finite coordinates or an unattached keyed render box.
  Offset resolve({
    required RenderBox viewport,
    BuildContext? from,
    Offset? globalPosition,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final size = viewport.size;
    final center = size.center(Offset.zero);
    Offset fromContext(BuildContext? source, {bool required = false}) {
      final render = source?.mounted == true
          ? source!.findRenderObject()
          : null;
      if (render is RenderBox && render.attached && render.hasSize) {
        return viewport.globalToLocal(
          render.localToGlobal(render.size.center(Offset.zero)),
        );
      }
      if (required) {
        throw const RevealException(
          'Reveal origin key has no attached, laid-out RenderBox.',
        );
      }
      return center;
    }

    final result = switch (_kind) {
      _OriginKind.button => fromContext(from),
      _OriginKind.gesture =>
        globalPosition == null
            ? fromContext(from)
            : viewport.globalToLocal(globalPosition),
      _OriginKind.screen => center,
      _OriginKind.corner => Offset(
        ((_directional && textDirection == TextDirection.rtl ? -_x : _x) + 1) *
            size.width /
            2,
        (_y + 1) * size.height / 2,
      ),
      _OriginKind.normalized => Offset(_x * size.width, _y * size.height),
      _OriginKind.offset => Offset(_x, _y),
      _OriginKind.key => fromContext(_key!.currentContext, required: true),
    };
    if (!result.dx.isFinite || !result.dy.isFinite) {
      throw const RevealException(
        'Reveal origin must have finite coordinates.',
      );
    }
    return result;
  }
}
