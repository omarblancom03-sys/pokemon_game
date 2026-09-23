// PRUEBAS del comportamiento y el sigilo: los Pokémon ven en un cono y oyen
// según el ruido del jugador (correr se oye de lejos; agachado en la hierba
// alta casi no se ve ni se oye); al descubrirte, los asustadizos huyen (y se
// pierden), los curiosos se acercan y se quedan mirando, y los agresivos
// cargan. Agacharse y correr cambian lo que se nota el jugador.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/wild_behavior.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

void main() {
  // Campo abierto a la izquierda, hierba alta a la derecha (30 x 14 m).
  final layout = MapLayout.parse(
    const [
      'TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT',
      'T.........""""""""""""""""""""""T',
      'T.........""""""""""""""""""""""T',
      'T..@......""""""""""""""""""""""T',
      'T.........""""""""""""""""""""""T',
      'T.........""""""""""""""""""""""T',
      'TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT',
    ].map((r) => r.substring(0, 32)).toList(),
  );

  World3DSim world() =>
      World3DSim(layout: layout, random: Random(3), maxFieldItems: 0);

  /// Pokémon en [at] mirando hacia [facing] (0 = +Z; pi/2 = +X).
  WildPokemon addWild(
    World3DSim s,
    Vector3 at, {
    Temperament temperament = Temperament.skittish,
    double facing = -pi / 2,
  }) {
    final w = WildPokemon(
      id: 'w${s.wild.length}',
      pokemon: fakePokemon(1),
      position: at,
      temperament: temperament,
      facing: facing,
    )..idleTime = 1e9; // no pasea por su cuenta
    s.wild.add(w);
    return w;
  }

  void step(World3DSim s, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60);
    }
  }

  group('senses', () {
    final w = WildPokemon(
      id: 'w',
      pokemon: fakePokemon(1),
      position: Vector3.zero(),
      facing: pi / 2, // mira hacia +X
    );

    test('sees in a cone in front, not behind; always when touching', () {
      expect(
        WildBehavior.sees(w, Vector3(8, 0, 1), PlayerStealth.normal),
        isTrue,
      );
      expect(
        WildBehavior.sees(w, Vector3(-8, 0, 0), PlayerStealth.normal),
        isFalse,
      );
      expect(
        WildBehavior.sees(w, Vector3(1, 0, 8), PlayerStealth.normal),
        isFalse,
        reason: 'outside the ±60° cone',
      );
      expect(
        WildBehavior.sees(w, Vector3(-1, 0, 0), PlayerStealth.hidden),
        isTrue,
      );
    });

    test('crouching in tall grass hides you except very close', () {
      expect(
        WildBehavior.sees(w, Vector3(6, 0, 0), PlayerStealth.hidden),
        isFalse,
      );
      expect(
        WildBehavior.sees(w, Vector3(6, 0, 0), PlayerStealth.crouching),
        isTrue,
      );
      expect(
        WildBehavior.sees(w, Vector3(2, 0, 0), PlayerStealth.hidden),
        isTrue,
      );
    });

    test('running is heard far away; standing still makes no noise', () {
      double noise(PlayerStealth s) => WildBehavior.noiseFor(s, moving: true);
      expect(
        noise(PlayerStealth.noisy),
        greaterThan(noise(PlayerStealth.normal)),
      );
      expect(
        noise(PlayerStealth.normal),
        greaterThan(noise(PlayerStealth.crouching)),
      );
      expect(
        noise(PlayerStealth.crouching),
        greaterThan(noise(PlayerStealth.hidden)),
      );
      expect(WildBehavior.noiseFor(PlayerStealth.noisy, moving: false), 0);
    });
  });

  group('awareness', () {
    test('walking in front: "?" first, then "!" in about a second', () {
      final s = world();
      final w = addWild(s, s.player.position + Vector3(8, 0, 0));
      s.input.setKeyboardDirection(Vector2(0, -1)); // anda (de lado para él)
      s.camera.yaw = 0;
      s.update(0.3);
      expect(w.isSuspicious, isTrue);
      expect(w.isAlert, isFalse);
      step(s, 1);
      expect(w.isAlert, isTrue);
    });

    test('standing still behind it: never noticed', () {
      final s = world();
      final w = addWild(
        s,
        s.player.position + Vector3(5, 0, 0),
        facing: pi / 2, // de espaldas al jugador
      );
      step(s, 5);
      expect(w.awareness, 0);
      expect(w.isAlert, isFalse);
    });

    test('running behind it is heard', () {
      final s = world();
      final w = addWild(
        s,
        s.player.position + Vector3(0, 0, -4),
        facing: pi, // mira hacia -Z: el jugador queda a su espalda
      );
      s
        ..camera.yaw =
            -pi /
            2 // adelante = +X
        ..cameraInput.running = true
        ..input.setKeyboardDirection(Vector2(0, -1));
      step(s, 0.5);
      expect(s.stealth, PlayerStealth.noisy);
      step(s, 1.2);
      expect(w.isAlert, isTrue);
    });

    test('crouching in tall grass you can sneak up behind it', () {
      final s = world();
      s.player.teleport(s.cellCenter(12, 3));
      final w = addWild(
        s,
        s.player.position + Vector3(6, 0, 0),
        facing: pi / 2, // de espaldas
        temperament: Temperament.curious,
      );
      s
        ..crouching = true
        ..camera.yaw =
            -pi /
            2 // adelante = +X
        ..input.setKeyboardDirection(Vector2(0, -1));
      expect(s.stealth, PlayerStealth.hidden);
      step(s, 1.5); // ~3 m a velocidad de agachado
      s.input.setKeyboardDirection(Vector2.zero());
      step(s, 0.5);
      expect(w.position.distanceTo(s.player.position), lessThan(3.5));
      expect(w.isAlert, isFalse);
      expect(s.crouchAmount, greaterThan(0.9));
    });

    test('after calming down it stays wary for a while', () {
      final s = world();
      final w = addWild(
        s,
        s.player.position + Vector3(12, 0, 0),
        facing: pi / 2, // huye mirando hacia allá: no vuelve a verte
      )..alertTime = 0.1;
      w.awareness = 1;
      step(s, 0.3);
      expect(w.isAlert, isFalse);
      expect(w.awareness, closeTo(0.6, 0.1));
    });
  });

  group('reactions', () {
    test('skittish ones flee and get lost far away', () {
      final s = world();
      final w = addWild(s, s.player.position + Vector3(6, 0, 0))
        ..alertTime = 60;
      final start = w.position.distanceTo(s.player.position);
      step(s, 0.5);
      expect(w.position.distanceTo(s.player.position), greaterThan(start + 1));
      step(s, 8);
      expect(s.wild, isEmpty, reason: 'fled beyond the despawn distance');
    });

    test('curious ones come closer and stay looking at you', () {
      final s = world();
      final w = addWild(
        s,
        s.player.position + Vector3(9, 0, 0),
        temperament: Temperament.curious,
        facing: 0,
      )..alertTime = 60;
      step(s, 6);
      final d = w.position.distanceTo(s.player.position);
      expect(d, closeTo(WildBehavior.curiousDistance, 0.3));
      final toPlayer = (s.player.position - w.position)..normalize();
      expect(w.facingDirection.dot(toPlayer), greaterThan(0.95));
    });

    test('aggressive ones charge and start an encounter', () {
      final contacts = <WildPokemon>[];
      final s = World3DSim(
        layout: layout,
        random: Random(3),
        maxFieldItems: 0,
        onWildContact: contacts.add,
      );
      final w = addWild(
        s,
        s.player.position + Vector3(9, 0, 0),
        temperament: Temperament.aggressive,
      )..alertTime = 60;
      step(s, 4);
      expect(contacts, [w]);
    });

    test('a ball landing next to a calm one startles it', () {
      final s = world();
      final w = addWild(
        s,
        s.player.position + Vector3(9, 0, 3),
        facing: pi / 2,
        temperament: Temperament.curious,
      );
      s.camera
        ..yaw = -pi / 2
        ..pitch = 0.62;
      // Tiro "a ojo" hacia +X: cae a unos 8–9 m, cerca de él.
      s.throwBall(PokeBallType.poke);
      var startled = false;
      for (var i = 0; i < 180 && !startled; i++) {
        s.update(1 / 60);
        startled = w.isAlert;
      }
      expect(startled, isTrue);
    });
  });

  group('player stealth', () {
    test('running stands you up; crouching is slower and quieter', () {
      final s = world()..crouching = true;
      expect(s.stealth, PlayerStealth.crouching);
      s
        ..camera.yaw = 0
        ..input.setKeyboardDirection(Vector2(0, -1));
      step(s, 0.5);
      expect(s.player.speed, closeTo(s.config.crouchSpeed, 0.05));

      s.cameraInput.running = true;
      step(s, 0.5);
      expect(s.crouching, isFalse);
      expect(s.stealth, PlayerStealth.noisy);
    });
  });
}
