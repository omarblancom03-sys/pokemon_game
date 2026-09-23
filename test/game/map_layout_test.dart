// PRUEBAS del mapa como datos: que lee bien el dibujo ASCII, que rechaza
// dibujos mal hechos, qué se puede pisar, y que el mapa REAL del juego es
// válido (inicio y humos en casillas pisables).

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/config/world_config.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game/map/world_map.dart';

void main() {
  final layout = MapLayout.parse(['TTTT', 'T@.T', 'T=#T', 'TTTT']);

  group('parse', () {
    test('reads size, tiles and start', () {
      expect(layout.columns, 4);
      expect(layout.rows, 4);
      expect(layout.start, (col: 1, row: 1));
      expect(layout.tileAt(1, 1), TileKind.path, reason: '@ is a path');
      expect(layout.tileAt(2, 1), TileKind.grass);
      expect(layout.tileAt(2, 2), TileKind.fence);
      expect(layout.tileAt(9, 9), isNull, reason: 'outside the map');
    });

    test('rejects rows of different length', () {
      expect(() => MapLayout.parse(['@..', '..']), throwsFormatException);
    });

    test('rejects unknown characters', () {
      expect(() => MapLayout.parse(['@?']), throwsFormatException);
    });

    test('requires exactly one start', () {
      expect(() => MapLayout.parse(['...']), throwsFormatException);
      expect(() => MapLayout.parse(['@.@']), throwsFormatException);
    });

    test('rejects an empty map', () {
      expect(() => MapLayout.parse([]), throwsFormatException);
    });
  });

  group('walkability', () {
    test('per cell; outside the map is blocked', () {
      expect(layout.isWalkable(1, 1), isTrue);
      expect(layout.isWalkable(0, 0), isFalse);
      expect(layout.isWalkable(2, 2), isFalse);
      expect(layout.isWalkable(-1, 1), isFalse);
    });

    test('an area is walkable only if every touched cell is', () {
      const tile = 10.0;
      // Dentro de las casillas (1,1) y (2,1): césped y camino.
      expect(
        layout.isAreaWalkable(const Rect.fromLTWH(12, 12, 15, 5), tile),
        isTrue,
      );
      // Baja hasta la fila 2 y toca la valla (2,2).
      expect(
        layout.isAreaWalkable(const Rect.fromLTWH(22, 15, 5, 10), tile),
        isFalse,
      );
      // Borde exacto: acabar justo en x=30 no cuenta como tocar la col 3.
      expect(
        layout.isAreaWalkable(const Rect.fromLTWH(20, 10, 10, 10), tile),
        isTrue,
      );
    });

    test('walkableCells lists only walkable cells', () {
      expect(layout.walkableCells.toList(), [
        (col: 1, row: 1),
        (col: 2, row: 1),
        (col: 1, row: 2),
      ]);
    });
  });

  group('real world map', () {
    final world = MapLayout.parse(worldMapRows);
    const config = WorldConfig();

    test('parses and starts on a walkable cell', () {
      expect(world.isWalkable(world.start.col, world.start.row), isTrue);
    });

    test('every configured smoke is on a walkable cell', () {
      for (final spawn in config.smokeSpawns) {
        final col = (spawn.x / config.tileSize).floor();
        final row = (spawn.y / config.tileSize).floor();
        expect(world.isWalkable(col, row), isTrue, reason: spawn.id);
      }
    });
  });
}
