import 'package:flame/extensions.dart';
import 'package:flutter/services.dart';

/// Shared movement intent written by input sources (keyboard, on-screen
/// D-pad) and read by `AshComponent`. Keeps input devices decoupled from
/// the character logic.
class MovementInput {
  final Vector2 _keyboard = Vector2.zero();
  final Vector2 _pad = Vector2.zero();

  /// When false (e.g. during an encounter) [direction] is always zero.
  bool enabled = true;

  void setKeyboardDirection(Vector2 direction) => _keyboard.setFrom(direction);

  void setPadDirection(Vector2 direction) => _pad.setFrom(direction);

  void clear() {
    _keyboard.setZero();
    _pad.setZero();
  }

  /// Current direction with length ≤ 1. The D-pad wins over the keyboard.
  Vector2 get direction {
    if (!enabled) return Vector2.zero();
    final result = (_pad.isZero() ? _keyboard : _pad).clone();
    if (result.length2 > 1) result.normalize();
    return result;
  }

  static final _left = {LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA};
  static final _right = {
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.keyD,
  };
  static final _up = {LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW};
  static final _down = {LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS};

  /// Maps pressed keys (arrows / WASD) to a raw direction. Opposite keys
  /// cancel out.
  static Vector2 directionFromKeys(Set<LogicalKeyboardKey> keys) {
    double axis(
      Set<LogicalKeyboardKey> negative,
      Set<LogicalKeyboardKey> pos,
    ) =>
        (keys.any(pos.contains) ? 1.0 : 0.0) -
        (keys.any(negative.contains) ? 1.0 : 0.0);
    return Vector2(axis(_left, _right), axis(_up, _down));
  }

  /// Whether [key] is one of the movement keys.
  static bool isMovementKey(LogicalKeyboardKey key) =>
      _left.contains(key) ||
      _right.contains(key) ||
      _up.contains(key) ||
      _down.contains(key);
}
