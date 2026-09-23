// PRUEBAS de la hierba alta y los Pokémon salvajes del mundo 3D: las matas
// salen solo en la hierba, se apartan de quien pasa, los Pokémon aparecen
// lejos del jugador, deambulan sin salir de la hierba, tocarlos dispara UN
// encuentro, andar por la hierba puede dar encuentros al azar, y la pausa
// y el tiempo de gracia los detienen.

import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/cell_noise.dart';
import 'package:pokemon_game/game3d/sim/grass_field.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/pokemon.dart';
import 'package:pokemon_game/models/pokemon_type.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

/// Random que siempre devuelve lo mismo (para forzar o evitar encuentros).
class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => (value * max).floor().clamp(0, max - 1);

  @override
  bool nextBool() => value >= 0.5;
}

void main() {
  // Pradera de hierba alta a la derecha, camino a la izquierda.
  final layout = MapLayout.parse(const [
    'TTTTTTTTTTTTTTTT',
    'T@.......""""""T',
    'T........""""""T',
    'T........""""""T',
    'T........""""""T',
    'TTTTTTTTTTTTTTTT',
  ]);

  void step(World3DSim s, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 30) {
      s.update(1 / 30);
    }
  }

  group('GrassField', () {
    test('tufts are placed only on tall grass cells', () {
      final field = GrassField.fromLayout(layout, 2, perCell: 3);
      expect(field.tufts, hasLength(6 * 4 * 3));
      for (final t in field.tufts) {
        final col = (t.x / 2).floor();
        final row = (t.z / 2).floor();
        expect(layout.tileAt(col, row), TileKind.tallGrass);
      }
    });

    test('same map, same tufts (stable noise)', () {
      final a = GrassField.fromLayout(layout, 2);
      final b = GrassField.fromLayout(layout, 2);
      expect(a.tufts.map((t) => t.x), b.tufts.map((t) => t.x));
      expect(cellNoise(-3, 7, 2), cellNoise(-3, 7, 2));
    });

    test('only wind far away; bends away from a nearby pusher', () {
      const tuft = GrassTuft(x: 0, z: 0, yaw: 0, scale: 1, phase: 1);
      final calm = GrassField.tiltFor(tuft, 0.3, const []);
      expect(calm.angle, lessThanOrEqualTo(GrassField.windStrength));

      // Alguien justo al oeste (-X): la punta debe irse hacia +X.
      final pushed = GrassField.tiltFor(tuft, 0.3, [Vector3(-0.3, 0, 0)]);
      expect(pushed.angle, greaterThan(0.5));
      final q = Quaternion.axisAngle(
        Vector3(pushed.axisX, 0, pushed.axisZ),
        pushed.angle,
      );
      // Ojo: se usa la MATRIZ (como el motor). En vector_math,
      // Quaternion.rotated gira en sentido contrario a su propia matriz.
      final tip = Matrix4.compose(
        Vector3.zero(),
        q,
        Vector3.all(1),
      ).transformed3(Vector3(0, 1, 0));
      expect(tip.x, greaterThan(0.4));

      final far = GrassField.tiltFor(tuft, 0.3, [Vector3(5, 0, 5)]);
      expect(far.angle, closeTo(calm.angle, 1e-9));
    });
  });

  group('wild Pokémon', () {
    test('spawn far from the player, inside tall grass', () {
      final s = World3DSim(layout: layout, random: Random(3));
      final w = s.spawn(fakePokemon(1))!;

      expect(s.isTallGrass(w.position), isTrue);
      expect(
        w.position.distanceTo(s.player.position),
        greaterThanOrEqualTo(World3DSim.minSpawnDistance),
      );
    });

    test('the spawn source fills the meadow up to the maximum', () async {
      var asked = 0;
      final s = World3DSim(
        layout: layout,
        random: Random(1),
        spawnWild: () async {
          asked++;
          return (pokemon: fakePokemon(asked), captureRate: 45);
        },
      );
      for (var i = 0; i < 40; i++) {
        step(s, 1);
        await pumpEventQueue();
      }
      // Pocas casillas lejos del jugador: al menos alguno, nunca más del tope.
      expect(s.wild, isNotEmpty);
      expect(s.wild.length, lessThanOrEqualTo(World3DSim.maxWild));
      expect(s.wild.map((w) => w.id).toSet(), hasLength(s.wild.length));
    });

    test('a failing source never breaks the world', () async {
      final s = World3DSim(
        layout: layout,
        spawnWild: () async => throw StateError('offline'),
      );
      step(s, 6);
      await pumpEventQueue();
      expect(s.wild, isEmpty);
    });

    test('late spawns after dispose are ignored', () async {
      final gate = Completer<void>();
      final s = World3DSim(
        layout: layout,
        spawnWild: () async {
          await gate.future;
          return (pokemon: fakePokemon(1), captureRate: 45);
        },
      );
      step(s, 1);
      s.dispose();
      gate.complete();
      await pumpEventQueue();
      expect(s.wild, isEmpty);
    });

    test('they wander but never leave the tall grass', () {
      final s = World3DSim(layout: layout, random: Random(7));
      final w = s.spawn(fakePokemon(1))!;
      final start = w.position;
      for (var i = 0; i < 600; i++) {
        s.update(1 / 30);
        expect(s.isTallGrass(w.position), isTrue);
      }
      expect(w.position.distanceTo(start), greaterThan(0.5));
      expect(w.age, closeTo(20, 1e-6));
    });

    test('an aggressive one that reaches you fires ONE contact', () {
      final contacts = <WildPokemon>[];
      final s = World3DSim(layout: layout, onWildContact: contacts.add);
      final w = s.spawn(fakePokemon(9))!;
      s.wild[0] = WildPokemon(
        id: w.id,
        pokemon: w.pokemon,
        position: w.position,
        temperament: Temperament.aggressive,
      )..alertTime = 10;
      s.player.teleport(w.position + Vector3(0.3, 0, 0));

      step(s, 0.5);
      expect(contacts.map((c) => c.id), [w.id]);
      expect(s.wild.single.engaged, isTrue);

      s.removeWild(w.id);
      expect(s.wild, isEmpty);
    });

    test('touching a calm one only startles it (no encounter)', () {
      final contacts = <WildPokemon>[];
      final s = World3DSim(layout: layout, onWildContact: contacts.add);
      final w = s.spawn(fakePokemon(9))!;
      s.wild[0] = WildPokemon(
        id: w.id,
        pokemon: w.pokemon,
        position: w.position,
        temperament: Temperament.curious,
      )..idleTime = 1e9;
      s.player.teleport(w.position + Vector3(0.3, 0, 0));

      step(s, 0.5);
      expect(contacts, isEmpty);
      expect(s.wild.single.isAlert, isTrue);
    });

    test('display size grows with the real height, within limits', () {
      WildPokemon withHeight(int dm) => WildPokemon(
        id: 'w',
        pokemon: Pokemon(
          id: 1,
          name: 'x',
          types: const [PokemonType.normal],
          imageUrl: null,
          height: dm,
          weight: 1,
        ),
        position: Vector3.zero(),
      );
      expect(withHeight(4).displayHeight, 1.1);
      expect(withHeight(21).displayHeight, closeTo(3.2, 1e-9));
      expect(withHeight(10).displayHeight, closeTo(1.8, 1e-9));
    });
  });

  group('encounters by walking in tall grass', () {
    World3DSim inGrass({required double roll, void Function()? onGrass}) {
      final s = World3DSim(
        layout: layout,
        random: _FixedRandom(roll),
        onGrassEncounter: onGrass,
        grassEncounters: true,
      );
      s.player.teleport(s.cellCenter(10, 2));
      return s;
    }

    test('an unlucky roll triggers an encounter', () {
      var count = 0;
      final s = inGrass(roll: 0, onGrass: () => count++);
      s.input.setKeyboardDirection(Vector2(1, 0));
      step(s, 1.5);
      expect(count, greaterThanOrEqualTo(1));
    });

    test('off by default in 3D', () {
      var count = 0;
      final s = World3DSim(
        layout: layout,
        random: _FixedRandom(0),
        onGrassEncounter: () => count++,
      );
      s.player.teleport(s.cellCenter(10, 2));
      s.input.setKeyboardDirection(Vector2(1, 0));
      step(s, 1.5);
      expect(count, 0);
    });

    test('a lucky roll never does', () {
      var count = 0;
      final s = inGrass(roll: 0.99, onGrass: () => count++);
      s.input.setKeyboardDirection(Vector2(1, 0));
      step(s, 2);
      expect(count, 0);
    });

    test('no encounters while paused or during the grace period', () {
      var count = 0;
      final s = inGrass(roll: 0, onGrass: () => count++)..setPaused(true);
      s.input.setKeyboardDirection(Vector2(1, 0));
      step(s, 1);
      expect(count, 0, reason: 'paused: input is off');
      expect(s.input.enabled, isFalse);

      s
        ..setPaused(false)
        ..input.setKeyboardDirection(Vector2(-1, 0));
      step(s, World3DSim.graceSeconds * 0.8);
      expect(count, 0, reason: 'grace period');
    });
  });
}
