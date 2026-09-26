// PRUEBAS de la VOLTERETA: un impulso rápido de ~3 m hacia donde te
// mueves (o hacia donde miras), que choca con las paredes, te levanta si
// ibas agachado, hace ruido y no deja apuntar ni lanzar mientras dura; hay
// que esperar un poco para dar otra. Un Pokémon que te embiste de cerca se
// pasa de largo y queda ATURDIDO (quieto, sin verte: la ocasión de lanzarle
// una bola); rodando, ninguno te alcanza. Y la postura: una vuelta entera.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/capture/capture_calculator.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/trainer_pose.dart';
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

  /// Mundo abierto con la cámara hacia +X (adelante = +X).
  (World3DSim, List<World3DEvent>, List<WildPokemon>) world() {
    final events = <World3DEvent>[];
    final contacts = <WildPokemon>[];
    final s = World3DSim(
      layout: open,
      maxFieldItems: 0,
      calculator: CaptureCalculator(random: _FixedRandom(0.999)),
      dodgeRandom: _FixedRandom(0.999),
      onEvent: events.add,
      onWildContact: contacts.add,
    )..camera.yaw = -pi / 2;
    s.player.facing = pi / 2; // mirando hacia +X
    return (s, events, contacts);
  }

  void step(World3DSim s, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60);
    }
  }

  test('it rolls ~3 m towards where you move, then you walk again', () {
    final (s, events, _) = world();
    final start = s.player.position;
    s.input.setKeyboardDirection(Vector2(-1, 0)); // izquierda = -Z aquí
    expect(s.roll(), isTrue);
    expect(s.isRolling, isTrue);
    expect(events.whereType<PlayerRolled>(), hasLength(1));
    step(s, World3DSim.rollTime);
    expect(s.isRolling, isFalse);
    final moved = s.player.position - start;
    expect(moved.z, closeTo(-World3DSim.rollDistance, 0.25));
    expect(moved.x.abs(), lessThan(0.1));
  });

  test('standing still, it rolls the way you face', () {
    final (s, _, _) = world();
    final start = s.player.position;
    s.roll();
    step(s, World3DSim.rollTime + 0.05);
    expect(s.player.position.x - start.x, greaterThan(2.8));
  });

  test('one at a time, with a short wait, never paused or mid-throw', () {
    final (s, _, _) = world();
    expect(s.roll(), isTrue);
    expect(s.roll(), isFalse, reason: 'already rolling');
    step(s, World3DSim.rollTime + 0.05);
    expect(s.roll(), isFalse, reason: 'catching your breath');
    step(s, World3DSim.rollCooldown);
    expect(s.roll(), isTrue);
    step(s, 1);

    s.setPaused(true);
    expect(s.roll(), isFalse);
    s.setPaused(false);
    s.throwBall(PokeBallType.poke);
    expect(s.roll(), isFalse, reason: 'mid-throw');
  });

  test('it stands you up, makes noise, and blocks aiming and throwing', () {
    final (s, _, _) = world();
    s
      ..crouching = true
      ..aiming = true;
    step(s, 0.2);
    expect(s.isAiming, isTrue);
    s.roll();
    step(s, 0.1);
    expect(s.crouching, isFalse);
    expect(s.stealth, PlayerStealth.noisy);
    expect(s.isAiming, isFalse);
    expect(s.canThrow, isFalse);
    expect(s.rollProgress, inExclusiveRange(0, 1));
    step(s, World3DSim.rollTime);
    expect(s.isAiming, isTrue, reason: 'still holding aim');
  });

  test('walls stop it', () {
    final (s, _, _) = world();
    // A 1 m del bosque del este (empieza en x = 46).
    s.player.teleport(s.cellCenter(22, 3));
    s.roll();
    step(s, World3DSim.rollTime);
    expect(s.player.position.x, lessThan(46));
    expect(s.isRolling, isFalse);
  });

  group('a charger that is close', () {
    /// Uno agresivo, alerta, 3 m delante y viniendo hacia ti.
    WildPokemon charger(World3DSim s, {double distance = 3}) {
      final w = WildPokemon(
        id: 'c',
        pokemon: fakePokemon(25),
        position: s.player.position + Vector3(distance, 0, 0),
        temperament: Temperament.aggressive,
        facing: -pi / 2,
      )..alertTime = 30;
      s.wild.add(w);
      return w;
    }

    test('overshoots where you were and is dazed, unaware of you', () {
      final (s, events, contacts) = world();
      final w = charger(s);
      s.input.setKeyboardDirection(Vector2(-1, 0)); // a un lado (-Z)
      s.roll();
      expect(w.overshootTo, isNotNull);
      final passTo = w.overshootTo!;
      expect(passTo.x, lessThan(s.player.position.x - 1), reason: 'past you');
      s.input.setKeyboardDirection(Vector2.zero());
      step(s, 2);
      expect(contacts, isEmpty);
      expect(events.whereType<PokemonDazed>().single.wild, w);
      expect(w.isDazed, isTrue);
      expect(w.isAlert, isFalse, reason: 'counts as not having seen you');
      final at = w.position;
      step(s, 0.3);
      expect(w.position, at, reason: 'it does not move');
      // Vuelve en sí, mosqueado.
      step(s, WildPokemon.dazeSeconds);
      expect(w.isDazed, isFalse);
      expect(w.awareness, greaterThan(0.5));
    });

    test('a ball while it is dazed counts as not seen', () {
      final (s, _, _) = world();
      final w = charger(s);
      s.input.setKeyboardDirection(Vector2(-1, 0));
      s.roll();
      s.input.setKeyboardDirection(Vector2.zero());
      for (var i = 0; i < 180 && !w.isDazed; i++) {
        s.update(1 / 60);
      }
      expect(w.isDazed, isTrue);
      // Se pasó de largo: está detrás. Girarse hacia él y apuntar.
      final to = w.position - s.player.position;
      s.camera.yaw = atan2(-to.x, -to.z);
      s.aiming = true;
      step(s, 0.1);
      expect(s.lockedTarget, w);
      s.throwBall(PokeBallType.poke);
      for (
        var i = 0;
        i < 120 && (s.balls.isEmpty || s.balls.first.hit == null);
        i++
      ) {
        s.update(1 / 60);
      }
      expect(s.balls.first.hit?.unaware, isTrue);
    });

    test('far away it just keeps charging', () {
      final (s, _, _) = world();
      final w = charger(s, distance: 8);
      s.roll();
      expect(w.overshootTo, isNull);
    });

    test('while you roll, contact dazes it instead of starting a battle', () {
      final (s, events, contacts) = world();
      // Te alcanza por detrás justo cuando ruedas (no estaba en el radio al
      // empezar: llega durante la voltereta).
      final w = charger(s, distance: 5)..facing = -pi / 2;
      s.input.setKeyboardDirection(Vector2(0, -1)); // hacia él (+X)
      s.roll();
      expect(w.overshootTo, isNull, reason: 'out of range at the start');
      step(s, World3DSim.rollTime);
      expect(contacts, isEmpty);
      expect(events.whereType<PokemonDazed>(), hasLength(1));
    });
  });

  test('the camera breathes: back when running, close when crouching', () {
    final (s, _, _) = world();
    s
      ..cameraInput.running = true
      ..input.setKeyboardDirection(Vector2(0, -1));
    step(s, 1.5);
    expect(s.camera.stance, greaterThan(0.9));
    s
      ..cameraInput.running = false
      ..input.setKeyboardDirection(Vector2.zero());
    step(s, 2);
    expect(s.camera.stance.abs(), lessThan(0.05));
    s.crouching = true;
    step(s, 2);
    expect(s.camera.stance, lessThan(-0.95));
  });

  test('the pose: a whole turn, off the ground in the middle', () {
    TrainerPose pose(double p) => TrainerPose.fromMotion(
      distanceWalked: 3,
      speed: 6,
      walkSpeed: 4.5,
      runSpeed: 7.5,
      rollProgress: p,
    );
    expect(pose(0).rollAngle, 0);
    expect(pose(1).rollAngle, closeTo(2 * pi, 1e-9));
    expect(pose(0.5).rollAngle, closeTo(pi, 1e-9));
    expect(pose(0.5).rollLift, greaterThan(0.4));
    expect(pose(1).rollLift, closeTo(0, 1e-9));
    expect(pose(0.5).crouch, 1, reason: 'tucked');
    final walking = TrainerPose.fromMotion(
      distanceWalked: 3,
      speed: 4.5,
      walkSpeed: 4.5,
      runSpeed: 7.5,
    );
    expect(walking.roll, 0);
    expect(walking.rollAngle, 0);
  });
}
