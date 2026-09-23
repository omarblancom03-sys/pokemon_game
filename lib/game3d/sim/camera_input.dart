import 'package:flutter/services.dart';

/// "Intención" de mover la cámara: la escriben el teclado (Q/E), el ratón
/// (arrastrar y rueda) y la lee la simulación en cada fotograma.
///
/// Los arrastres y la rueda se ACUMULAN hasta que la simulación los
/// consume con [takeDrag] / [takeZoom]; las teclas son un estado continuo.
class CameraInput {
  double _dragX = 0;
  double _dragY = 0;
  double _zoom = 0;

  /// -1 = girar a la izquierda (Q), +1 = a la derecha (E), 0 = quieto.
  double turnAxis = 0;

  /// Mayús pulsada: correr.
  bool running = false;

  void addDrag(double dx, double dy) {
    _dragX += dx;
    _dragY += dy;
  }

  void addZoom(double delta) => _zoom += delta;

  /// Devuelve el arrastre acumulado (en píxeles) y lo pone a cero.
  (double, double) takeDrag() {
    final result = (_dragX, _dragY);
    _dragX = 0;
    _dragY = 0;
    return result;
  }

  /// Devuelve el zoom acumulado y lo pone a cero.
  double takeZoom() {
    final result = _zoom;
    _zoom = 0;
    return result;
  }

  void clear() {
    takeDrag();
    takeZoom();
    turnAxis = 0;
    running = false;
  }

  /// Teclas pulsadas → estado de cámara y carrera.
  void updateFromKeys(Set<LogicalKeyboardKey> keys) {
    final left = keys.contains(LogicalKeyboardKey.keyQ) ? 1.0 : 0.0;
    final right = keys.contains(LogicalKeyboardKey.keyE) ? 1.0 : 0.0;
    turnAxis = right - left;
    running =
        keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
  }

  static bool isCameraKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.keyQ ||
      key == LogicalKeyboardKey.keyE ||
      key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight;
}
