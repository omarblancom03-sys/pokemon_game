// PRUEBAS del minimapa: está centrado en el jugador y girado con la cámara
// (arriba = hacia donde mira la cámara), escala por el radio, marca bolas y
// Pokémon (según lo que saben de ti) solo si caen dentro del círculo, y las
// flechas (jugador, norte) giran de forma coherente con los puntos.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/minimap.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

void main() {
  final origin = Vector3(10, 0, 10);

  group('project', () {
    test('with yaw 0, north (-Z) is up and east (+X) is right', () {
      final view = MinimapView(center: origin, yaw: 0, radius: 20);
      final north = view.project(origin + Vector3(0, 0, -10));
      expect(north.x, closeTo(0, 1e-6));
      expect(north.y, closeTo(-0.5, 1e-6));
      final east = view.project(origin + Vector3(10, 0, 0));
      expect(east.x, closeTo(0.5, 1e-6));
      expect(east.y, closeTo(0, 1e-6));
    });

    test('up is always where the camera looks (its forward)', () {
      for (final yaw in [0.3, pi / 2, -2.0, pi]) {
        final view = MinimapView(center: origin, yaw: yaw, radius: 10);
        // Adelante de la cámara: (-sin yaw, 0, -cos yaw).
        final ahead = view.project(
          origin + Vector3(-sin(yaw), 0, -cos(yaw)) * 5,
        );
        expect(ahead.x, closeTo(0, 1e-6), reason: 'yaw $yaw');
        expect(ahead.y, closeTo(-0.5, 1e-6), reason: 'yaw $yaw');
        // Derecha de la cámara: (cos yaw, 0, -sin yaw).
        final right = view.project(
          origin + Vector3(cos(yaw), 0, -sin(yaw)) * 5,
        );
        expect(right.x, closeTo(0.5, 1e-6), reason: 'yaw $yaw');
      }
    });

    test('inside is the unit circle', () {
      expect(MinimapView.inside((x: 0.6, y: 0.6)), isTrue);
      expect(MinimapView.inside((x: 0.8, y: 0.8)), isFalse);
    });

    test('screenAngle agrees with project for a facing direction', () {
      final view = MinimapView(center: origin, yaw: 0.8, radius: 10);
      for (final facing in [0.0, 1.0, pi, -2.5]) {
        final p = view.project(
          origin + Vector3(sin(facing), 0, cos(facing)) * 5,
        );
        final a = view.screenAngle(facing);
        // Ángulo desde "arriba" en sentido horario: (sin a, -cos a).
        expect(p.x, closeTo(sin(a) * 0.5, 1e-6), reason: 'facing $facing');
        expect(p.y, closeTo(-cos(a) * 0.5, 1e-6), reason: 'facing $facing');
      }
      expect(view.northAngle, closeTo(view.screenAngle(pi), 1e-12));
    });
  });

  group('markers', () {
    // Un pasillo de 40 x 4 casillas (80 m de largo).
    final layout = MapLayout.parse([
      'T' * 40,
      'T@${'.' * 37}T',
      'T${'.' * 38}T',
      'T' * 40,
    ]);

    World3DSim world() =>
        World3DSim(layout: layout, random: Random(1), maxFieldItems: 0);

    WildPokemon addWild(World3DSim s, Vector3 at) {
      final w = WildPokemon(
        id: 'w${s.wild.length}',
        pokemon: fakePokemon(1),
        position: at,
        temperament: Temperament.skittish,
      );
      s.wild.add(w);
      return w;
    }

    test('balls and free Pokémon inside the circle, nothing outside', () {
      final s = world();
      final p = s.player.position;
      s.fieldItems.drop(PokeBallType.great, p + Vector3(5, 0, 0));
      s.fieldItems.drop(PokeBallType.poke, p + Vector3(70, 0, 0));
      addWild(s, p + Vector3(10, 0, 0));
      addWild(s, p + Vector3(60, 0, 0));
      addWild(s, p + Vector3(12, 0, 0)).capturedBy = 'ball-0';

      final marks = MinimapView.of(s).markers(s);
      expect(marks.map((m) => m.mark), [MinimapMark.ball, MinimapMark.calm]);
      expect(marks.last.x, closeTo(10 / MinimapView.defaultRadius, 1e-6));
    });

    test('a Pokémon is marked by what it knows about you', () {
      final w = WildPokemon(
        id: 'w',
        pokemon: fakePokemon(1),
        position: Vector3.zero(),
        temperament: Temperament.aggressive,
      );
      expect(MinimapMark.forWild(w), MinimapMark.calm);
      w.awareness = 0.5;
      expect(MinimapMark.forWild(w), MinimapMark.suspicious);
      w.alertTime = 3;
      expect(MinimapMark.forWild(w), MinimapMark.hostile);

      final shy = WildPokemon(
        id: 's',
        pokemon: fakePokemon(1),
        position: Vector3.zero(),
        temperament: Temperament.skittish,
      )..alertTime = 3;
      expect(MinimapMark.forWild(shy), MinimapMark.alert);
    });
  });
}
