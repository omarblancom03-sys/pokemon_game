// PRUEBAS de las briznas de hierba: cada brizna sube por encima de la
// hierba, gira, cae planeando, se queda en el suelo y se encoge hasta
// desaparecer; nunca hay más de maxBlades; corriendo por la hierba alta
// saltan más que andando y agachado ninguna (fuera de la hierba, tampoco);
// la hierba que se agita sobre un Pokémon escondido escupe briznas y,
// cuando sale, un surtidor.

import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/mesh/grass_mesh.dart';
import 'package:pokemon_game/game3d/sim/grass_blades.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

void main() {
  group('GrassBladeSystem', () {
    test('a blade flies up spinning, lands, shrinks and disappears', () {
      final blades = GrassBladeSystem(random: Random(1))
        ..footstep(Vector3(3, 0, 3), Vector3(0, 0, -7), running: true);
      expect(blades.blades, hasLength(3));
      final b = blades.blades.first;
      final y0 = b.position.y;

      // Sube por encima de la hierba alta (si no, no se vería).
      var peak = y0;
      for (var i = 0; i < 20; i++) {
        blades.update(1 / 60);
        peak = max(peak, b.position.y);
      }
      expect(peak, greaterThan(1));
      expect(b.angle, isNot(0));
      expect(b.scale, 1);

      // Cae planeando hasta el suelo y se queda quieta ahí.
      var guard = 0;
      while (b.landedFor == null) {
        blades.update(1 / 60);
        expect(b.velocity.y, greaterThan(-2.05), reason: 'falls gently');
        expect(++guard, lessThan(200));
      }
      expect(b.position.y, closeTo(GrassBladeSystem.groundY, 1e-6));
      final landed = b.position.clone();
      blades.update(0.2);
      expect(b.position, landed);
      expect(b.scale, closeTo(0.5, 0.05));

      // Encogida del todo, desaparece.
      blades.update(0.25);
      expect(blades.blades, isEmpty);
    });

    test('running kicks up more and higher blades than walking', () {
      final run = GrassBladeSystem(random: Random(2))
        ..footstep(Vector3.zero(), Vector3(7, 0, 0), running: true);
      final walk = GrassBladeSystem(random: Random(2))
        ..footstep(Vector3.zero(), Vector3(3, 0, 0), running: false);
      expect(run.blades.length, greaterThan(walk.blades.length));
      double maxUp(GrassBladeSystem s) =>
          s.blades.map((b) => b.velocity.y).reduce(max);
      expect(maxUp(run), greaterThan(maxUp(walk)));
    });

    test('never more than maxBlades (the oldest go first)', () {
      final blades = GrassBladeSystem(random: Random(3));
      for (var i = 0; i < 10; i++) {
        blades.burst(Vector3(i.toDouble(), 0, 0));
      }
      expect(blades.blades, hasLength(GrassBladeSystem.maxBlades));
      expect(blades.blades.last.position.x, 9);
    });

    test('rustling grass spits more blades the harder it shakes', () {
      int spat(double burst) {
        final blades = GrassBladeSystem(random: Random(4));
        for (var i = 0; i < 180; i++) {
          blades.rustle(Vector3(5, 0, 5), burst, 1 / 60);
        }
        for (final b in blades.blades) {
          expect(b.position.xz.distanceTo(Vector2(5, 5)), lessThan(0.75));
          expect(b.velocity.y, greaterThan(1.5));
        }
        return blades.blades.length;
      }

      expect(spat(0), 0);
      expect(spat(1), greaterThan(spat(0.3)));
      expect(spat(0.3), greaterThan(0));
    });

    test('a burst throws blades up in every direction', () {
      final blades = GrassBladeSystem(random: Random(5))
        ..burst(Vector3(2, 0, 2));
      expect(blades.blades.length, greaterThanOrEqualTo(10));
      var east = false, west = false, north = false, south = false;
      for (final b in blades.blades) {
        expect(b.velocity.y, greaterThan(2));
        east |= b.velocity.x > 0.5;
        west |= b.velocity.x < -0.5;
        south |= b.velocity.z > 0.5;
        north |= b.velocity.z < -0.5;
      }
      expect(east && west && north && south, isTrue);
    });
  });

  test(
    'the loose blade mesh is two-sided and centred (spins on its middle)',
    () {
      final m = buildLooseBlade();
      expect(m.triangleCount, 6);
      var front = 0, back = 0;
      var minY = double.infinity, maxY = -double.infinity;
      for (var i = 0; i < m.vertexCount; i++) {
        final nz = m.normals[i * 3 + 2];
        if (nz > 0.99) front++;
        if (nz < -0.99) back++;
        minY = min(minY, m.positions[i * 3 + 1]);
        maxY = max(maxY, m.positions[i * 3 + 1]);
      }
      expect(front, back, reason: 'same faces on both sides');
      expect(front + back, m.vertexCount);
      expect(minY, closeTo(-0.5, 1e-6));
      expect(maxY, closeTo(0.5, 1e-6));
    },
  );

  group('in the world', () {
    // Pradera abierta a la izquierda, hierba alta a la derecha.
    final layout = MapLayout.parse([
      'T' * 40,
      for (var i = 0; i < 6; i++)
        'T${i == 3 ? '@' : '.'}${'.' * 13}${'"' * 24}T',
      'T' * 40,
    ]);

    World3DSim world() =>
        World3DSim(layout: layout, random: Random(1), maxFieldItems: 0);

    /// Cuenta cuántas briznas nuevas salen en 1 s andando hacia +X (desde
    /// el centro de la hierba alta o desde la pradera).
    int bladesKicked({
      bool run = false,
      bool crouch = false,
      bool inGrass = true,
    }) {
      final s = world()..crouching = crouch;
      s.player.teleport(s.cellCenter(inGrass ? 18 : 3, 3));
      s.input.setKeyboardDirection(Vector2(1, 0));
      if (run) s.cameraInput.updateFromKeys({LogicalKeyboardKey.shiftLeft});
      var total = 0;
      for (var t = 0.0; t < 1; t += 1 / 60) {
        final before = s.blades.blades.length;
        s.update(1 / 60);
        total += max(0, s.blades.blades.length - before);
      }
      expect(s.isTallGrass(s.player.position), inGrass);
      return total;
    }

    test('running through tall grass kicks up more blades than walking', () {
      final running = bladesKicked(run: true);
      final walking = bladesKicked();
      expect(walking, greaterThan(0));
      expect(running, greaterThan(walking));
    });

    test('crouched, or out of the tall grass, no blades fly', () {
      expect(bladesKicked(crouch: true), 0);
      expect(bladesKicked(run: true, inGrass: false), 0);
    });

    test('grass over a hidden one spits blades; coming out, a burst', () {
      final s = world();
      s.camera.yaw = -pi / 2; // mirando hacia +X (hacia la hierba)
      final w = WildPokemon(
        id: 'h',
        pokemon: fakePokemon(1),
        position: s.player.position + Vector3(40, 0, 0),
        temperament: Temperament.skittish,
      )..hidden = true;
      s.wild.add(w);

      var spat = false;
      for (var t = 0.0; t < 4; t += 1 / 60) {
        s.update(1 / 60);
        spat |= s.blades.blades.any(
          (b) => b.position.xz.distanceTo(w.position.xz) < 1,
        );
      }
      expect(spat, isTrue);

      // Se acerca andando hasta que sale.
      s.player.teleport(w.position - Vector3(5, 0, 0));
      s.input.setKeyboardDirection(Vector2(0, -1));
      final before = s.blades.blades.length;
      var guard = 0;
      while (w.hidden) {
        s.update(1 / 60);
        expect(++guard, lessThan(200));
      }
      expect(s.blades.blades.length, greaterThanOrEqualTo(before + 10));
    });
  });
}
