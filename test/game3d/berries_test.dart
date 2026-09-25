// PRUEBAS de los ARBUSTOS CON BAYAS: se encuentran en el mapa llenos, las
// bayas cuelgan por fuera de las hojas, solo se sacude el que está cerca y
// delante, al sacudirlo suelta todas sus bayas, que caen a los pies del
// jugador en suelo libre y se recogen cuando dejan de botar; no se
// puede volver a sacudir mientras se balancea, le vuelven a crecer y las
// que nadie recoge se pudren. En el mundo: la tecla de acción elige entre
// cartel y arbusto, sacudir hace ruido y con el mundo congelado no se hace.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/berries.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

void main() {
  // Un arbusto (3,2) y, al lado, un cartel (4,2) en una pradera (casillas
  // de 2 m).
  final layout = MapLayout.parse([
    'TTTTTTTTTTTT',
    'T..........T',
    'T..bs......T',
    'T...@......T',
    'T..........T',
    'T..........T',
    'TTTTTTTTTTTT',
  ]);
  const tile = 2.0;

  Vector3 center(int col, int row) =>
      Vector3((col + 0.5) * tile, 0, (row + 0.5) * tile);

  /// Mirando hacia -Z (hacia arriba en el mapa).
  const north = pi;

  BerrySystem berries() =>
      BerrySystem.fromLayout(layout, tile, random: Random(3));

  /// Avanza [seconds] con el jugador quieto en [player]; devuelve lo que
  /// se recogió.
  List<World3DEvent> run(BerrySystem s, Vector3 player, double seconds) {
    final events = <World3DEvent>[];
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60, player, events.add);
    }
    return events;
  }

  int picked(List<World3DEvent> events) =>
      events.whereType<BerriesPickedUp>().fold(0, (sum, e) => sum + e.count);

  test('finds every bush, full, with berries hanging outside the leaves', () {
    final s = berries();
    final bush = s.bushes.single;
    expect(bush.cell, (col: 3, row: 2));
    expect(bush.berries, BerrySystem.maxBerries);
    expect(bush.slots, hasLength(BerrySystem.maxBerries));
    final unit = tile / 2;
    for (final slot in bush.slots) {
      final local = (slot - bush.center) / unit;
      // Por fuera de las tres bolas de hojas…
      for (final b in bushLeafBalls) {
        final d = Vector3(
          (local.x - b.x) / b.rx,
          (local.y - b.y) / b.ry,
          (local.z - b.z) / b.rz,
        );
        expect(d.length, greaterThanOrEqualTo(1));
      }
      // …pero pegadas a ellas y dentro de su casilla.
      expect(slot.y, inInclusiveRange(0.4, 1.1));
      final flat = Vector3(local.x, 0, local.z).length * unit;
      expect(flat, lessThan(1));
    }
  });

  test('only a bush that is close and in front can be shaken', () {
    final s = berries();
    final below = center(3, 3);
    expect(s.reachable(below, north), same(s.bushes.single));
    expect(s.reachable(below, 0), isNull, reason: 'looking away');
    expect(s.reachable(center(3, 4) + Vector3(0, 0, 1), north), isNull);
  });

  test('shaking drops every berry at the feet; picked up once landed', () {
    final s = berries();
    final bush = s.bushes.single;
    final player = center(3, 3);

    expect(s.shake(bush, player), 3);
    expect(bush.berries, 0);
    expect(bush.isShaking, isTrue);
    expect(s.loose, hasLength(3));

    // En el aire no se recogen.
    final flying = run(s, player, 0.3);
    expect(picked(flying), 0);
    expect(bush.sway, isNot(0));

    final events = run(s, player, 1.5);
    expect(picked(events), 3);
    expect(s.loose, isEmpty);
    expect(bush.isShaking, isFalse);
    expect(bush.sway, 0);
  });

  test('berries land on free ground near the player, between him and it', () {
    final s = berries();
    final bush = s.bushes.single;
    // Al lado del arbusto, pegado a su casilla.
    final player = center(2, 2) + Vector3(0.5, 0, 0);
    s.shake(bush, player);
    // Lejos (no las recoge) hasta que se paran.
    run(s, Vector3(100, 0, 100), 2);
    expect(s.loose, hasLength(3));
    for (final berry in s.loose) {
      expect(berry.landed, isTrue);
      expect(berry.position.y, closeTo(BerrySystem.radius, 1e-6));
      final cell = (
        col: (berry.position.x / tile).floor(),
        row: (berry.position.z / tile).floor(),
      );
      expect(layout.isWalkable(cell.col, cell.row), isTrue);
      final flat = Vector3(berry.position.x, 0, berry.position.z);
      expect(flat.distanceTo(player), lessThan(BerrySystem.pickupRadius));
    }
  });

  test('walking away leaves them on the ground; coming back picks them', () {
    final s = berries();
    final bush = s.bushes.single;
    final player = center(3, 3);
    s.shake(bush, player);
    final away = center(9, 5);
    expect(picked(run(s, away, 2)), 0);
    expect(s.loose, hasLength(3));
    expect(picked(run(s, player, 0.1)), 3);
  });

  test('cannot shake again while it sways; an empty bush drops nothing', () {
    final s = berries();
    final bush = s.bushes.single;
    final player = center(3, 3);
    s.shake(bush, player);
    expect(s.shake(bush, player), isNull);
    run(s, player, BerrySystem.shakeDuration + 0.1);
    expect(s.shake(bush, player), 0);
    expect(bush.isShaking, isTrue);
  });

  test('berries grow back one by one, up to the maximum', () {
    final s = berries();
    final bush = s.bushes.single;
    s.shake(bush, center(3, 3));
    final away = center(9, 5);
    run(s, away, BerrySystem.regrowSeconds + 0.1);
    expect(bush.berries, 1);
    expect(bush.berryScale(0), lessThan(1), reason: 'it pops in');
    run(s, away, 1);
    expect(bush.berryScale(0), 1);
    expect(bush.berryScale(1), 0);
    run(s, away, BerrySystem.regrowSeconds * 3);
    expect(bush.berries, BerrySystem.maxBerries);
  });

  test('berries nobody picks up rot away', () {
    final s = berries();
    s.shake(s.bushes.single, center(3, 3));
    final away = center(9, 5);
    run(s, away, 2);
    expect(s.loose.first.scale, 1);
    run(s, away, BerrySystem.groundLifetime - 1.5);
    expect(s.loose.first.scale, lessThan(1));
    run(s, away, 1);
    expect(s.loose, isEmpty);
  });

  group('in the world', () {
    World3DSim world({List<World3DEvent>? events}) => World3DSim(
      layout: layout,
      random: Random(1),
      maxFieldItems: 0,
      onEvent: events?.add,
    );

    void step(World3DSim s, double seconds) {
      for (var t = 0.0; t < seconds; t += 1 / 60) {
        s.update(1 / 60);
      }
    }

    test('the action key shakes the bush in front and berries reach the '
        'bag', () {
      final events = <World3DEvent>[];
      final s = world(events: events);
      s.player
        ..teleport(center(3, 3))
        ..facing = north;
      expect(s.shakableBush, same(s.berries.bushes.single));
      expect(s.readableSign, isNull);

      expect(s.act(), isTrue);
      expect(events.whereType<BushShaken>().single.berries, 3);
      expect(s.blades.blades, isNotEmpty, reason: 'leaves fall');
      expect(s.act(), isFalse, reason: 'still swaying');

      step(s, 2);
      final picked = events.whereType<BerriesPickedUp>();
      expect(picked.fold(0, (sum, e) => sum + e.count), 3);
    });

    test('with a sign and a bush in reach, the nearest one is used', () {
      final s = world();
      // Debajo de los dos (los dos a mano), más cerca del cartel.
      s.player
        ..teleport(Vector3(8.2, 0, 6.6))
        ..facing = north;
      expect(s.readableSign, (col: 4, row: 2));
      expect(s.shakableBush, isNull);
      // Un poco a la izquierda: más cerca del arbusto.
      s.player.teleport(Vector3(7.8, 0, 6.6));
      expect(s.readableSign, isNull);
      expect(s.shakableBush, isNotNull);
      expect(s.act(), isTrue);
      expect(s.openSign, isNull);
    });

    test('while reading a sign, the bush cannot be shaken', () {
      final s = world();
      s.player
        ..teleport(Vector3(8.2, 0, 6.6))
        ..facing = north;
      expect(s.act(), isTrue);
      expect(s.openSign, isNotNull);
      s.player.teleport(Vector3(7.8, 0, 6.6));
      expect(s.shakableBush, isNull);
      expect(s.act(), isTrue, reason: 'closes the sign');
      expect(s.openSign, isNull);
      expect(s.berries.bushes.single.berries, 3);
    });

    test('shaking is noisy: nearby Pokémon turn to look, hidden ones jump '
        'out; far ones do not notice', () {
      final events = <World3DEvent>[];
      final s = world(events: events);
      s.player
        ..teleport(center(3, 3))
        ..facing = north;
      WildPokemon add(String id, Vector3 at, {bool hidden = false}) {
        final w = WildPokemon(
          id: id,
          pokemon: fakePokemon(4),
          position: at,
          temperament: Temperament.skittish,
          // Mirando hacia +X, de espaldas al jugador: no lo ve.
          facing: pi / 2,
        )..hidden = hidden;
        s.wild.add(w);
        return w;
      }

      final bush = s.berries.bushes.single.center;
      final near = add('near', bush + Vector3(5, 0, 1));
      final hidden = add('hidden', bush + Vector3(3, 0, 0), hidden: true);
      final far = add('far', bush + Vector3(14, 0, 4));

      expect(s.shakeBush(), isTrue);
      expect(near.isSuspicious, isTrue);
      expect(far.awareness, 0);
      expect(hidden.hidden, isFalse);
      expect(events.whereType<PokemonRevealed>().single.startled, isTrue);
    });

    test('while the world is frozen nothing can be shaken', () {
      final s = world()..setPaused(true);
      s.player
        ..teleport(center(3, 3))
        ..facing = north;
      expect(s.shakableBush, isNull);
      expect(s.act(), isFalse);
      expect(s.berries.bushes.single.berries, 3);
    });
  });
}
