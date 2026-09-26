// PRUEBAS del ARO QUE SE ENCOGE al apuntar: empieza grande, se encoge a
// ritmo constante y vuelve a empezar; lo pequeño que esté al pulsar decide
// el tiro (¡Bien!/¡Genial!/¡Excelente!), que viaja con la bola y, si le da,
// multiplica la probabilidad. Sin apuntar, con una baya o sin objetivo no
// hay aro (ni bonus).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/capture/capture_calculator.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

void main() {
  group('ThrowRing', () {
    test('starts as big as the sight ring, shrinks, then starts over', () {
      final ring = ThrowRing()..update(1 / 60, target: 'a');
      expect(ring.active, isTrue);
      expect(ring.size, 1);
      expect(ring.quality, ThrowQuality.none);

      ring.update(ThrowRing.cycle / 2, target: 'a');
      expect(ring.size, closeTo(1 - (1 - ThrowRing.minSize) / 2, 1e-9));
      ring.update(ThrowRing.cycle / 2 - 0.01, target: 'a');
      expect(ring.size, closeTo(ThrowRing.minSize, 0.01));
      expect(ring.quality, ThrowQuality.excellent);
      ring.update(0.02, target: 'a');
      expect(ring.size, greaterThan(0.95), reason: 'starts over');
    });

    test('the smaller, the better the throw', () {
      expect(ThrowRing.qualityFor(1), ThrowQuality.none);
      expect(ThrowRing.qualityFor(0.76), ThrowQuality.none);
      expect(ThrowRing.qualityFor(0.6), ThrowQuality.nice);
      expect(ThrowRing.qualityFor(0.4), ThrowQuality.great);
      expect(ThrowRing.qualityFor(0.2), ThrowQuality.excellent);
      expect(
        ThrowQuality.values.map((q) => q.bonus),
        orderedEquals([1, 1.2, 1.5, 2]),
      );
    });

    test('another target (or none) starts it again', () {
      final ring = ThrowRing()
        ..update(0, target: 'a')
        ..update(1, target: 'a');
      expect(ring.size, lessThan(0.5));
      ring.update(1 / 60, target: 'b');
      expect(ring.target, 'b');
      expect(ring.size, 1);
      ring.update(1, target: null);
      expect(ring.active, isFalse);
      expect(ring.quality, ThrowQuality.none);
    });
  });

  test('CaptureCalculator: the throw bonus multiplies (and stacks)', () {
    double chance(ThrowQuality q, {bool eating = false}) =>
        CaptureCalculator.chance(
          captureRate: 51, // 0,2
          ball: PokeBallType.poke,
          unaware: true,
          fromBehind: false, // ×1,5
          eating: eating,
          quality: q,
        );
    expect(chance(ThrowQuality.none), closeTo(0.3, 1e-9));
    expect(chance(ThrowQuality.nice), closeTo(0.36, 1e-9));
    expect(chance(ThrowQuality.great), closeTo(0.45, 1e-9));
    expect(chance(ThrowQuality.excellent), closeTo(0.6, 1e-9));
    expect(chance(ThrowQuality.excellent, eating: true), closeTo(0.9, 1e-9));
  });

  group('in the world', () {
    final open = MapLayout.parse(const [
      'TTTTTTTTTTTTTTTTTTTTTTTT',
      'T......................T',
      'T......................T',
      'T..@...................T',
      'T......................T',
      'T......................T',
      'TTTTTTTTTTTTTTTTTTTTTTTT',
    ]);

    // Cámara hacia +X y un Pokémon 8 m delante, de espaldas y quieto:
    // ratio 51 (0,2) × por la espalda (2) = 0,4.
    (World3DSim, WildPokemon) world() {
      final s = World3DSim(layout: open, random: Random(1), maxFieldItems: 0)
        ..camera.yaw = -pi / 2;
      final w = WildPokemon(
        id: 'w',
        pokemon: fakePokemon(25),
        position: s.player.position + Vector3(8, 0, 0),
        captureRate: 51,
        temperament: Temperament.curious,
        facing: pi / 2,
      )..idleTime = 1e9;
      s.wild.add(w);
      return (s, w);
    }

    void step(World3DSim s, double seconds) {
      for (var t = 0.0; t < seconds; t += 1 / 60) {
        s.update(1 / 60);
      }
    }

    ThrownBall throwAndHit(World3DSim s) {
      expect(s.throwBall(PokeBallType.poke), isTrue);
      while (s.balls.isEmpty || s.balls.single.phase == BallPhase.flying) {
        s.update(1 / 60);
      }
      return s.balls.single;
    }

    test('the ring runs only while aiming at someone with a ball', () {
      final (s, w) = world();
      step(s, 0.2);
      expect(s.lockedTarget, w);
      expect(s.throwRing.active, isFalse, reason: 'not aiming');

      s.aiming = true;
      step(s, 0.5);
      expect(s.throwRing.target, w.id);
      expect(s.throwRing.size, lessThan(1));

      s.berryReady = true; // una baya no captura: sin aro
      step(s, 0.1);
      expect(s.throwRing.active, isFalse);
      s
        ..berryReady = false
        ..readyBall = null; // sin bolas
      step(s, 0.1);
      expect(s.throwRing.active, isFalse);
    });

    test('throwing with a small ring: "¡Excelente!" doubles the chance', () {
      final (s, _) = world();
      s.aiming = true;
      // Hasta que el aro está en la zona excelente.
      step(s, 1 / 60);
      while (s.throwRing.quality != ThrowQuality.excellent) {
        s.update(1 / 60);
      }
      final ball = throwAndHit(s);
      expect(ball.quality, ThrowQuality.excellent);
      expect(ball.result!.chance, closeTo(0.8, 1e-9));
    });

    test('the quality is the one when you press, not at release', () {
      final (s, _) = world();
      s.aiming = true;
      step(s, 1 / 60);
      // Pulsar con el aro aún grande: aunque se encoja mientras el brazo
      // termina el gesto, el tiro se queda sin bonus.
      final ball = throwAndHit(s);
      expect(ball.quality, ThrowQuality.none);
      expect(ball.result!.chance, closeTo(0.4, 1e-9));
    });

    test('a quick throw without aiming has no ring bonus', () {
      final (s, _) = world();
      step(s, 1.5);
      final ball = throwAndHit(s);
      expect(ball.quality, ThrowQuality.none);
    });
  });
}
