// PRUEBAS de la HIERBA PISADA: las matas por las que pasa corriendo un
// Pokémon quedan tumbadas hacia donde iba (del todo en el centro, menos
// en los bordes), siguen así un rato y luego se levantan poco a poco; una
// pisada más floja no borra una fuerte. En el mundo: el que huye por la
// hierba alta deja rastro; el que pasea, no.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/grass_field.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

GrassTuft tuft(double x, double z) =>
    GrassTuft(x: x, z: z, yaw: 0, scale: 1, phase: 0);

void main() {
  group('GrassTrampling', () {
    // Una fila de matas a lo largo de x, en z = 1 (casillas de 2 m).
    GrassTrampling row() => GrassTrampling(
      GrassField([for (var i = 0; i < 10; i++) tuft(0.5 + i * 0.5, 1)]),
      tileSize: 2,
    );

    test('a run flattens the tufts it passes towards where it went', () {
      final t = row()..trample(Vector3(2.5, 0, 1), Vector3(0, 0, 3));
      // Mata 4 (x = 2,5): de lleno; 3 y 5 (a 0,5 m): algo menos; a 1 m, nada.
      expect(t.amountOf(4), 1);
      expect(t.amountOf(3), inExclusiveRange(0, 1));
      expect(t.amountOf(5), t.amountOf(3));
      expect(t.amountOf(2), 0);
      expect(t.amountOf(6), 0);
      expect(t.trampled.toSet(), {3, 4, 5});
      // Tumbada hacia +Z (hacia donde iba), con el ángulo máximo.
      final bend = t.bendOf(4);
      expect(bend.x, closeTo(0, 1e-9));
      expect(bend.z, closeTo(GrassTrampling.maxBend, 1e-9));
      expect(t.bendOf(8), (x: 0.0, z: 0.0));
      // Y aplastada (más baja); las demás, a su altura.
      expect(t.heightOf(4), closeTo(1 - GrassTrampling.flatten, 1e-9));
      expect(t.heightOf(8), 1);
    });

    test('flattened for a while, then it gets back up', () {
      final t = row()..trample(Vector3(2.5, 0, 1), Vector3(1, 0, 0));
      t.update(GrassTrampling.holdTime);
      expect(t.amountOf(4), 1);
      t.update(GrassTrampling.recoverTime / 2);
      expect(t.amountOf(4), closeTo(0.5, 1e-9));
      t.update(GrassTrampling.recoverTime / 2 + 0.01);
      expect(t.amountOf(4), 0);
      expect(t.trampled, isEmpty);
    });

    test('a weaker run does not undo a stronger one; a fresh one does', () {
      final t = row()..trample(Vector3(2.5, 0, 1), Vector3(1, 0, 0));
      // Otra pasada de refilón, hacia -Z: la mata 4 sigue como estaba.
      t.trample(Vector3(2.5, 0, 1.6), Vector3(0, 0, -1));
      expect(t.bendOf(4).x, closeTo(GrassTrampling.maxBend, 1e-9));
      // Ya casi levantada, la misma pasada sí la tumba hacia -Z.
      t
        ..update(GrassTrampling.life - 1)
        ..trample(Vector3(2.5, 0, 1.6), Vector3(0, 0, -1));
      expect(t.bendOf(4).z, lessThan(0));
    });

    test('standing still (no direction) flattens nothing', () {
      final t = row()..trample(Vector3(2.5, 0, 1), Vector3.zero());
      expect(t.trampled, isEmpty);
    });
  });

  test('tiltFor: a bent tuft leans its tip where the bend points', () {
    for (final (bx, bz) in const [(0.8, 0.0), (0.0, 0.8), (-0.56, -0.56)]) {
      final tilt = GrassField.tiltFor(
        tuft(0, 0),
        0,
        const [],
        bend: (x: bx, z: bz),
      );
      // Punta = eje × ... : con eje (ax, 0, az), la punta va hacia (-az, ax).
      final tip = Vector2(-tilt.axisZ, tilt.axisX);
      final want = Vector2(bx, bz)..normalize();
      expect(tip.dot(want), greaterThan(0.98), reason: '($bx, $bz)');
      expect(tilt.angle, closeTo(0.8, 0.1));
    }
  });

  group('in the world', () {
    // Césped al oeste (el jugador) y hierba alta al este.
    final layout = MapLayout.parse([
      'T' * 30,
      for (var row = 1; row < 9; row++)
        'T${row == 4 ? '@' : '.'}${'.' * 5}${'"' * 22}T',
      'T' * 30,
    ]);

    World3DSim world() =>
        World3DSim(layout: layout, random: Random(3), maxFieldItems: 0);

    WildPokemon add(World3DSim s, Temperament temperament) {
      final w = WildPokemon(
        id: 'w',
        pokemon: fakePokemon(1),
        position: s.cellCenter(10, 4),
        temperament: temperament,
      );
      s.wild.add(w);
      return w;
    }

    void run(World3DSim s, double seconds) {
      for (var t = 0.0; t < seconds; t += 1 / 60) {
        s.update(1 / 60);
      }
    }

    test('one that flees through the tall grass leaves a trail pointing '
        'away from you', () {
      final s = world();
      final w = add(s, Temperament.skittish);
      final start = w.position;
      s.behavior.startle(w);
      run(s, 1);
      expect(w.position.x, greaterThan(start.x + 3), reason: 'it fled east');
      final bent = s.trampled.trampled.toList();
      expect(bent, isNotEmpty);
      for (final i in bent) {
        final tf = s.grass.tufts[i];
        // Por donde pasó, y tumbadas hacia el este (lejos del jugador).
        expect(tf.x, inInclusiveRange(start.x - 1, w.position.x + 1));
        expect(s.trampled.bendOf(i).x, greaterThan(0));
      }
    });

    test('a calm one strolling around leaves no trail', () {
      final s = world();
      final w = add(s, Temperament.skittish);
      run(s, 6);
      expect(w.distanceMoved, greaterThan(1), reason: 'it did stroll');
      expect(w.isAlert, isFalse);
      expect(s.trampled.trampled, isEmpty);
    });
  });
}
