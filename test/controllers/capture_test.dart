// PRUEBAS de la captura: la probabilidad crece con el ratio de la especie,
// la bola y el sigilo; las sacudidas cuadran con el resultado; y la bolsa
// del entrenador cuenta, elige y gasta bolas correctamente.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/capture/capture_calculator.dart';
import 'package:pokemon_game/controllers/trainer_controller.dart';
import 'package:pokemon_game/models/poke_ball.dart';

import '../fakes/fake_pokemon_repository.dart';

/// Random que devuelve una secuencia fija.
class _SeqRandom implements Random {
  _SeqRandom(this.values);

  final List<double> values;
  var _i = 0;

  @override
  double nextDouble() => values[_i++ % values.length];

  @override
  int nextInt(int max) => (nextDouble() * max).floor();

  @override
  bool nextBool() => nextDouble() >= 0.5;
}

void main() {
  group('CaptureCalculator.chance', () {
    double chance(
      int rate,
      PokeBallType ball, {
      bool unaware = false,
      bool back = false,
    }) => CaptureCalculator.chance(
      captureRate: rate,
      ball: ball,
      unaware: unaware,
      fromBehind: back,
    );

    test('grows with the species rate and the ball', () {
      expect(chance(45, PokeBallType.poke), closeTo(45 / 255, 1e-9));
      expect(chance(45, PokeBallType.great), closeTo(45 / 255 * 1.5, 1e-9));
      expect(chance(45, PokeBallType.ultra), closeTo(45 / 255 * 2, 1e-9));
      expect(chance(3, PokeBallType.poke), lessThan(0.02)); // legendario
    });

    test('stealth bonus: unaware ×1.5, from behind ×2', () {
      expect(
        chance(45, PokeBallType.poke, unaware: true),
        closeTo(45 / 255 * 1.5, 1e-9),
      );
      expect(
        chance(45, PokeBallType.poke, unaware: true, back: true),
        closeTo(45 / 255 * 2, 1e-9),
      );
      // Por la espalda no cuenta si ya te ha visto.
      expect(
        chance(45, PokeBallType.poke, back: true),
        closeTo(45 / 255, 1e-9),
      );
    });

    test('never above 1', () {
      expect(chance(255, PokeBallType.ultra, unaware: true, back: true), 1);
    });
  });

  group('CaptureCalculator.roll', () {
    test('4 passed checks = caught with 3 shakes', () {
      final calc = CaptureCalculator(random: _SeqRandom([0]));
      final r = calc.roll(
        captureRate: 45,
        ball: PokeBallType.poke,
        unaware: false,
        fromBehind: false,
      );
      expect(r.caught, isTrue);
      expect(r.shakes, 3);
    });

    test('failing the second check = one shake and escape', () {
      final calc = CaptureCalculator(random: _SeqRandom([0, 0.9999]));
      final r = calc.roll(
        captureRate: 45,
        ball: PokeBallType.poke,
        unaware: false,
        fromBehind: false,
      );
      expect(r.caught, isFalse);
      expect(r.shakes, 1);
    });

    test('over many throws the success rate matches the chance', () {
      final calc = CaptureCalculator(random: Random(42));
      var caught = 0;
      for (var i = 0; i < 4000; i++) {
        final r = calc.roll(
          captureRate: 90,
          ball: PokeBallType.poke,
          unaware: false,
          fromBehind: false,
        );
        if (r.caught) caught++;
        expect(r.shakes, inInclusiveRange(0, 3));
      }
      expect(caught / 4000, closeTo(90 / 255, 0.03));
    });

    test('critical capture: one check, one shake', () {
      // Dado del crítico 0 (< 25 %) y la única comprobación sale bien.
      final ok = CaptureCalculator(random: _SeqRandom([0, 0])).roll(
        captureRate: 45,
        ball: PokeBallType.poke,
        unaware: false,
        fromBehind: false,
        criticalChance: 0.25,
      );
      expect(ok.critical, isTrue);
      expect(ok.caught, isTrue);
      expect(ok.shakes, 1);

      // Crítico, pero la comprobación falla: se escapa sin sacudirse.
      final fail = CaptureCalculator(random: _SeqRandom([0, 0.9999])).roll(
        captureRate: 45,
        ball: PokeBallType.poke,
        unaware: false,
        fromBehind: false,
        criticalChance: 0.25,
      );
      expect(fail.critical, isTrue);
      expect(fail.caught, isFalse);
      expect(fail.shakes, 0);
    });

    test('no critical chance: the critical die is not even rolled', () {
      // Con la misma secuencia que "4 comprobaciones superadas".
      final r = CaptureCalculator(random: _SeqRandom([0])).roll(
        captureRate: 45,
        ball: PokeBallType.poke,
        unaware: false,
        fromBehind: false,
      );
      expect(r.critical, isFalse);
      expect(r.shakes, 3);
    });

    test('critical captures make hard Pokémon much easier', () {
      // Ratio 25 (≈ 10 %): con crítico siempre, la tasa es p^(1/4) ≈ 56 %.
      final calc = CaptureCalculator(random: Random(7));
      var caught = 0;
      for (var i = 0; i < 3000; i++) {
        final r = calc.roll(
          captureRate: 25,
          ball: PokeBallType.poke,
          unaware: false,
          fromBehind: false,
          criticalChance: 1,
        );
        if (r.caught) caught++;
      }
      expect(caught / 3000, closeTo(pow(25 / 255, 0.25), 0.03));
    });

    test('critical chance grows with the species caught, up to 25 %', () {
      expect(CaptureCalculator.criticalChanceFor(0), 0);
      expect(CaptureCalculator.criticalChanceFor(5), closeTo(0.1, 1e-12));
      expect(
        CaptureCalculator.criticalChanceFor(40),
        CaptureCalculator.maxCriticalChance,
      );
    });
  });

  group('TrainerController', () {
    test('starts with 5 Poké Balls selected', () {
      final t = TrainerController();
      expect(t.count(PokeBallType.poke), 5);
      expect(t.totalBalls, 5);
      expect(t.selected, PokeBallType.poke);
    });

    test('takeBall spends the selected ball and falls back to others', () {
      final t = TrainerController(
        startingBag: const {PokeBallType.poke: 1, PokeBallType.ultra: 1},
      );
      expect(t.takeBall(), PokeBallType.poke);
      expect(t.selected, PokeBallType.ultra); // se acabaron las Poké Ball
      expect(t.takeBall(), PokeBallType.ultra);
      expect(t.takeBall(), isNull);
      expect(t.totalBalls, 0);
    });

    test('picking up balls with an empty bag selects them', () {
      final t = TrainerController(startingBag: const {});
      var notified = 0;
      t.addListener(() => notified++);
      t.addBalls(PokeBallType.great, 2);
      expect(t.selected, PokeBallType.great);
      expect(t.count(PokeBallType.great), 2);
      expect(notified, 1);
    });

    test('selectNext skips types with no stock', () {
      final t = TrainerController(
        startingBag: const {PokeBallType.poke: 1, PokeBallType.ultra: 3},
      )..selectNext();
      expect(t.selected, PokeBallType.ultra);
      t.selectNext();
      expect(t.selected, PokeBallType.poke);
    });

    test('captures are listed newest first', () {
      final t = TrainerController()
        ..registerCapture(fakePokemon(1), PokeBallType.poke)
        ..registerCapture(fakePokemon(2), PokeBallType.ultra);
      expect(t.captured.map((c) => c.pokemon.id), [2, 1]);
      expect(t.hasCaught(1), isTrue);
      expect(t.hasCaught(3), isFalse);
      expect(t.speciesCaught, 2);
      t.registerCapture(fakePokemon(1), PokeBallType.great);
      expect(t.speciesCaught, 2, reason: 'same species again');
    });
  });
}
