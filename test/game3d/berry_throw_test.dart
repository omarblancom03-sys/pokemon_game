// PRUEBAS de LANZAR BAYAS: con una baya en la mano se ve la baya (no la
// bola), no hay probabilidad de captura y el arco previsto no choca con los
// Pokémon; al lanzarla sale de la mano, cae un poco por detrás del Pokémon
// fijado (del lado contrario al jugador), rebota contra los árboles y, en el
// suelo, se puede volver a recoger.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

void main() {
  // Pradera abierta de 24 x 9 casillas con un árbol (8,4) en la fila del
  // jugador (el inicio está en 3,4).
  final layout = MapLayout.parse([
    'T' * 24,
    for (var row = 1; row < 8; row++)
      row == 4 ? 'T..@....T${'.' * 14}T' : 'T${'.' * 22}T',
    'T' * 24,
  ]);

  /// Mundo con la cámara mirando hacia +X (hacia el árbol) y una baya en
  /// la mano.
  World3DSim world({List<World3DEvent>? events}) {
    final s = World3DSim(
      layout: layout,
      random: Random(3),
      maxFieldItems: 0,
      onEvent: events?.add,
    )..berryReady = true;
    s.camera.yaw = -pi / 2;
    return s;
  }

  void step(World3DSim s, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60);
    }
  }

  /// Un Pokémon tranquilo a [offset] del jugador, de espaldas a él (mira
  /// hacia +X).
  WildPokemon wildAt(World3DSim s, Vector3 offset) {
    final w = WildPokemon(
      id: 'w',
      pokemon: fakePokemon(25),
      position: s.player.position + offset,
      temperament: Temperament.skittish,
      facing: pi / 2,
    )..idleTime = 1e9;
    s.wild.add(w);
    return w;
  }

  test('with a berry in hand: berry shown, no capture chance, an arc that '
      'ignores Pokémon', () {
    final s = world();
    // Por debajo del árbol, para que nada estorbe.
    s.player.teleport(s.cellCenter(3, 6));
    wildAt(s, Vector3(7, 0, 0));
    s.aiming = true;
    step(s, 0.2);
    expect(s.lockedTarget, isNotNull);
    expect(s.heldBerry, isTrue);
    expect(s.heldBall, isNull);
    expect(s.lockedChance, isNull);
    final arc = s.aimPreview;
    expect(arc, isNotEmpty);
    expect(arc.last.y, closeTo(BerrySystem.radius, 0.05), reason: 'ground');

    // Sin baya en la mano, lo de siempre.
    s.berryReady = false;
    expect(s.heldBerry, isFalse);
    expect(s.heldBall, isNotNull);
    expect(s.lockedChance, isNotNull);
  });

  test('a berry with no balls left can still be aimed and thrown', () {
    final s = world()..readyBall = null;
    s.aiming = true;
    step(s, 0.1);
    expect(s.aimPreview, isNotEmpty);
    expect(s.throwBerry(), isTrue);
  });

  test('thrown at a locked Pokémon, it lands just behind it', () {
    final s = world();
    s.player.teleport(s.cellCenter(3, 6));
    final w = wildAt(s, Vector3(7, 0, 0));
    s.aiming = true;
    step(s, 0.2);
    final spot = s.baitSpot(w);
    expect(spot.distanceTo(w.position), closeTo(World3DSim.baitOffset, 0.2));

    expect(s.throwBerry(), isTrue);
    expect(s.heldBerry, isTrue, reason: 'still in the hand');
    step(s, World3DSim.releaseTime + 0.02);
    expect(s.heldBerry, isFalse, reason: 'it left the hand');
    final berry = s.berries.loose.single;
    expect(berry.thrown, isTrue);
    expect(s.balls, isEmpty);

    step(s, 2);
    expect(berry.landed, isTrue);
    final flat = Vector3(berry.position.x, 0, berry.position.z);
    expect(flat.distanceTo(Vector3(spot.x, 0, spot.z)), lessThan(1.2));
    // Al otro lado del Pokémon: para comérsela te dará la espalda.
    expect(berry.position.x, greaterThan(w.position.x));
  });

  test('a berry thrown at a tree bounces back and falls on this side', () {
    final s = world();
    s.player.teleport(s.cellCenter(6, 4));
    s.camera.pitch = 0.5; // tiro tenso, hacia el árbol (8,4)
    s.aiming = true;
    step(s, 0.1);
    s.throwBerry();
    step(s, 3);
    final berry = s.berries.loose.single;
    expect(berry.landed, isTrue);
    expect(berry.position.x, lessThan(8 * 2.0), reason: 'did not go through');
    expect(layout.isWalkable((berry.position.x / 2).floor(), 4), isTrue);
  });

  test('a thrown berry on the ground can be picked up again', () {
    final events = <World3DEvent>[];
    final s = world(events: events);
    s.player.teleport(s.cellCenter(3, 6));
    s.aiming = true;
    step(s, 0.1);
    s.throwBerry();
    step(s, 2.5);
    final berry = s.berries.loose.single;
    expect(berry.landed, isTrue);
    expect(events.whereType<BerriesPickedUp>(), isEmpty);

    s.player.teleport(Vector3(berry.position.x, 0, berry.position.z));
    step(s, 0.1);
    expect(events.whereType<BerriesPickedUp>().single.count, 1);
  });
}
