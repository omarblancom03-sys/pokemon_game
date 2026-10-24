// PRUEBAS de los objetos del mundo 3D: detección de bloques de casas,
// ruido estable por casilla y que cada tipo de casilla genere geometría
// dentro de su sitio.

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/mesh/mesh_builder.dart';
import 'package:pokemon_game/game3d/mesh/props.dart';
import 'package:pokemon_game/game3d/sim/trees.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('findHouseBlocks groups contiguous H cells into rectangles', () {
    final layout = MapLayout.parse(const ['HH..H', 'HH..H', '..@..']);

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

  test('bushes can be left out (the game draws them apart, to sway)', () {
    final layout = MapLayout.parse(const ['.b', '.@']);
    final all = buildProps(layout, 2);
    final noBush = buildProps(layout, 2, bushes: false);
    expect(all.triangleCount, greaterThan(noBush.triangleCount));
  });

  test('a berry fits in its radius (plus its little leaves on top)', () {
    final m = buildBerry(radius: 0.1);
    for (var i = 0; i < m.vertexCount; i++) {
      final p = Vector3(
        m.positions[i * 3],
        m.positions[i * 3 + 1],
        m.positions[i * 3 + 2],
      );
      expect(p.length, lessThan(0.12));
    }
  });

  test('a tree stays roughly inside its own cell', () {
    final layout = MapLayout.parse(const ['...', '.T.', '.@.']);
    final tree = TreeField.fromLayout(layout, 2, outerRing: 0).trees.single;
    final b = MeshBuilder();
    addTreeAt(b, tree);
    final m = b.build();
    for (var i = 0; i < m.vertexCount; i++) {
      expect(m.positions[i * 3], inInclusiveRange(1.9, 4.1));
      expect(m.positions[i * 3 + 1], greaterThanOrEqualTo(0));
      expect(m.positions[i * 3 + 2], inInclusiveRange(1.9, 4.1));
    }
  });

  test('without canopies only the trunks stay (the canopies sway apart)', () {
    final layout = MapLayout.parse(const ['.TPA', '.@..']);
    final all = buildProps(layout, 2);
    final trunks = buildProps(layout, 2, canopies: false);
    expect(trunks.isEmpty, isFalse);
    expect(all.triangleCount, greaterThan(trunks.triangleCount));
    // Ningún tronco del mapa pasa de lo alto del pivote de su copa.
    var maxY = 0.0;
    for (var i = 0; i < trunks.vertexCount; i++) {
      final x = trunks.positions[i * 3];
      final z = trunks.positions[i * 3 + 2];
      if (x < 0 || z < 0 || x > 8 || z > 4) continue; // bosque del borde
      maxY = trunks.positions[i * 3 + 1] > maxY
          ? trunks.positions[i * 3 + 1]
          : maxY;
    }
    expect(maxY, lessThanOrEqualTo(1.2 * 1.35 * 1 + 1e-6));
  });

  test('the canopy, placed by TreeField, lands where the whole tree was', () {
    // La copa aparte (pivote en el origen) + su transformación sin viento
    // = la misma copa que addTreeAt dibuja entera.
    final layout = MapLayout.parse(const ['.T', '.@']);
    final tree = TreeField.fromLayout(layout, 2, outerRing: 0).trees.single;
    final whole = MeshBuilder();
    addTreeAt(whole, tree);
    final trunk = MeshBuilder();
    addTreeAt(trunk, tree, canopy: false);
    final canopy = buildCanopy(tree.kind);
    final m = TreeField.canopyTransform(tree, (x: 0, z: 0));

    final w = whole.build();
    final t = trunk.build();
    expect(w.vertexCount, t.vertexCount + canopy.vertexCount);
    for (var i = 0; i < canopy.vertexCount; i++) {
      final p = m.transformed3(
        Vector3(
          canopy.positions[i * 3],
          canopy.positions[i * 3 + 1],
          canopy.positions[i * 3 + 2],
        ),
      );
      final j = t.vertexCount + i;
      expect(p.x, closeTo(w.positions[j * 3], 1e-4));
      expect(p.y, closeTo(w.positions[j * 3 + 1], 1e-4));
      expect(p.z, closeTo(w.positions[j * 3 + 2], 1e-4));
    }
  });

  test('a falling leaf is small, almost flat and seen from both sides', () {
    final leaf = buildFallingLeaf();
    expect(leaf.isEmpty, isFalse);
    var up = 0;
    var down = 0;
    for (var i = 0; i < leaf.vertexCount; i++) {
      expect(leaf.positions[i * 3].abs(), lessThanOrEqualTo(0.25 + 1e-6));
      expect(leaf.positions[i * 3 + 1].abs(), lessThanOrEqualTo(0.05 + 1e-6));
      expect(leaf.positions[i * 3 + 2].abs(), lessThanOrEqualTo(0.5 + 1e-6));
      if (leaf.normals[i * 3 + 1] > 0.5) up++;
      if (leaf.normals[i * 3 + 1] < -0.5) down++;
    }
    // Tantas caras hacia arriba como hacia abajo.
    expect(up, greaterThan(0));
    expect(up, down);
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
