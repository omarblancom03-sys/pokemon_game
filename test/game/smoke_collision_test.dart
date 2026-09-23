// PRUEBA de colisión: que entrar en el humo avisa con su id (y una sola
// vez, gracias al hitbox sólido).

import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/components/ash_component.dart';
import 'package:pokemon_game/game/components/smoke_component.dart';
import 'package:pokemon_game/game/config/world_config.dart';
import 'package:pokemon_game/game/input/movement_input.dart';
import 'package:pokemon_game/game/poke_game.dart';

class _CollisionGame extends FlameGame with HasCollisionDetection {}

void main() {
  late MovementInput input;
  late List<String> reached;

  setUp(() {
    input = MovementInput();
    reached = [];
  });

  AshComponent buildAsh(Vector2 position) => AshComponent(
    input: input,
    bounds: Vector2(1000, 1000),
    speed: 200,
    position: position,
    size: Vector2(32, 40),
  );

  SmokeComponent buildSmoke() => SmokeComponent(
    id: 'smoke-a',
    position: Vector2(500, 500),
    radius: 28,
    onAshReached: reached.add,
  );

  testWithGame<_CollisionGame>(
    'walking into a smoke reports its id once',
    _CollisionGame.new,
    (game) async {
      final ash = buildAsh(Vector2(300, 500));
      await game.world.ensureAddAll([buildSmoke(), ash]);

      game.update(0.1);
      expect(reached, isEmpty, reason: 'still far away');

      input.setKeyboardDirection(Vector2(1, 0));
      for (var i = 0; i < 20; i++) {
        game.update(0.1);
      }

      expect(reached, ['smoke-a']);
    },
  );

  testWithGame<_CollisionGame>(
    'does not report while Ash stays away',
    _CollisionGame.new,
    (game) async {
      await game.world.ensureAddAll([
        buildSmoke(),
        buildAsh(Vector2(100, 100)),
      ]);

      for (var i = 0; i < 10; i++) {
        game.update(0.1);
      }

      expect(reached, isEmpty);
    },
  );

  testWithGame<PokeGame>(
    'PokeGame spawns configured smokes, pauses input and removes smokes',
    () => PokeGame(
      onSmokeReached: reached.add,
      config: const WorldConfig(
        smokeRespawnSeconds: 1,
        smokeSpawns: [SmokeSpawn('s1', 100, 100), SmokeSpawn('s2', 200, 100)],
      ),
    ),
    (game) async {
      await game.ready();
      expect(game.smokes.map((s) => s.id), unorderedEquals(['s1', 's2']));

      game.setPaused(true);
      game.input.setKeyboardDirection(Vector2(1, 0));
      expect(game.input.direction, Vector2.zero());
      game.setPaused(false);
      expect(game.input.direction, Vector2(1, 0));

      game.removeSmoke('s1');
      await game.ready();
      expect(game.smokes.map((s) => s.id), ['s2']);

      game.update(1.1);
      await game.ready();
      expect(game.smokes, hasLength(2), reason: 'respawned elsewhere');

      // El humo nuevo cae en una casilla pisable y lejos de Ash.
      final respawned = game.smokes.firstWhere((s) => s.id != 's2');
      final tile = game.config.tileSize;
      expect(
        game.layout.isWalkable(
          (respawned.position.x / tile).floor(),
          (respawned.position.y / tile).floor(),
        ),
        isTrue,
      );
      expect(
        respawned.position.distanceTo(game.ash.position),
        greaterThanOrEqualTo(200),
      );
    },
  );
}
