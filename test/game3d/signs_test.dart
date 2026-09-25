// PRUEBAS de los carteles: se encuentran en el mapa, solo se puede leer el
// que está cerca y DELANTE del jugador (el más cercano si hay dos), leer
// abre y vuelve a cerrar, alejarse lo cierra y con el mundo congelado no
// se lee nada.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/signs.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  // Dos carteles en una pradera (casillas de 2 m).
  final layout = MapLayout.parse([
    'TTTTTTTTTT',
    'T........T',
    'T..s.s...T',
    'T...@....T',
    'T........T',
    'TTTTTTTTTT',
  ]);
  const tile = 2.0;

  Vector3 center(int col, int row) =>
      Vector3((col + 0.5) * tile, 0, (row + 0.5) * tile);

  /// Mirando hacia -Z (hacia arriba en el mapa), como al empezar.
  const north = pi;

  test('finds every sign in the layout', () {
    final reader = SignReader.fromLayout(layout, tile);
    expect(reader.signs, [(col: 3, row: 2), (col: 5, row: 2)]);
  });

  test('only a sign that is close and in front can be read', () {
    final reader = SignReader.fromLayout(layout, tile);
    final below = center(3, 3); // justo debajo del primer cartel
    expect(reader.readable(below, north), (col: 3, row: 2));
    expect(reader.readable(below, 0), isNull, reason: 'looking away');
    expect(reader.readable(below, north + pi / 3), (col: 3, row: 2));
    expect(
      reader.readable(center(3, 4) + Vector3(0, 0, 1), north),
      isNull,
      reason: 'too far',
    );
    // Entre los dos (los dos a su alcance), más cerca del segundo: ese.
    final between = center(4, 3) + Vector3(0.2, 0, -0.8);
    for (final sign in reader.signs) {
      final d = center(sign.col, sign.row).distanceTo(between);
      expect(d, lessThan(SignReader.readRange));
    }
    expect(reader.readable(between, north), (col: 5, row: 2));
  });

  test('reading opens it; again closes it; nothing to read: nothing', () {
    final reader = SignReader.fromLayout(layout, tile);
    final below = center(3, 3);
    expect(reader.toggle(below, north), isTrue);
    expect(reader.open, (col: 3, row: 2));
    expect(reader.toggle(below, north), isTrue);
    expect(reader.open, isNull);
    expect(reader.toggle(below, 0), isFalse);
    expect(reader.open, isNull);
  });

  test('walking away closes it (turning around does not)', () {
    final reader = SignReader.fromLayout(layout, tile)
      ..toggle(center(3, 3), north)
      ..update(center(3, 3));
    expect(reader.open, isNotNull, reason: 'still there, just turned');
    reader.update(center(3, 4) + Vector3(0, 0, 0.8));
    expect(reader.open, isNull);
  });

  group('in the world', () {
    World3DSim world() =>
        World3DSim(layout: layout, random: Random(1), maxFieldItems: 0);

    test('the sim exposes the sign in front and closes it as you leave', () {
      final s = world();
      s.player
        ..teleport(center(3, 3))
        ..facing = north;
      expect(s.readableSign, (col: 3, row: 2));
      expect(s.toggleSign(), isTrue);
      expect(s.openSign, (col: 3, row: 2));

      s.player.teleport(center(3, 4) + Vector3(0, 0, 1));
      s.update(1 / 60);
      expect(s.openSign, isNull);
    });

    test('while the world is frozen nothing can be read', () {
      final s = world()..setPaused(true);
      s.player
        ..teleport(center(3, 3))
        ..facing = north;
      expect(s.readableSign, isNull);
      expect(s.toggleSign(), isFalse);
      expect(s.openSign, isNull);
    });
  });
}
