// PRUEBAS de los Pokémon DORMIDOS ("Zzz"): no se mueven ni ven; solo les
// desvela oírte cerca (andando o corriendo; agachado, casi nunca) y les
// despierta de golpe que les toques o una bola que cae al lado. Despertados
// por ti te descubren ("!") y, tras espabilarse un momento, reaccionan según
// su carácter; si nadie les molesta, se despiertan solos y tranquilos.
// Dormido da ×2 al capturar, la mira solo lo fija de cerca y el minimapa lo
// marca aparte.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/capture/capture_calculator.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/aiming.dart';
import 'package:pokemon_game/game3d/sim/minimap.dart';
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
    'T..........@...........T',
    'T......................T',
    'T......................T',
    'TTTTTTTTTTTTTTTTTTTTTTTT',
  ]);

  final meadow = MapLayout.parse(const [
    'TTTTTTTTTTTTTTTTTTTTTTTT',
    'T@.......""""""""""""""T',
    'T........""""""""""""""T',
    'T........""""""""""""""T',
    'T........""""""""""""""T',
    'T........""""""""""""""T',
    'TTTTTTTTTTTTTTTTTTTTTTTT',
  ]);

  /// Mundo abierto con la cámara hacia +X (adelante = +X). Las bolas nunca
  /// capturan (así se ve qué pasa después).
  (World3DSim, List<World3DEvent>) world() {
    final events = <World3DEvent>[];
    final s = World3DSim(
      layout: open,
      maxFieldItems: 0,
      calculator: CaptureCalculator(random: _FixedRandom(0.999)),
      onEvent: events.add,
    )..camera.yaw = -pi / 2;
    s.player.facing = pi / 2; // mirando hacia +X
    return (s, events);
  }

  /// Uno dormido a [distance] m delante del jugador (+X), mirando hacia
  /// [facing] (por defecto, hacia el jugador).
  WildPokemon sleeper(
    World3DSim s, {
    double distance = 5,
    double facing = -pi / 2,
    Temperament temperament = Temperament.skittish,
    int captureRate = 45,
  }) {
    final w = WildPokemon(
      id: 'z',
      pokemon: fakePokemon(143),
      position: s.player.position + Vector3(distance, 0, 0),
      facing: facing,
      temperament: temperament,
      captureRate: captureRate,
    )..asleep = true;
    s.wild.add(w);
    return w;
  }

  void step(World3DSim s, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60);
    }
  }

  group('who sleeps', () {
    Future<World3DSim> spawnSome(double sleepChance) async {
      var n = 0;
      final s = World3DSim(
        layout: meadow,
        random: Random(3),
        maxFieldItems: 0,
        spawnWild: () async => (pokemon: fakePokemon(++n), captureRate: 45),
      )..sleepChance = sleepChance;
      for (var i = 0; i < 20 && s.wild.length < World3DSim.maxWild; i++) {
        step(s, 1);
        await pumpEventQueue();
      }
      return s;
    }

    test('some of the visible ones; never the hidden ones', () async {
      expect(World3DSim.defaultSleepChance, 0.2);
      final sleepy = await spawnSome(1);
      for (final w in sleepy.wild) {
        expect(w.asleep, !w.hidden, reason: 'hidden ones are awake');
      }
      expect(sleepy.wild.where((w) => w.asleep), isNotEmpty);
      final awake = await spawnSome(0);
      expect(awake.wild.any((w) => w.asleep), isFalse);
    });

    test('spawn() can put one to sleep, but not a hidden one', () {
      final s = World3DSim(layout: meadow, maxFieldItems: 0);
      expect(s.spawn(fakePokemon(1), asleep: true)!.asleep, isTrue);
      expect(
        s.spawn(fakePokemon(2), asleep: true, hidden: true)!.asleep,
        isFalse,
      );
      expect(s.spawn(fakePokemon(3))!.asleep, isFalse);
    });
  });

  group('what a sleeper notices', () {
    final behavior = WildBehavior(
      random: Random(1),
      isWalkable: (_) => true,
      isTallGrass: (_) => false,
      nearbyGrass: (_, _) => null,
    );

    /// Segundos hasta que se despierta con el jugador a [d] m (null si en
    /// [limit] s no se despierta).
    double? wakesAfter(
      double d,
      PlayerStealth stealth, {
      bool moving = true,
      double limit = 10,
    }) {
      final w = WildPokemon(
        id: 'z',
        pokemon: fakePokemon(1),
        position: Vector3.zero(),
      )..asleep = true;
      for (var t = 0.0; t < limit; t += 1 / 60) {
        final woke = behavior.perceiveAsleep(
          w,
          player: Vector3(d, 0, 0),
          stealth: stealth,
          moving: moving,
          dt: 1 / 60,
        );
        if (woke) return t;
      }
      return null;
    }

    test('it does not see you, even right in front', () {
      // De pie, quieto, a 5 m y a la vista: despierto te descubriría.
      expect(wakesAfter(5, PlayerStealth.normal, moving: false), isNull);
    });

    test('walking or running near wakes it; farther away, it sleeps on', () {
      expect(wakesAfter(3, PlayerStealth.normal), lessThan(2));
      expect(wakesAfter(6, PlayerStealth.normal), isNull);
      expect(wakesAfter(9, PlayerStealth.noisy), lessThan(4));
      expect(wakesAfter(12, PlayerStealth.noisy), isNull);
    });

    test('crouching you can get right next to it', () {
      expect(wakesAfter(1.5, PlayerStealth.crouching), isNull);
      expect(wakesAfter(1.5, PlayerStealth.hidden), isNull);
    });

    test('touching it wakes it at once', () {
      expect(wakesAfter(1, PlayerStealth.hidden, moving: false), 0);
    });

    test('noise makes it stir; silence settles it again', () {
      final w = WildPokemon(
        id: 'z',
        pokemon: fakePokemon(1),
        position: Vector3.zero(),
      )..asleep = true;
      for (var i = 0; i < 40; i++) {
        behavior.perceiveAsleep(
          w,
          player: Vector3(4, 0, 0),
          stealth: PlayerStealth.normal,
          moving: true,
          dt: 1 / 60,
        );
      }
      expect(w.isStirring, isTrue);
      expect(w.isSuspicious, isFalse, reason: 'no "?" while asleep');
      for (var i = 0; i < 60 * 5; i++) {
        behavior.perceiveAsleep(
          w,
          player: Vector3(4, 0, 0),
          stealth: PlayerStealth.normal,
          moving: false,
          dt: 1 / 60,
        );
      }
      expect(w.isStirring, isFalse);
      expect(w.awareness, 0);
    });
  });

  group('asleep in the world', () {
    test('it stays put and does not wander off', () {
      final (s, _) = world();
      final w = sleeper(s);
      final at = w.position;
      step(s, 5);
      expect(w.asleep, isTrue);
      expect(w.position, at);
      expect(w.isAlert, isFalse);
    });

    test('woken by you: "!", a moment to wake up, then it reacts', () {
      final (s, events) = world();
      final w = sleeper(s, facing: pi / 2); // de espaldas a ti
      // Tropiezas con él.
      s.player.teleport(w.position - Vector3(1, 0, 0));
      s.update(1 / 60);
      final woke = events.whereType<PokemonWoke>().single;
      expect(woke.wild, w);
      expect(woke.startled, isTrue);
      expect(w.asleep, isFalse);
      expect(w.isAlert, isTrue);
      expect(w.isWaking, isTrue);
      final at = w.position;
      step(s, WildPokemon.wakeSeconds * 0.9);
      expect(w.position, at, reason: 'still waking up');
      expect(
        w.facingDirection.x,
        closeTo(-1, 0.02),
        reason: 'it turned to you',
      );
      // Espabilado, el asustadizo huye.
      step(s, 1);
      expect(w.isWaking, isFalse);
      expect(
        w.position.distanceTo(s.player.position),
        greaterThan(at.distanceTo(s.player.position) + 1),
      );
    });

    test('left alone long enough, it wakes up by itself, calm', () {
      final (s, events) = world();
      final w = sleeper(s, distance: 12)
        ..sleptFor = World3DSim.sleepLifetime - 0.05;
      step(s, 0.1);
      expect(events.whereType<PokemonWoke>().single.startled, isFalse);
      expect(w.asleep, isFalse);
      expect(w.isAlert, isFalse);
    });

    test('a ball landing next to it wakes it up', () {
      final (s, events) = world();
      final w = sleeper(s, distance: 8);
      // Un tiro a ojo, corto: cae delante de él.
      s.camera.pitch = 0.9;
      s.throwBall(PokeBallType.poke);
      for (var i = 0; i < 180 && w.asleep; i++) {
        s.update(1 / 60);
      }
      expect(s.balls.every((b) => b.hit == null), isTrue, reason: 'a miss');
      expect(events.whereType<PokemonWoke>().single.startled, isTrue);
    });
  });

  group('catching a sleeper', () {
    test('the sight only locks on from close', () {
      final (s, _) = world();
      final w = sleeper(s, distance: 12);
      WildPokemon? lock() => findLockTarget(
        player: s.player.position,
        forward: Vector3(1, 0, 0),
        wild: s.wild,
      );
      expect(lock(), isNull, reason: 'lying in the grass, too far');
      w.asleep = false;
      expect(lock(), w, reason: 'awake it would be locked');
      w
        ..asleep = true
        ..position = s.player.position + Vector3(sleepLockDistance - 1, 0, 0);
      expect(lock(), w);
    });

    test('×2 on top of stealth, "asleep" in the hit, and it wakes up', () {
      final (s, events) = world();
      // De espaldas, ratio 51: 0,2 × 2 (espalda) × 2 (dormido) = 0,8.
      final w = sleeper(s, facing: pi / 2, captureRate: 51);
      s.aiming = true;
      step(s, 0.1);
      expect(s.lockedTarget, w);
      expect(s.lockedChance, closeTo(0.8, 1e-9));
      s.throwBall(PokeBallType.poke);
      for (
        var i = 0;
        i < 120 && (s.balls.isEmpty || s.balls.single.hit == null);
        i++
      ) {
        s.update(1 / 60);
      }
      expect(s.balls.single.hit, (
        unaware: true,
        fromBehind: true,
        eating: false,
        asleep: true,
      ));
      expect(w.asleep, isFalse);
      s.aiming = false;
      for (
        var i = 0;
        i < 60 * 6 && events.whereType<PokemonBrokeFree>().isEmpty;
        i++
      ) {
        s.update(1 / 60);
      }
      expect(
        events.whereType<PokemonBrokeFree>().single.result.chance,
        closeTo(0.8, 1e-9),
      );
      // Sale de la bola bien despierto (y alerta), no dormido.
      expect(w.asleep, isFalse);
      expect(w.isAlert, isTrue);
    });

    test('the calculator: ×2 when asleep', () {
      double chance({required bool asleep}) => CaptureCalculator.chance(
        captureRate: 30,
        ball: PokeBallType.poke,
        unaware: true,
        fromBehind: false,
        asleep: asleep,
      );
      expect(
        chance(asleep: true),
        closeTo(chance(asleep: false) * CaptureCalculator.sleepBonus, 1e-12),
      );
      expect(CaptureCalculator.sleepBonus, 2);
    });
  });

  test('the minimap marks sleepers apart', () {
    final w = WildPokemon(
      id: 'z',
      pokemon: fakePokemon(1),
      position: Vector3.zero(),
    )..asleep = true;
    expect(MinimapMark.forWild(w), MinimapMark.asleep);
    w.awareness = 0.6;
    expect(MinimapMark.forWild(w), MinimapMark.asleep, reason: 'stirring');
    w.asleep = false;
    expect(MinimapMark.forWild(w), MinimapMark.suspicious);
  });
}
