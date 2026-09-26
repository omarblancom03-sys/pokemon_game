// PRUEBAS de la HUIDA en el Reto Safari: un Pokémon que se escapa de la
// bola puede huir para siempre (más si es raro; la mitad si le diste
// mientras comía). El que huye, tras el "pop", corre lejos del jugador sea
// cual sea su carácter, no se para por nada ni dispara encuentros, y
// desaparece. Fuera del reto nadie huye.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/capture/capture_calculator.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
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
    'TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT',
    'T......................................T',
    'T......................................T',
    'T..@...................................T',
    'T......................................T',
    'T......................................T',
    'TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT',
  ]);

  /// Cámara hacia +X y un Pokémon AGRESIVO quieto 8 m delante, de
  /// espaldas. Todas las comprobaciones de captura fallan; [flee] es el
  /// dado de la huida.
  (World3DSim, WildPokemon, List<World3DEvent>) world({
    required double flee,
    bool safari = true,
  }) {
    final events = <World3DEvent>[];
    final s = World3DSim(
      layout: open,
      maxFieldItems: 0,
      calculator: CaptureCalculator(random: _FixedRandom(0.999)),
      fleeRandom: _FixedRandom(flee),
      onEvent: events.add,
    )..camera.yaw = -pi / 2;
    final w = WildPokemon(
      id: 'w',
      pokemon: fakePokemon(25),
      position: s.player.position + Vector3(8, 0, 0),
      temperament: Temperament.aggressive,
      facing: pi / 2,
    )..idleTime = 1e9;
    s.wild.add(w);
    if (safari) s.startSafari(600);
    return (s, w, events);
  }

  void step(World3DSim s, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60);
    }
  }

  /// Lanza y avanza justo hasta que se escapa de la bola.
  PokemonBrokeFree throwUntilEscape(World3DSim s, List<World3DEvent> events) {
    step(s, 0.1);
    s.throwBall(PokeBallType.poke);
    for (var t = 0.0; t < 8; t += 1 / 60) {
      s.update(1 / 60);
      final escape = events.whereType<PokemonBrokeFree>().firstOrNull;
      if (escape != null) return escape;
    }
    fail('it never broke free');
  }

  test('the rarer, the likelier to flee; a berry halves it', () {
    expect(World3DSim.safariFleeChance(255), closeTo(0.1, 1e-9));
    expect(World3DSim.safariFleeChance(45), closeTo(0.429, 0.001));
    expect(World3DSim.safariFleeChance(3), closeTo(0.495, 0.001));
    expect(
      World3DSim.safariFleeChance(45, eating: true),
      closeTo(World3DSim.safariFleeChance(45) / 2, 1e-9),
    );
    // Fuera de rango no rompe nada.
    expect(World3DSim.safariFleeChance(0), World3DSim.safariFleeChance(1));
    expect(World3DSim.safariFleeChance(999), World3DSim.safariFleeChance(255));
  });

  test('a bad roll in the challenge: it runs off and is gone', () {
    final (s, w, events) = world(flee: 0);
    expect(throwUntilEscape(s, events).fled, isTrue);
    expect(w.isLeaving, isTrue);
    expect(s.wild, contains(w), reason: 'it still has to run away');

    // Tras el "pop", corre lejos del jugador (aunque sea agresivo: no carga).
    final start = w.position.distanceTo(s.player.position);
    step(s, 2);
    expect(w.position.distanceTo(s.player.position), greaterThan(start + 4));
    expect(w.isAlert, isTrue);
    expect(s.wild, contains(w));
    // Y al rato ya no está.
    step(s, World3DSim.leaveSeconds);
    expect(s.wild, isNot(contains(w)));
  });

  test('a good roll: it only broke free (and stays)', () {
    final (s, w, events) = world(flee: 0.99);
    expect(throwUntilEscape(s, events).fled, isFalse);
    expect(w.isLeaving, isFalse);
    step(s, 10);
    expect(s.wild, contains(w));
  });

  test('outside the challenge nobody flees', () {
    final (s, w, events) = world(flee: 0, safari: false);
    expect(throwUntilEscape(s, events).fled, isFalse);
    expect(w.isLeaving, isFalse);
  });

  test('one that is leaving never starts an encounter', () {
    var contacts = 0;
    final s = World3DSim(
      layout: open,
      maxFieldItems: 0,
      onWildContact: (_) => contacts++,
    );
    final w =
        WildPokemon(
            id: 'w',
            pokemon: fakePokemon(25),
            position: s.player.position + Vector3(0.3, 0, 0),
            temperament: Temperament.aggressive,
          )
          ..alertTime = 5
          ..leavingFor = 0;
    s.wild.add(w);
    step(s, 0.5);
    expect(contacts, 0);
    expect(w.position.distanceTo(s.player.position), greaterThan(1));
  });
}
