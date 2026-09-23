// PRUEBAS del polvo: cada nubecilla crece, sube y se desvanece; nunca hay
// más de maxPuffs; al correr sale una por pisada (andando o en la hierba
// alta, no), al frenar en seco tras correr sale un corro, y una Poké Ball
// que bota con fuerza también levanta polvo.

import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/dust.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('DustSystem', () {
    test('a puff grows, rises, fades and disappears', () {
      final dust = DustSystem(random: Random(1))
        ..footstep(Vector3(3, 0, 3), Vector3(0, 0, -7));
      expect(dust.puffs, hasLength(2));
      final puff = dust.puffs.first;
      final r0 = puff.radius;
      final o0 = puff.opacity;
      final y0 = puff.position.y;

      dust.update(0.2);
      expect(puff.radius, greaterThan(r0));
      expect(puff.opacity, lessThan(o0));
      expect(puff.position.y, greaterThan(y0));
      // Se queda atrás: el corredor iba hacia -Z, el polvo va hacia +Z.
      expect(puff.position.z, greaterThan(3));

      dust.update(1);
      expect(dust.puffs, isEmpty);
    });

    test('never more than maxPuffs (the oldest go first)', () {
      final dust = DustSystem(random: Random(2));
      for (var i = 0; i < 20; i++) {
        dust.burst(Vector3(i.toDouble(), 0, 0));
      }
      expect(dust.puffs, hasLength(DustSystem.maxPuffs));
      expect(dust.puffs.last.position.x, 19);
    });

    test('a stronger burst makes more and bigger puffs', () {
      final soft = DustSystem(random: Random(3))
        ..burst(Vector3.zero(), strength: 0.2);
      final hard = DustSystem(random: Random(3))..burst(Vector3.zero());
      expect(hard.puffs.length, greaterThan(soft.puffs.length));
      double maxSize(DustSystem d) => d.puffs.map((p) => p.size).reduce(max);
      expect(maxSize(hard), greaterThan(maxSize(soft)));
    });
  });

  group('in the world', () {
    // Pradera abierta a la izquierda, hierba alta a la derecha.
    final layout = MapLayout.parse([
      'T' * 30,
      for (var i = 0; i < 6; i++)
        'T${i == 3 ? '@' : '.'}${'.' * 13}${'"' * 14}T',
      'T' * 30,
    ]);

    World3DSim world() =>
        World3DSim(layout: layout, random: Random(1), maxFieldItems: 0);

    void step(World3DSim s, double seconds) {
      for (var t = 0.0; t < seconds; t += 1 / 60) {
        s.update(1 / 60);
      }
    }

    test('running kicks up dust; walking does not', () {
      final walker = world();
      walker.input.setKeyboardDirection(Vector2(1, 0));
      step(walker, 1.5);
      expect(walker.dust.puffs, isEmpty);

      final runner = world();
      runner.input.setKeyboardDirection(Vector2(1, 0));
      runner.cameraInput.updateFromKeys({LogicalKeyboardKey.shiftLeft});
      step(runner, 1);
      expect(runner.dust.puffs, isNotEmpty);
      // Todas cerca del suelo y por detrás del corredor.
      for (final p in runner.dust.puffs) {
        expect(p.position.x, lessThan(runner.player.position.x));
        expect(p.position.y, lessThan(1));
      }
    });

    test('no dust in the tall grass', () {
      final s = world();
      s.player.teleport(s.cellCenter(18, 3));
      s.input.setKeyboardDirection(Vector2(1, 0));
      s.cameraInput.updateFromKeys({LogicalKeyboardKey.shiftLeft});
      step(s, 0.8);
      expect(s.dust.puffs, isEmpty);
    });

    test('stopping dead after a run leaves a little cloud', () {
      final s = world();
      s.input.setKeyboardDirection(Vector2(1, 0));
      s.cameraInput.updateFromKeys({LogicalKeyboardKey.shiftLeft});
      step(s, 0.8);
      final before = s.dust.puffs.length;
      s.input.setKeyboardDirection(Vector2.zero());
      s.update(1 / 60);
      expect(s.dust.puffs.length, greaterThan(before + 2));
    });

    test('a thrown ball bouncing hard on the ground raises dust', () {
      final s = world();
      s.ballSystem.launch(
        PokeBallType.poke,
        s.player.position + Vector3(0, 3, 0),
        Vector3(4, 0, 0),
      );
      step(s, 1);
      expect(s.dust.puffs, isNotEmpty);
    });
  });
}
