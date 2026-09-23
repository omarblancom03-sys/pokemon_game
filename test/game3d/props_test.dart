// PRUEBAS de los objetos del mundo 3D: detección de bloques de casas,
// ruido estable por casilla y que cada tipo de casilla genere geometría
// dentro de su sitio.

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/mesh/mesh_builder.dart';
import 'package:pokemon_game/game3d/mesh/props.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('findHouseBlocks groups contiguous H cells into rectangles', () {
    final layout = MapLayout.parse(const [
      'HH..H',
      'HH..H',
      '..@..',
    ]);

    expect(findHouseBlocks(layout), [
      (col: 0, row: 0, width: 2, height: 2),
      (col: 4, row: 0, width: 1, height: 2),
    ]);
  });

  test('cellNoise is stable and within 0..1', () {
    for (var i = 0; i < 50; i++) {
      final n = cellNoise(i, i * 3, i % 4);
      expect(n, inInclusiveRange(0, 1));
      expect(cellNoise(i, i * 3, i % 4), n);
    }
    expect(cellNoise(1, 2), isNot(cellNoise(2, 1)));
  });

  test('an empty meadow only builds the outer forest', () {
    final meadow = buildProps(MapLayout.parse(const ['..', '.@']), 2);
    final withTree = buildProps(MapLayout.parse(const ['.T', '.@']), 2);

    expect(meadow.isEmpty, isFalse); // el bosque del borde
    expect(withTree.triangleCount, greaterThan(meadow.triangleCount));
  });

  test('a tree stays roughly inside its own cell', () {
    final b = MeshBuilder();
    b.withTransform(Matrix4.translation(Vector3(5, 0, 5)), () {
      addTree(b, 1);
    });
    final m = b.build();
    for (var i = 0; i < m.vertexCount; i++) {
      expect(m.positions[i * 3], inInclusiveRange(3.9, 6.1));
      expect(m.positions[i * 3 + 1], greaterThanOrEqualTo(0));
      expect(m.positions[i * 3 + 2], inInclusiveRange(3.9, 6.1));
    }
  });

  test('a house covers its block and faces the door to +Z', () {
    final b = MeshBuilder();
    addHouse(b, (col: 1, row: 1, width: 4, height: 3), 2, Palette.roofRed);
    final m = b.build();

    var maxZ = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (var i = 0; i < m.vertexCount; i++) {
      maxY = m.positions[i * 3 + 1] > maxY ? m.positions[i * 3 + 1] : maxY;
      maxZ = m.positions[i * 3 + 2] > maxZ ? m.positions[i * 3 + 2] : maxZ;
    }
    expect(maxY, greaterThan(3)); // paredes + tejado
    // El escalón de la puerta sobresale por el sur del bloque (z = 8).
    expect(maxZ, greaterThan(8));
  });
}
