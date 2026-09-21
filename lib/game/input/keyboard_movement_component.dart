import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import 'movement_input.dart';

/// Translates keyboard state into [MovementInput]. Has no visual.
class KeyboardMovementComponent extends Component with KeyboardHandler {
  KeyboardMovementComponent({required this.input});

  final MovementInput input;

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    input.setKeyboardDirection(MovementInput.directionFromKeys(keysPressed));
    // Consume movement keys so the browser does not scroll the page.
    return !MovementInput.isMovementKey(event.logicalKey);
  }
}
