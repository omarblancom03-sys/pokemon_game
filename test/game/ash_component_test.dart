// PRUEBAS del personaje, con un juego de Flame simulado: que se mueve
// velocidad x dt, que sin entrada no se mueve, que no sale de los límites
// del mapa y que informa al dibujo de hacia dónde mira.

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

  AshComponent buildAsh({Vector2? position}) => AshComponent(
    input: input,
    bounds: Vector2(1000, 800),
    speed: 100,
    position: position ?? Vector2(500, 400),
    size: Vector2(20, 40),
    visual: visual,
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
}
