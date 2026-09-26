// PRUEBAS de los EVENTOS de lanzar (los que usan los sonidos): la mano
// suelta la bola o la baya (ItemThrown), la bola golpea (BallHit, una vez y
// con la calidad del tiro), cada sacudida se cuenta (BallShook 1, 2, 3) antes
// del resultado, y un Pokémon que te descubre lo avisa (PokemonNoticed).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/capture/capture_calculator.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

/// Random fijo: 0 = todas las comprobaciones de captura salen bien.
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
  final open = MapLayout.parse(const [
    'TTTTTTTTTTTTTTTTTTTTTTTT',
    'T......................T',
    'T......................T',
    'T..@...................T',
    'T......................T',
    'T......................T',
    'TTTTTTTTTTTTTTTTTTTTTTTT',
  ]);

  /// Cámara hacia +X y un Pokémon quieto 8 m delante, de espaldas.
  (World3DSim, WildPokemon, List<World3DEvent>) world({double roll = 0}) {
    final events = <World3DEvent>[];
    final s = World3DSim(
      layout: open,
      maxFieldItems: 0,
      calculator: CaptureCalculator(random: _FixedRandom(roll)),
      onEvent: events.add,
    )..camera.yaw = -pi / 2;
    final w = WildPokemon(
      id: 'w',
      pokemon: fakePokemon(25),
      position: s.player.position + Vector3(8, 0, 0),
      temperament: Temperament.curious,
      facing: pi / 2,
    )..idleTime = 1e9;
    s.wild.add(w);
    return (s, w, events);
  }

  void step(World3DSim s, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60);
    }
  }

  test('throw → hit → shake 1, 2, 3 → caught, in that order', () {
    final (s, w, events) = world();
    step(s, 0.1);
    s.throwBall(PokeBallType.great);
    step(s, World3DSim.releaseTime - 0.05);
    expect(events.whereType<ItemThrown>(), isEmpty, reason: 'still in hand');
    step(s, 8);
    final kinds = [
      for (final e in events)
        switch (e) {
          ItemThrown(:final ball) => 'throw $ball',
          BallHit(:final wild, :final quality) => 'hit ${wild.id} $quality',
          BallShook(:final count, :final critical) => 'shake $count $critical',
          PokemonCaught() => 'caught',
          _ => null,
        },
    ].nonNulls;
    expect(kinds, [
      'throw ${PokeBallType.great}',
      'hit ${w.id} ${ThrowQuality.none}',
      'shake 1 false',
      'shake 2 false',
      'shake 3 false',
      'caught',
    ]);
  });

  test('a critical capture: one shake, marked critical', () {
    final (s, _, events) = world();
    s.ballSystem.criticalChance = 1;
    step(s, 0.1);
    s.throwBall(PokeBallType.poke);
    step(s, 8);
    final shakes = events.whereType<BallShook>().toList();
    expect(shakes, hasLength(1));
    expect(shakes.single.critical, isTrue);
  });

  test('every check fails: no shakes, then the escape', () {
    final (s, _, events) = world(roll: 0.999);
    step(s, 0.1);
    s.throwBall(PokeBallType.poke);
    step(s, 8);
    expect(events.whereType<BallShook>(), isEmpty);
    expect(events.whereType<PokemonBrokeFree>(), hasLength(1));
  });

  test('a berry thrown says so (no ball)', () {
    final (s, _, events) = world();
    s.berryReady = true;
    step(s, 0.1);
    s.throwBerry();
    step(s, World3DSim.releaseTime + 0.05);
    expect(events.whereType<ItemThrown>().single.ball, isNull);
  });

  test('a Pokémon that spots you says so, once', () {
    final (s, w, events) = world();
    w.facing = -pi / 2; // mirando al jugador
    step(s, 2);
    expect(w.isAlert, isTrue);
    expect(events.whereType<PokemonNoticed>().map((e) => e.wild), [w]);
  });
}
