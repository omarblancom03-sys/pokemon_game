// PRUEBAS del cuerpo del jugador en 3D: acelera hasta su velocidad, corre
// más rápido, se detiene contra obstáculos, se desliza junto a ellos y gira
// hacia donde camina.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game3d/sim/player_body.dart';
import 'package:pokemon_game/game3d/sim/world3d_config.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  const config = World3DConfig();

  PlayerBody body({FootprintTest? canOccupy}) => PlayerBody(
    config: config,
    canOccupy: canOccupy ?? (_) => true,
    position: Vector3.zero(),
  );

  void run(PlayerBody p, Vector3 wish, double seconds, {bool running = false}) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      p.update(1 / 60, wish, running: running);
    }
  }

  test('accelerates up to walk speed and no further', () {
    final p = body();
    run(p, Vector3(1, 0, 0), 2);

    expect(p.speed, closeTo(config.walkSpeed, 1e-3));
    expect(p.isMoving, isTrue);
    expect(p.position.x, greaterThan(config.walkSpeed * 1.5));
  });

  test('running is faster than walking', () {
    final p = body();
    run(p, Vector3(1, 0, 0), 2, running: true);
    expect(p.speed, closeTo(config.runSpeed, 1e-3));
  });

  test('stops when the wish is released', () {
    final p = body();
    run(p, Vector3(0, 0, 1), 1);
    run(p, Vector3.zero(), 1);
    expect(p.speed, closeTo(0, 1e-6));
    expect(p.isMoving, isFalse);
  });

  test('a wall stops the movement on that axis only (slides)', () {
    // Pared en x >= 1: el jugador no puede pasar, pero sí seguir en z.
    final p = body(canOccupy: (Rect r) => r.right < 1);
    run(p, Vector3(1, 0, 1)..normalize(), 2);

    expect(p.position.x, lessThan(1));
    expect(p.position.z, greaterThan(3));
  });

  test('turns smoothly to face the walking direction', () {
    final p = body()..facing = 0; // mirando a +Z
    p.update(1 / 60, Vector3(1, 0, 0)); // quiere ir a +X (π/2)
    expect(p.facing, greaterThan(0));
    expect(p.facing, lessThan(math.pi / 2));

    run(p, Vector3(1, 0, 0), 1);
    expect(p.facing, closeTo(math.pi / 2, 1e-6));
  });

  test('distanceWalked accumulates only real displacement', () {
    final p = body(canOccupy: (_) => false);
    run(p, Vector3(1, 0, 0), 1);
    expect(p.distanceWalked, 0);
    expect(p.position, Vector3.zero());
  });
}
