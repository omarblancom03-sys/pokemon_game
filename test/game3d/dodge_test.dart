// PRUEBAS de la ESQUIVA: un Pokémon que te vigila (alerta o con "?") y ve
// venir la bola (la mira de frente) puede apartarse de un salto lateral y
// la bola pasa de largo. Depende del carácter (los agresivos nunca) y del
// tiro (con el aro cuesta más; uno "¡Excelente!" no se esquiva). Sin verte,
// huyendo (de espaldas) o comiendo, nunca. Si no cabe, no se aparta.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/capture/capture_calculator.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/aiming.dart';
import 'package:pokemon_game/game3d/sim/wild_behavior.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

/// Random fijo: siempre devuelve [value].
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
  // Un pasillo de una casilla: no cabe a ningún lado.
  final corridor = MapLayout.parse(const [
    'TTTTTTTTTTTTTTTTTTTTTTTT',
    'T..@...................T',
    'TTTTTTTTTTTTTTTTTTTTTTTT',
  ]);

  /// Cámara hacia +X y un Pokémon 8 m delante. [facingPlayer]: te mira
  /// (si no, de espaldas); [alert]: te ha visto (un curioso alerta se te
  /// acerca mirándote). [dodge] es el dado.
  (World3DSim, WildPokemon, List<World3DEvent>) world({
    double dodge = 0,
    bool facingPlayer = true,
    bool alert = true,
    Temperament temperament = Temperament.curious,
    MapLayout? layout,
  }) {
    final events = <World3DEvent>[];
    final s = World3DSim(
      layout: layout ?? open,
      maxFieldItems: 0,
      calculator: CaptureCalculator(random: _FixedRandom(0)),
      dodgeRandom: _FixedRandom(dodge),
      onEvent: events.add,
    )..camera.yaw = -pi / 2;
    final w = WildPokemon(
      id: 'w',
      pokemon: fakePokemon(25),
      position: s.player.position + Vector3(8, 0, 0),
      temperament: temperament,
      facing: facingPlayer ? -pi / 2 : pi / 2,
    )..idleTime = 1e9;
    if (alert) w.alertTime = 1e9; // alerta todo el rato, pero quieto
    s.wild.add(w);
    return (s, w, events);
  }

  void step(World3DSim s, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60);
    }
  }

  /// Lanza una bola directa al Pokémon (sin el gesto: desde la mano, ya).
  void throwAt(
    World3DSim s,
    WildPokemon w, {
    ThrowQuality quality = ThrowQuality.none,
  }) {
    final hand = handPosition(s.player.position, s.player.facing);
    s.ballSystem.launch(
      PokeBallType.poke,
      hand,
      lockedThrowVelocity(hand, w)!,
      quality: quality,
    );
  }

  test('the chance depends on temperament and on the ring', () {
    expect(
      WildBehavior.dodgeChance(Temperament.skittish, ThrowQuality.none),
      0.4,
    );
    expect(
      WildBehavior.dodgeChance(Temperament.curious, ThrowQuality.none),
      0.2,
    );
    expect(
      WildBehavior.dodgeChance(Temperament.aggressive, ThrowQuality.none),
      0,
    );
    expect(
      WildBehavior.dodgeChance(Temperament.skittish, ThrowQuality.great),
      closeTo(0.16, 1e-9),
    );
    expect(
      WildBehavior.dodgeChance(Temperament.skittish, ThrowQuality.excellent),
      0,
    );
  });

  test('alert and facing the ball: it hops aside and the ball misses', () {
    final (s, w, events) = world();
    throwAt(s, w);
    for (var i = 0; i < 120 && events.whereType<PokemonDodged>().isEmpty; i++) {
      s.update(1 / 60);
    }
    expect(events.whereType<PokemonDodged>().single.wild, w);
    final start = w.dodgeFrom;
    step(s, WildPokemon.dodgeTime);
    expect(w.isDodging, isFalse, reason: 'it has landed');
    // Se apartó hacia un lado (no hacia atrás ni hacia delante).
    final moved = w.position - start;
    expect(moved.z.abs(), closeTo(WildPokemon.dodgeDistance, 0.1));
    expect(moved.x.abs(), lessThan(0.1));
    expect(w.isAlert, isTrue);
    step(s, 3);
    expect(events.whereType<BallHit>(), isEmpty);
    expect(events.whereType<BallMissed>(), hasLength(1));
  });

  test('the hop is quick and has a little jump', () {
    final (s, w, events) = world();
    throwAt(s, w);
    for (var i = 0; i < 120 && events.whereType<PokemonDodged>().isEmpty; i++) {
      s.update(1 / 60);
    }
    expect(events.whereType<PokemonDodged>(), hasLength(1));
    s.update(WildPokemon.dodgeTime / 2);
    expect(w.dodgeJump, greaterThan(0.3));
    expect(
      (w.position - w.dodgeFrom).length,
      greaterThan(WildPokemon.dodgeDistance * 0.6),
      reason: 'most of the way in half the time',
    );
  });

  test('a good roll for you: it does not dodge and gets hit', () {
    final (s, w, events) = world(dodge: 0.99);
    throwAt(s, w);
    step(s, 1.5);
    expect(events.whereType<PokemonDodged>(), isEmpty);
    expect(events.whereType<BallHit>(), hasLength(1));
  });

  test('never if it has not seen you, runs away (its back to you) or is '
      'aggressive', () {
    for (final (alert, facing, temperament) in [
      (false, false, Temperament.curious),
      (true, true, Temperament.skittish), // se da la vuelta y huye
      (true, true, Temperament.aggressive),
    ]) {
      final (s, w, events) = world(
        alert: alert,
        facingPlayer: facing,
        temperament: temperament,
      );
      // El agresivo alerta carga: que no llegue a tocarte en la prueba.
      if (temperament == Temperament.aggressive) w.alertTime = 0.2;
      throwAt(s, w);
      step(s, 1.5);
      expect(events.whereType<PokemonDodged>(), isEmpty);
    }
  });

  test('a suspicious one ("?") watching you can dodge too', () {
    final (s, w, events) = world(alert: false);
    w.awareness = 0.5; // "?": se para y te mira
    s.crouching = true; // agachado cuesta más que te descubra del todo
    throwAt(s, w);
    step(s, 1.5);
    expect(events.whereType<PokemonDodged>(), hasLength(1));
  });

  test('an excellent throw cannot be dodged', () {
    final (s, w, events) = world();
    throwAt(s, w, quality: ThrowQuality.excellent);
    step(s, 1.5);
    expect(events.whereType<PokemonDodged>(), isEmpty);
    expect(events.whereType<BallHit>(), hasLength(1));
  });

  test('with no room on either side it stays put', () {
    final (s, w, events) = world(layout: corridor);
    throwAt(s, w);
    step(s, 1.5);
    expect(events.whereType<PokemonDodged>(), isEmpty);
    expect(events.whereType<BallHit>(), hasLength(1));
  });
}
