// PRUEBAS de las Poké Balls del campo: aparecen lejos del jugador, nunca en
// caminos ni en casillas bloqueadas, se recogen al pasar por encima (avisando
// con un evento), el campo se repone poco a poco y las bolas falladas se
// pueden recoger pero no cuentan para el máximo.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/field_items.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  // Camino a la izquierda (sin bolas), campo abierto a la derecha.
  final layout = MapLayout.parse(const [
    'TTTTTTTTTTTTTTTTTTTT',
    'T@=.....,.....""""bT',
    'T.=..............""T',
    'T.=...o..........""T',
    'T.=................T',
    'TTTTTTTTTTTTTTTTTTTT',
  ]);

  FieldItems field({int max = 3, int seed = 1}) => FieldItems(
    layout: layout,
    tileSize: 2,
    random: Random(seed),
    maxItems: max,
  );

  test('fill spreads items far from the player, off paths and walls', () {
    final player = Vector3(3, 0, 3);
    final f = field()..fill(player);
    expect(f.items, hasLength(3));
    for (final item in f.items) {
      final kind = layout.tileAt(
        (item.position.x / 2).floor(),
        (item.position.z / 2).floor(),
      )!;
      expect(kind.walkable, isTrue);
      expect(kind, isNot(TileKind.path));
      expect(kind, isNot(TileKind.stone));
      expect(
        item.position.distanceTo(player),
        greaterThanOrEqualTo(FieldItems.minPlayerDistance),
      );
      expect(item.dropped, isFalse);
    }
    // Repartidos: ninguno pegado a otro.
    for (final a in f.items) {
      for (final b in f.items) {
        if (a != b) {
          expect(a.position.distanceTo(b.position), greaterThanOrEqualTo(6));
        }
      }
    }
  });

  test('loot: mostly Poké Balls, sometimes Great, rarely Ultra', () {
    expect(FieldItems.lootFor(0.1, 0.1), (ball: PokeBallType.poke, count: 2));
    expect(FieldItems.lootFor(0.5, 0.9), (ball: PokeBallType.poke, count: 3));
    expect(FieldItems.lootFor(0.7, 0.1).ball, PokeBallType.great);
    expect(FieldItems.lootFor(0.95, 0.9), (ball: PokeBallType.ultra, count: 1));
  });

  test('walking over an item picks it up and reports it', () {
    final f = field()..fill(Vector3(3, 0, 3));
    final item = f.items.first;
    final events = <World3DEvent>[];

    f.update(0.1, item.position + Vector3(0.5, 0, 0), events.add);

    expect(f.items, isNot(contains(item)));
    expect(events, hasLength(1));
    final picked = events.single as BallsPickedUp;
    expect(picked.ball, item.ball);
    expect(picked.count, item.count);
  });

  test('the field refills one item per respawn period', () {
    final player = Vector3(3, 0, 3);
    final f = field()..fill(player);
    final item = f.items.first;
    f.update(0.1, item.position, (_) {});
    expect(f.items, hasLength(2));

    f.update(FieldItems.respawnSeconds - 1, player, (_) {});
    expect(f.items, hasLength(2), reason: 'too soon');
    f.update(1.5, player, (_) {});
    expect(f.items, hasLength(3));
  });

  test('dropped balls can be picked up and do not count for the max', () {
    final player = Vector3(3, 0, 3);
    final f = field()..fill(player);
    final dropped = f.drop(PokeBallType.great, Vector3(20, 0.12, 5));
    expect(dropped.position.y, 0);
    expect(dropped.count, 1);
    expect(f.items, hasLength(4), reason: 'max 3 + the dropped one');

    final events = <World3DEvent>[];
    f.update(0.1, Vector3(20, 0, 5), events.add);
    expect(events.whereType<BallsPickedUp>().single.ball, PokeBallType.great);
    expect(f.items, hasLength(3));
  });

  test('World3DSim picks items up while walking and not while paused', () {
    final events = <World3DEvent>[];
    final s = World3DSim(
      layout: layout,
      random: Random(2),
      onEvent: events.add,
    );
    expect(s.fieldItems.items, isNotEmpty);
    final item = s.fieldItems.items.first;

    s
      ..setPaused(true)
      ..player.teleport(item.position)
      ..update(0.1);
    expect(events, isEmpty);

    s
      ..setPaused(false)
      ..update(0.1);
    expect(events.whereType<BallsPickedUp>(), hasLength(1));
  });
}
