import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import 'movement_input.dart';

/// Componente invisible: su único trabajo es traducir el teclado a
/// [MovementInput]. No dibuja nada.
class KeyboardMovementComponent extends Component with KeyboardHandler {
  KeyboardMovementComponent({required this.input});

  final MovementInput input;

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    input.setKeyboardDirection(MovementInput.directionFromKeys(keysPressed));
    // Devolver false = "me quedo con esta tecla". Se consumen las de
    // movimiento para que el navegador no haga scroll de la página.
    return !MovementInput.isMovementKey(event.logicalKey);
  }
}
