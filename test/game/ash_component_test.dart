// PRUEBAS del personaje, con un juego de Flame simulado: que se mueve
// velocidad x dt, que sin entrada no se mueve, que no sale de los límites
// del mapa, que no atraviesa obstáculos (pero se desliza por ellos), que se
// ordena en profundidad por su Y y que informa al dibujo de hacia dónde mira.

import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/components/ash_component.dart';
import 'package:pokemon_game/game/input/movement_input.dart';
import 'package:pokemon_game/game/visuals/ash_visual.dart';

class _RecordingVisual extends Component implements AshVisual {
  Facing? facing;
  bool? isMoving;

  @override
  void updateState({required Facing facing, required bool isMoving}) {
    this.facing = facing;
    this.isMoving = isMoving;
  }
}

void main() {
  late MovementInput input;
  late _RecordingVisual visual;

  AshComponent buildAsh({Vector2? position, CanOccupy? canOccupy}) =>
      AshComponent(
        input: input,
        bounds: Vector2(1000, 800),
        speed: 100,
        position: position ?? Vector2(500, 400),
        size: Vector2(20, 40),
        visual: visual,
        canOccupy: canOccupy,
      );

  setUp(() {
    input = MovementInput();
    visual = _RecordingVisual();
  });

  testWithFlameGame('moves at speed * dt in the input direction', (game) async {
    final ash = buildAsh();
    await game.world.ensureAdd(ash);

    input.setKeyboardDirection(Vector2(1, 0));
    game.update(0.5);

    expect(ash.position, Vector2(550, 400));
    expect(ash.isMoving, isTrue);
    expect(ash.facing, Facing.right);
  });

  testWithFlameGame('stays still without input', (game) async {
    final ash = buildAsh();
    await game.world.ensureAdd(ash);

    game.update(1);

    expect(ash.position, Vector2(500, 400));
    expect(ash.isMoving, isFalse);
  });

  testWithFlameGame('cannot leave the world bounds', (game) async {
    final ash = buildAsh(position: Vector2(30, 30));
    await game.world.ensureAdd(ash);

    input.setKeyboardDirection(Vector2(-1, -1));
    game.update(5);

    // Anchor is centered: half the size keeps the body inside.
    expect(ash.position, Vector2(10, 20));

    input.setKeyboardDirection(Vector2(1, 1));
    game.update(100);

    expect(ash.position, Vector2(990, 780));
  });

  testWithFlameGame('does not move when input is disabled', (game) async {
    final ash = buildAsh();
    await game.world.ensureAdd(ash);

    input
      ..setKeyboardDirection(Vector2(0, 1))
      ..enabled = false;
    game.update(1);

    expect(ash.position, Vector2(500, 400));
  });

  testWithFlameGame('reports facing and movement to the visual', (game) async {
    final ash = buildAsh();
    await game.world.ensureAdd(ash);

    input.setKeyboardDirection(Vector2(0, -1));
    game.update(0.1);
    expect(visual.facing, Facing.up);
    expect(visual.isMoving, isTrue);

    input.setKeyboardDirection(Vector2.zero());
    game.update(0.1);
    expect(visual.facing, Facing.up, reason: 'keeps last facing when idle');
    expect(visual.isMoving, isFalse);
  });

  // Un muro invisible: los pies no pueden pasar de x = 520.
  bool wallAt520(Rect feet) => feet.right <= 520;

  testWithFlameGame('stops at an obstacle', (game) async {
    final ash = buildAsh(canOccupy: wallAt520);
    await game.world.ensureAdd(ash);

    input.setKeyboardDirection(Vector2(1, 0));
    for (var i = 0; i < 20; i++) {
      game.update(0.05);
    }

    expect(ash.feet.right, lessThanOrEqualTo(520));
    expect(ash.position.x, greaterThan(505), reason: 'got close to the wall');
    expect(ash.facing, Facing.right, reason: 'keeps facing the wall');
  });

  testWithFlameGame('slides along an obstacle when moving diagonally', (
    game,
  ) async {
    final ash = buildAsh(canOccupy: wallAt520);
    await game.world.ensureAdd(ash);

    input.setKeyboardDirection(Vector2(1, 1));
    for (var i = 0; i < 20; i++) {
      game.update(0.05);
    }

    expect(ash.feet.right, lessThanOrEqualTo(520));
    expect(ash.position.y, greaterThan(460), reason: 'kept moving down');
  });

  testWithFlameGame('priority follows the bottom edge (y-sorting)', (
    game,
  ) async {
    final ash = buildAsh();
    await game.world.ensureAdd(ash);
    expect(ash.priority, 420, reason: 'center 400 + half height 20');

    input.setKeyboardDirection(Vector2(0, 1));
    game.update(0.5);

    expect(ash.priority, 470);
  });
}
