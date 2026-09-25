// PRUEBAS del contenido de los carteles del mapa: cada cartel del mapa
// tiene su propio texto (ninguno sale "gastado"), no sobra ningún texto
// sin cartel y a todos se puede llegar (tienen al lado una casilla
// pisable).

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game/map/world_map.dart';
import 'package:pokemon_game/game/map/world_signs.dart';

void main() {
  final world = MapLayout.parse(worldMapRows);
  final signCells = [
    for (var row = 0; row < world.rows; row++)
      for (var col = 0; col < world.columns; col++)
        if (world.tileAt(col, row) == TileKind.sign) (col: col, row: row),
  ];

  test('the world has signs and every one has its own text', () {
    expect(signCells.length, greaterThanOrEqualTo(4));
    for (final c in signCells) {
      final text = signTextAt(c.col, c.row);
      expect(text, isNot(same(unreadableSign)), reason: '$c');
      expect(text.title, isNotEmpty);
      expect(text.body, isNotEmpty);
    }
  });

  test('no text is left over without its sign', () {
    for (final cell in worldSigns.keys) {
      expect(world.tileAt(cell.col, cell.row), TileKind.sign, reason: '$cell');
    }
  });

  test('every sign can be reached (a walkable cell next to it)', () {
    for (final c in signCells) {
      final neighbours = [
        (c.col + 1, c.row),
        (c.col - 1, c.row),
        (c.col, c.row + 1),
        (c.col, c.row - 1),
      ];
      expect(
        neighbours.any((n) => world.isWalkable(n.$1, n.$2)),
        isTrue,
        reason: '$c',
      );
    }
  });

  test('a sign without text reads as worn out', () {
    expect(signTextAt(0, 0), same(unreadableSign));
  });
}
