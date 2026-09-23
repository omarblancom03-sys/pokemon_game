// PRUEBAS del suelo 3D: el ruido suave no tiene saltos, el color del suelo
// varía por manchas sin perder su tipo (césped, camino, hierba alta) y los
// detalles (matas bajas y piedrecitas) son pequeños y no se salen de su casilla.

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/mesh/mesh_builder.dart';
import 'package:pokemon_game/game3d/mesh/props.dart';
import 'package:pokemon_game/game3d/mesh/terrain_mesh.dart';
import 'package:pokemon_game/game3d/sim/cell_noise.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('smoothNoise', () {
    test('matches cellNoise on integer points and stays in 0..1', () {
      for (var i = 0; i < 20; i++) {
        expect(smoothNoise(i.toDouble(), i * 2.0, 3), cellNoise(i, i * 2, 3));
        final v = smoothNoise(i * 0.37, i * 0.91, 1);
        expect(v, inInclusiveRange(0, 1));
      }
    });

    test('has no jumps: tiny steps give tiny changes', () {
      for (var x = 0.0; x < 6; x += 0.01) {
        final a = smoothNoise(x, 2.5);
        final b = smoothNoise(x + 0.001, 2.5);
        expect((a - b).abs(), lessThan(0.01), reason: 'x = $x');
      }
    });
  });

  group('groundColorAt', () {
    double brightness(Vector4 c) => c.x + c.y + c.z;

    test('lawn varies in patches but stays close to its base color', () {
      final base = brightness(groundColor(TileKind.grass));
      var min = double.infinity;
      var max = double.negativeInfinity;
      for (var x = 0.0; x < 60; x += 1) {
        for (var z = 0.0; z < 60; z += 1) {
          final c = groundColorAt(TileKind.grass, x, z);
          expect(c.w, 1);
          min = brightness(c) < min ? brightness(c) : min;
          max = brightness(c) > max ? brightness(c) : max;
        }
      }
      expect(max - min, greaterThan(base * 0.08)); // hay manchas
      expect(min, greaterThan(base * 0.6));
      expect(max, lessThan(base * 1.45));
    });

    test('same place and kind → same color (tiles blend seamlessly)', () {
      expect(
        groundColorAt(TileKind.path, 4, 6),
        groundColorAt(TileKind.path, 4, 6),
      );
    });

    test('a path is still clearly lighter than tall grass anywhere', () {
      for (var x = 0.0; x < 40; x += 2.5) {
        final path = groundColorAt(TileKind.path, x, x * 0.7);
        final tall = groundColorAt(TileKind.tallGrass, x, x * 0.7);
        expect(brightness(path), greaterThan(brightness(tall) * 2));
      }
    });
  });

  test('grass tufts and pebbles are small and stay in their cell', () {
    var anyTuft = false;
    var anyPebble = false;
    for (var cell = 0; cell < 12; cell++) {
      final tufts = MeshBuilder();
      addGrassTufts(tufts, cell, 3);
      final pebbles = MeshBuilder();
      addPebbles(pebbles, cell, 3);
      for (final (mesh, maxHeight) in [
        (tufts.build(), 0.35),
        (pebbles.build(), 0.06),
      ]) {
        for (var i = 0; i < mesh.vertexCount; i++) {
          expect(mesh.positions[i * 3], inInclusiveRange(-1, 1));
          expect(mesh.positions[i * 3 + 1], inInclusiveRange(-0.05, maxHeight));
          expect(mesh.positions[i * 3 + 2], inInclusiveRange(-1, 1));
        }
      }
      anyTuft |= !tufts.isEmpty;
      anyPebble |= !pebbles.isEmpty;
    }
    expect(anyTuft, isTrue);
    expect(anyPebble, isTrue);
  });
}
