// PRUEBAS de los Pokémon ESCONDIDOS en la hierba alta: no se mueven, la mira
// no los fija, no salen en el minimapa ni apartan la hierba (la agitan a
// ráfagas); salen al acercarte (asustados si vas de pie, distraídos y de
// espaldas si vas agachado), si cae una bola cerca o si les das con una;
// y si nadie los encuentra, se van.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/capture/capture_calculator.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/aiming.dart';
import 'package:pokemon_game/game3d/sim/grass_field.dart';
import 'package:pokemon_game/game3d/sim/minimap.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

void main() {
  // Campo abierto a la izquierda y hierba alta a la derecha (32 x 7).
  final layout = MapLayout.parse([
    'T' * 32,
    for (var i = 0; i < 5; i++) 'T${i == 2 ? '@' : '.'}${'.' * 9}${'"' * 20}T',
    'T' * 32,
  ]);

  /// Mundo con la cámara mirando hacia +X (hacia la hierba).
  World3DSim world({List<World3DEvent>? events, CaptureCalculator? calc}) {
    final s = World3DSim(
      layout: layout,
      random: Random(5),
      maxFieldItems: 0,
      onEvent: events?.add,
      calculator: calc,
    );
    s.camera.yaw = -pi / 2;
    return s;
  }

  /// Un escondido a [distance] m del jugador hacia +X (con 20 m cae en la
  /// hierba alta).
  WildPokemon hideAt(World3DSim s, double distance) {
    final w = WildPokemon(
      id: 'h',
      pokemon: fakePokemon(7),
      position: s.player.position + Vector3(distance, 0, 0),
      temperament: Temperament.skittish,
    )..hidden = true;
    s.wild.add(w);
    return w;
  }

  void step(World3DSim s, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60);
    }
  }

  test('hidden: stays put, cannot be locked, not on the minimap', () {
    final s = world();
    final w = hideAt(s, 20);
    final start = w.position;
    step(s, 5);
    expect(w.hidden, isTrue);
    expect(w.position, start);
    expect(
      findLockTarget(
        player: s.player.position,
        forward: s.camera.forward,
        wild: s.wild,
      ),
      isNull,
    );
    expect(MinimapView.of(s).markers(s), isEmpty);
    expect(s.grassPushers.length, 1, reason: 'only the player pushes');
    expect(s.grassRustlers.single, w.position);
  });

  test('the grass over a hidden one shakes in bursts', () {
    final at = Vector3(10, 0, 10);
    const near = GrassTuft(x: 10.5, z: 10, yaw: 0, scale: 1, phase: 0.3);
    const far = GrassTuft(x: 14, z: 10, yaw: 0, scale: 1, phase: 0.3);
    var maxNear = 0.0;
    var calmMoments = 0;
    for (var t = 0.0; t < 6; t += 0.01) {
      final tilt = GrassField.tiltFor(near, t, const [], rustlers: [at]);
      maxNear = max(maxNear, tilt.angle);
      if (GrassField.rustleBurst(t, at) == 0) calmMoments++;
      final still = GrassField.tiltFor(far, t, const [], rustlers: [at]);
      expect(still.angle, lessThanOrEqualTo(GrassField.windStrength + 1e-9));
    }
    expect(maxNear, greaterThan(0.2));
    expect(calmMoments, greaterThan(50), reason: 'bursts, not constant');
  });

  test('walking up makes it burst out, startled and facing you', () {
    final events = <World3DEvent>[];
    final s = world(events: events);
    final w = hideAt(s, 20);
    s.input.setKeyboardDirection(Vector2(0, -1)); // hacia +X (la cámara)
    var guard = 0;
    while (w.hidden) {
      s.update(1 / 60);
      expect(++guard, lessThan(400));
    }
    final d = w.position.distanceTo(s.player.position);
    expect(
      d,
      lessThanOrEqualTo(
        World3DSim.revealDistance(PlayerStealth.normal, moving: true) + 0.1,
      ),
    );
    expect(w.isAlert, isTrue);
    expect(w.revealedFor, isNotNull);
    final revealed = events.whereType<PokemonRevealed>().single;
    expect(revealed.startled, isTrue);
    expect(revealed.wild, w);
  });

  test('sneaking up (crouched) it peeks out unaware, looking away', () {
    final events = <World3DEvent>[];
    final s = world(events: events)..crouching = true;
    final w = hideAt(s, 20);
    s.input.setKeyboardDirection(Vector2(0, -1));
    var guard = 0;
    while (w.hidden) {
      s.update(1 / 60);
      expect(++guard, lessThan(900));
    }
    expect(w.isAlert, isFalse);
    expect(events.whereType<PokemonRevealed>().single.startled, isFalse);
    // Mira hacia otro lado: el jugador queda más o menos a su espalda.
    final toPlayer = s.player.position - w.position
      ..y = 0
      ..normalize();
    expect(toPlayer.dot(w.facingDirection), lessThan(0));
  });

  test('a ball landing close by flushes it out', () {
    final events = <World3DEvent>[];
    final s = world(events: events);
    final w = hideAt(s, 20);
    s.ballSystem.launch(
      PokeBallType.poke,
      w.position + Vector3(-1.5, 2.5, 0),
      Vector3(0, -1, 0),
    );
    step(s, 1);
    expect(w.hidden, isFalse);
    expect(w.isAlert, isTrue);
    expect(events.whereType<PokemonRevealed>().single.startled, isTrue);
  });

  test('a ball thrown at the rustling grass can catch it by surprise', () {
    final events = <World3DEvent>[];
    final s = world(
      events: events,
      calc: CaptureCalculator(random: Random(1)),
    );
    final w = hideAt(s, 20);
    // Directa al centro de la mata.
    s.ballSystem.launch(
      PokeBallType.ultra,
      w.position + Vector3(-2, 1, 0),
      Vector3(8, 0, 0),
    );
    step(s, 0.5);
    expect(w.capturedBy, isNotNull);
    expect(w.hidden, isFalse, reason: 'revealed inside the ball');
    expect(s.balls.single.hit!.unaware, isTrue);
  });

  test('nobody found it: it leaves after a while', () {
    final s = world();
    hideAt(s, 20);
    step(s, World3DSim.hiddenLifetime + 1);
    expect(s.wild, isEmpty);
  });

  test('reveal distance depends on how noticeable you are', () {
    double d(PlayerStealth s) => World3DSim.revealDistance(s, moving: true);
    expect(d(PlayerStealth.noisy), greaterThan(d(PlayerStealth.normal)));
    expect(d(PlayerStealth.normal), greaterThan(d(PlayerStealth.crouching)));
    expect(d(PlayerStealth.crouching), greaterThan(d(PlayerStealth.hidden)));
    expect(
      World3DSim.revealDistance(PlayerStealth.noisy, moving: false),
      lessThan(d(PlayerStealth.hidden)),
    );
  });
}
