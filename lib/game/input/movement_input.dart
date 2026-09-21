import 'package:flame/extensions.dart';
import 'package:flutter/services.dart';

/// "Intención de moverse" compartida: la escriben las fuentes de entrada
/// (teclado y D-pad en pantalla) y la lee AshComponent.
///
/// Así el personaje tiene UNA sola forma de saber hacia dónde ir, sin
/// importar con qué se juegue.
class MovementInput {
  final Vector2 _keyboard = Vector2.zero();
  final Vector2 _pad = Vector2.zero();

  /// Interruptor de pausa: si es false, [direction] siempre es cero.
  bool enabled = true;

  void setKeyboardDirection(Vector2 direction) => _keyboard.setFrom(direction);

  void setPadDirection(Vector2 direction) => _pad.setFrom(direction);

  void clear() {
    _keyboard.setZero();
    _pad.setZero();
  }

  /// Dirección actual, de longitud máxima 1. El D-pad manda sobre el teclado.
  Vector2 get direction {
    if (!enabled) return Vector2.zero();
    // clone(): se devuelve una copia, para que nadie altere el estado interno.
    final result = (_pad.isZero() ? _keyboard : _pad).clone();
    // Normalizar la diagonal: (1,1) mide 1,41; sin esto se iría un 41% más
    // rápido en diagonal que en línea recta.
    if (result.length2 > 1) result.normalize();
    return result;
  }

  // Teclas aceptadas: flechas y WASD.
  static final _left = {LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA};
  static final _right = {
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.keyD,
  };
  static final _up = {LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW};
  static final _down = {LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS};

  /// Teclas pulsadas → dirección. Las teclas opuestas se anulan (1 - 1 = 0).
  /// Ojo: en gráficos la Y crece hacia ABAJO, por eso "abajo" es +1.
  static Vector2 directionFromKeys(Set<LogicalKeyboardKey> keys) {
    double axis(
      Set<LogicalKeyboardKey> negative,
      Set<LogicalKeyboardKey> pos,
    ) =>
        (keys.any(pos.contains) ? 1.0 : 0.0) -
        (keys.any(negative.contains) ? 1.0 : 0.0);
    return Vector2(axis(_left, _right), axis(_up, _down));
  }

  /// ¿Es [key] una de las teclas de movimiento?
  static bool isMovementKey(LogicalKeyboardKey key) =>
      _left.contains(key) ||
      _right.contains(key) ||
      _up.contains(key) ||
      _down.contains(key);
}
