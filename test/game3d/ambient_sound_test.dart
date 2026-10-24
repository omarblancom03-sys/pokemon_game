// PRUEBAS del SONIDO DEL CAMPO: las ráfagas de viento (las mismas que mecen
// árboles y hierba) se oyen cuando llegan al jugador, una vez por ráfaga y
// tan fuertes como su pico; las bandadas posadas pían a ratos (no en el
// aire) y aletean al salir volando, más fuerte cuanto más cerca.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/birds.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  final meadow = MapLayout.parse([
    'T' * 30,
    for (var i = 0; i < 16; i++) 'T${i == 8 ? '@' : '.'}${'.' * 27}T',
    'T' * 30,
  ]);

  group('wind', () {
    test('each gust that reaches the player is heard once, as strong as '
        'its peak', () {
      late World3DSim s;
      final gusts = <(double, double)>[]; // (segundo, fuerza)
      s = World3DSim(
        layout: meadow,
        maxFieldItems: 0,
        onEvent: (e) {
          if (e is WindGust) gusts.add((s.time, e.strength));
        },
      );
      for (var t = 0.0; t < 90; t += 1 / 30) {
        s.update(1 / 30);
      }
      expect(gusts.length, greaterThanOrEqualTo(3));
      final p = s.player.position;
      for (final (at, strength) in gusts) {
        expect(Wind.gustAt(at, p.x, p.z), greaterThan(0.55));
        expect(strength, inInclusiveRange(World3DSim.gustSound, 1));
      }
      // Entre dos que suenan, el viento amainó (una sola vez por ráfaga).
      for (var i = 1; i < gusts.length; i++) {
        var calmed = false;
        for (var t = gusts[i - 1].$1; t < gusts[i].$1; t += 0.05) {
          if (Wind.gustAt(t, p.x, p.z) < World3DSim.gustCalm) {
            calmed = true;
            break;
          }
        }
        expect(calmed, isTrue, reason: 'gust $i');
      }
    });
  });

  group('birds', () {
    BirdSystem birds() => BirdSystem.fromLayout(
      meadow,
      2,
      player: Vector3(3, 0, 17),
      random: Random(1),
    );

    test('a perched flock chirps every few seconds; not while flying', () {
      final s = birds();
      final chirps = <BirdFlock>[];
      s.onChirp = chirps.add;
      for (var t = 0.0; t < 30; t += 1 / 30) {
        s.update(
          1 / 30,
          Vector3(3, 0, 17),
          stealth: PlayerStealth.normal,
          moving: false,
        );
      }
      // Dos bandadas, cada una cada 1,8–4,2 s.
      expect(chirps.length, inInclusiveRange(14, 34));
      expect(chirps.toSet(), hasLength(2));

      final flock = s.flocks.first;
      final took = <BirdFlock>[];
      s.onTakeOff = took.add;
      s.startle(flock.spot, Vector3(3, 0, 17));
      expect(took, [flock]);
      chirps.clear();
      for (var t = 0.0; t < 1; t += 1 / 30) {
        s.update(
          1 / 30,
          Vector3(3, 0, 17),
          stealth: PlayerStealth.normal,
          moving: false,
        );
      }
      expect(chirps, isNot(contains(flock)));
    });

    test('the sim makes them heard, louder nearby, nothing far away', () {
      final events = <World3DEvent>[];
      final s = World3DSim(
        layout: meadow,
        maxFieldItems: 0,
        onEvent: events.add,
      );
      for (var t = 0.0; t < 20; t += 1 / 30) {
        s.update(1 / 30);
      }
      final chirps = events.whereType<BirdsChirped>().toList();
      expect(chirps, isNotEmpty);
      for (final c in chirps) {
        expect(c.loudness, inExclusiveRange(0, 1));
      }
      // Una bola que cae junto a una bandada la espanta: se oye el aleteo.
      final flock = s.birds.flocks.firstWhere((f) => !f.flying);
      final d = flock.spot.distanceTo(s.player.position);
      s.birds.startle(flock.spot, s.player.position);
      final took = events.whereType<BirdsTookOff>();
      if (d < World3DSim.birdHearRange) {
        expect(took.single.loudness, closeTo(1 - d / 30, 1e-6));
      } else {
        expect(took, isEmpty);
      }
    });
  });
}
