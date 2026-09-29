// PRUEBAS de las MANADAS: a veces aparecen varios de la misma especie
// juntos, con un guía al que los demás siguen al pasear. Si uno te descubre
// (o se asusta, o se escapa de una bola) avisa a los demás, que te
// descubren uno tras otro; si capturas a uno, los otros miran alrededor.

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
  final meadow = MapLayout.parse(const [
    'TTTTTTTTTTTTTTTTTTTTTTTTTTTT',
    'T@.........""""""""""""""""T',
    'T..........""""""""""""""""T',
    'T..........""""""""""""""""T',
    'T..........""""""""""""""""T',
    'T..........""""""""""""""""T',
    'T..........""""""""""""""""T',
    'T..........""""""""""""""""T',
    'T..........""""""""""""""""T',
    'TTTTTTTTTTTTTTTTTTTTTTTTTTTT',
  ]);

  final open = MapLayout.parse(const [
    'TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT',
    'T..............................T',
    'T..............................T',
    'T..............................T',
    'T..........@...................T',
    'T..............................T',
    'T..............................T',
    'T..............................T',
    'TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT',
  ]);

  void step(World3DSim s, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60);
    }
  }

  group('where herds come from', () {
    test('same species, together, in the tall grass', () {
      final s = World3DSim(layout: meadow, random: Random(5), maxFieldItems: 0);
      final herd = s.spawnHerd(fakePokemon(25), captureRate: 190);
      expect(herd, hasLength(World3DSim.herdSize));
      final leader = herd.first;
      expect(leader.herdId, isNotNull);
      expect(herd.map((w) => w.id).toSet(), hasLength(herd.length));
      for (final w in herd) {
        expect(w.herdId, leader.herdId);
        expect(w.pokemon.id, 25);
        expect(w.captureRate, 190);
        expect(w.hidden, isFalse);
        expect(w.asleep, isFalse);
        expect(s.isTallGrass(w.position), isTrue);
        expect(w.position.distanceTo(leader.position), lessThan(2));
      }
      // Otra manada es otra; uno suelto no tiene manada.
      final other = s.spawnHerd(fakePokemon(16));
      expect(other.first.herdId, isNot(leader.herdId));
      expect(s.spawn(fakePokemon(19))!.herdId, isNull);
    });

    test('some spawns come as a herd, never over the limit', () async {
      var n = 0;
      final s = World3DSim(
        layout: meadow,
        random: Random(2),
        maxFieldItems: 0,
        spawnWild: () async => (pokemon: fakePokemon(++n), captureRate: 45),
      )..herdChance = 1;
      for (var i = 0; i < 30; i++) {
        step(s, 1);
        await pumpEventQueue();
      }
      expect(s.wild.length, lessThanOrEqualTo(World3DSim.maxWild));
      final herds = s.wild.map((w) => w.herdId).whereType<String>().toSet();
      expect(herds, isNotEmpty);
      // Con 6 huecos caben dos manadas de 3.
      expect(herds, hasLength(2));
      expect(World3DSim.defaultHerdChance, 0.2);
    });
  });

  test('the others follow the leader as it wanders', () {
    final s = World3DSim(layout: meadow, random: Random(8), maxFieldItems: 0);
    final herd = s.spawnHerd(fakePokemon(25));
    var worst = 0.0;
    var total = 0.0;
    var samples = 0;
    for (var i = 0; i < 120; i++) {
      step(s, 0.5);
      final leader = herd.first;
      for (final w in herd.skip(1)) {
        expect(w.herdHome, isNotNull);
        final d = w.position.distanceTo(leader.position);
        worst = max(worst, d);
        total += d;
        samples++;
      }
    }
    expect(herd.first.herdHome, isNull, reason: 'the leader leads');
    expect(total / samples, lessThan(5));
    expect(worst, lessThan(11));
  });

  group('the alarm', () {
    /// Guía a 1 m delante del jugador (+X) y dos compañeros a 3 m a los
    /// lados; todos de espaldas al jugador, que está quieto (no le ven ni
    /// le oyen). Un cuarto de la manada, lejos; y uno suelto, al lado.
    (World3DSim, List<World3DEvent>, List<WildPokemon>, WildPokemon)
    herdAround({CaptureCalculator? calculator}) {
      final events = <World3DEvent>[];
      final s = World3DSim(
        layout: open,
        maxFieldItems: 0,
        calculator: calculator,
        onEvent: events.add,
      )..camera.yaw = -pi / 2;
      s.player.facing = pi / 2;
      final me = s.player.position;
      WildPokemon add(String id, Vector3 at, {String? herd = 'h'}) {
        final w = WildPokemon(
          id: id,
          pokemon: fakePokemon(herd == null ? 7 : 25),
          position: me + at,
          facing: pi / 2, // hacia +X: de espaldas al jugador
          temperament: Temperament.curious,
        )..herdId = herd;
        s.wild.add(w);
        return w;
      }

      final herd = [
        add('a', Vector3(1, 0, 0)),
        add('b', Vector3(1, 0, 3)),
        add('c', Vector3(1, 0, -3)),
        add('far', Vector3(19, 0, 0)),
      ];
      final loner = add('loner', Vector3(2, 0, 5), herd: null);
      return (s, events, herd, loner);
    }

    test('one discovers you: the others follow, one after another', () {
      final (s, events, herd, loner) = herdAround();
      final [a, b, c, far] = herd;
      // El guía, pegado a ti, te nota.
      for (var i = 0; i < 60 && !a.isAlert; i++) {
        s.update(1 / 60);
      }
      expect(a.isAlert, isTrue);
      final call = events.whereType<HerdAlerted>().single;
      expect(call.caller, a);
      expect(call.count, 2, reason: 'the far one does not hear it');
      expect(b.isAlert || c.isAlert, isFalse, reason: 'not yet');
      step(s, World3DSim.herdCallDelay + 0.05);
      expect([b.isAlert, c.isAlert].where((x) => x), hasLength(1));
      step(s, World3DSim.herdCallDelay);
      expect(b.isAlert && c.isAlert, isTrue);
      expect(far.isAlert, isFalse);
      expect(loner.isAlert, isFalse, reason: 'not of the herd');
      // Cada uno lo dice con su "!" (y su grito).
      expect(
        events.whereType<PokemonNoticed>().map((e) => e.wild),
        containsAll([a, b, c]),
      );
      expect(events.whereType<HerdAlerted>(), hasLength(1));
    });

    test('one escaping from a ball warns the others', () {
      final (s, events, herd, _) = herdAround(
        calculator: CaptureCalculator(random: _FixedRandom(0.999)),
      );
      final [a, b, c, _] = herd;
      // Que no te note nadie: el guía más lejos, a 5 m.
      a.position = s.player.position + Vector3(5, 0, 0);
      s.aiming = true;
      step(s, 0.1);
      expect(s.lockedTarget, a);
      s.throwBall(PokeBallType.poke);
      s.aiming = false;
      for (
        var i = 0;
        i < 60 * 6 && events.whereType<PokemonBrokeFree>().isEmpty;
        i++
      ) {
        s.update(1 / 60);
      }
      expect(events.whereType<PokemonBrokeFree>(), hasLength(1));
      expect(events.whereType<HerdAlerted>().single.caller, a);
      step(s, 2 * World3DSim.herdCallDelay + 0.05);
      expect(b.isAlert && c.isAlert, isTrue);
    });

    test('catching one makes the others look around, not flee', () {
      final (s, events, herd, _) = herdAround(
        calculator: CaptureCalculator(random: _FixedRandom(0)),
      );
      final [a, b, c, _] = herd;
      a.position = s.player.position + Vector3(5, 0, 0);
      s.aiming = true;
      step(s, 0.1);
      s.throwBall(PokeBallType.poke);
      s.aiming = false;
      for (
        var i = 0;
        i < 60 * 8 && events.whereType<PokemonCaught>().isEmpty;
        i++
      ) {
        s.update(1 / 60);
      }
      expect(events.whereType<PokemonCaught>().single.wild, a);
      expect(events.whereType<HerdAlerted>(), isEmpty);
      for (final w in [b, c]) {
        expect(w.isSuspicious, isTrue);
        expect(w.isAlert, isFalse);
      }
      // Ahora guía otro de la manada.
      step(s, 0.1);
      expect(b.herdHome, isNull);
      expect(c.herdHome, isNotNull);
    });
  });
}
