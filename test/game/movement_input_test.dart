// PRUEBAS de la entrada: flechas y WASD, teclas opuestas que se anulan,
// diagonales normalizadas a longitud 1, prioridad del D-pad sobre el
// teclado, input desactivado (pausa) y que el vector devuelto es una copia.

import 'package:flame/extensions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/input/movement_input.dart';

void main() {
  group('directionFromKeys', () {
    test('maps arrows and WASD', () {
      expect(
        MovementInput.directionFromKeys({LogicalKeyboardKey.arrowRight}),
        Vector2(1, 0),
      );
      expect(
        MovementInput.directionFromKeys({LogicalKeyboardKey.keyW}),
        Vector2(0, -1),
      );
      expect(
        MovementInput.directionFromKeys({
          LogicalKeyboardKey.keyA,
          LogicalKeyboardKey.arrowDown,
        }),
        Vector2(-1, 1),
      );
    });

    test('opposite keys cancel out', () {
      expect(
        MovementInput.directionFromKeys({
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.keyD,
        }),
        Vector2.zero(),
      );
    });

    test('ignores non-movement keys', () {
      expect(
        MovementInput.directionFromKeys({LogicalKeyboardKey.space}),
        Vector2.zero(),
      );
      expect(MovementInput.isMovementKey(LogicalKeyboardKey.space), isFalse);
      expect(MovementInput.isMovementKey(LogicalKeyboardKey.keyS), isTrue);
    });
  });

  group('direction', () {
    test('diagonals are normalized to length 1', () {
      final input = MovementInput()..setKeyboardDirection(Vector2(1, 1));

      expect(input.direction.length, closeTo(1, 1e-6));
    });

    test('D-pad takes priority over keyboard', () {
      final input = MovementInput()
        ..setKeyboardDirection(Vector2(1, 0))
        ..setPadDirection(Vector2(0, -1));

      expect(input.direction, Vector2(0, -1));

      input.setPadDirection(Vector2.zero());
      expect(input.direction, Vector2(1, 0));
    });

    test('disabled input yields no movement', () {
      final input = MovementInput()
        ..setKeyboardDirection(Vector2(1, 0))
        ..enabled = false;

      expect(input.direction, Vector2.zero());
    });

    test('returned vector is a copy', () {
      final input = MovementInput()..setKeyboardDirection(Vector2(1, 0));

      input.direction.setZero();

      expect(input.direction, Vector2(1, 0));
    });
  });
}
