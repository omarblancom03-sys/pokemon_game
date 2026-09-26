// PRUEBAS de las PISADAS que suenan: una por paso, con el suelo que hay bajo
// el pie (tierra, losas, césped, hierba alta) y lo fuerte que pisas, que es
// lo mismo que te delata: corriendo a tope, andando la mitad, agachado casi
// nada (y en la hierba alta, menos aún). Rodando no hay pisadas.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  // Filas de izquierda a derecha: camino de tierra, losas, césped y hierba.
  final strips = MapLayout.parse(const [
    'TTTTTTTTTTTTTTTTTTTTTTTT',
    'T=====================@T',
    'TooooooooooooooooooooooT',
    'T......................T',
    'T""""""""""""""""""""""T',
    'TTTTTTTTTTTTTTTTTTTTTTTT',
  ]);

  (World3DSim, List<Footstep>) world(int row) {
    final steps = <Footstep>[];
    final s = World3DSim(
      layout: strips,
      maxFieldItems: 0,
      onEvent: (e) {
        if (e is Footstep) steps.add(e);
      },
    )..camera.yaw = -pi / 2; // adelante = +X
    s.player.teleport(s.cellCenter(2, row));
    return (s, steps);
  }

  void walk(World3DSim s, double seconds) {
    s.input.setKeyboardDirection(Vector2(0, -1));
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60);
    }
    s.input.setKeyboardDirection(Vector2.zero());
  }

  test('one step per stride, with the ground under the foot', () {
    for (final (row, surface) in [
      (1, GroundSurface.dirt),
      (2, GroundSurface.stone),
      (3, GroundSurface.lawn),
      (4, GroundSurface.tallGrass),
    ]) {
      final (s, steps) = world(row);
      walk(s, 1);
      // ~4 m andando, una pisada cada 0,75 m.
      expect(steps.length, inInclusiveRange(4, 7), reason: '$surface');
      expect(steps.map((f) => f.surface).toSet(), {surface});
      expect(steps.last.loudness, 0.5, reason: 'walking');
    }
  });

  test('running is loud; crouching is quiet, quieter in the tall grass', () {
    final (s, steps) = world(3);
    s.cameraInput.running = true;
    walk(s, 1);
    expect(steps.last.loudness, 1);

    final (c, crouched) = world(3);
    c.crouching = true;
    walk(c, 1.5);
    expect(crouched.last.loudness, closeTo(0.15, 1e-9));

    final (h, hidden) = world(4);
    h.crouching = true;
    walk(h, 1.5);
    expect(hidden.last.loudness, lessThan(0.1));
  });

  test('a roll makes no footsteps (it has its own sound)', () {
    final (s, steps) = world(1);
    s.roll();
    for (var t = 0.0; t < World3DSim.rollTime; t += 1 / 60) {
      s.update(1 / 60);
    }
    expect(steps, isEmpty);
  });
}
