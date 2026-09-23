// PRUEBAS del constructor de mallas low-poly: caras hacia fuera, colores por
// vértice, pila de transformaciones, conversión al espacio del motor y
// suelo (una casilla = un cuadrado del color de su tipo).

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/mesh/mesh_builder.dart';
import 'package:pokemon_game/game3d/mesh/terrain_mesh.dart';
import 'package:vector_math/vector_math.dart';

Vector3 _vec(List<double> data, int vertex) =>
    Vector3(data[vertex * 3], data[vertex * 3 + 1], data[vertex * 3 + 2]);

/// Normal geométrica del triángulo t (según el orden de sus índices).
Vector3 _faceNormal(MeshBuffers m, int t) {
  final a = _vec(m.positions, m.indices[t * 3]);
  final b = _vec(m.positions, m.indices[t * 3 + 1]);
  final c = _vec(m.positions, m.indices[t * 3 + 2]);
  return (b - a).cross(c - a)..normalize();
}

void main() {
  test('a box has 12 triangles, all facing outwards', () {
    final m = (MeshBuilder()
          ..box(Vector3(-1, -1, -1), Vector3(1, 1, 1), srgb(0xFF0000)))
        .build();

    expect(m.triangleCount, 12);
    expect(m.vertexCount, 36);
    for (var t = 0; t < m.triangleCount; t++) {
      final a = _vec(m.positions, m.indices[t * 3]);
      // Desde el centro (0,0,0) hacia la cara: misma dirección que la normal.
      expect(_faceNormal(m, t).dot(a), greaterThan(0), reason: 'tri $t');
      // La normal guardada coincide con la geométrica.
      expect(
        _vec(m.normals, m.indices[t * 3]).dot(_faceNormal(m, t)),
        closeTo(1, 1e-5),
      );
    }
  });

  test('prisms and gems face outwards too', () {
    final m = (MeshBuilder()
          ..prism(
            base: Vector3(0, -1, 0),
            bottomRadius: 1,
            topRadius: 0.5,
            height: 2,
            sides: 6,
            color: srgb(0x00FF00),
          )
          ..gem(Vector3.zero(), Vector3.all(1), srgb(0x0000FF)))
        .build();

    for (var t = 0; t < m.triangleCount; t++) {
      final a = _vec(m.positions, m.indices[t * 3]);
      final b = _vec(m.positions, m.indices[t * 3 + 1]);
      final c = _vec(m.positions, m.indices[t * 3 + 2]);
      final centroid = (a + b + c)..scale(1 / 3);
      expect(_faceNormal(m, t).dot(centroid), greaterThan(0), reason: '$t');
    }
  });


  test('withTransform moves the geometry and pop restores it', () {
    final builder = MeshBuilder();
    builder.withTransform(Matrix4.translation(Vector3(10, 0, 0)), () {
      builder.triangle(
        Vector3.zero(),
        Vector3(0, 0, 1),
        Vector3(1, 0, 0),
        srgb(0xFFFFFF),
      );
    });
    builder.triangle(
      Vector3.zero(),
      Vector3(0, 0, 1),
      Vector3(1, 0, 0),
      srgb(0xFFFFFF),
    );
    final m = builder.build();
    expect(m.positions[0], 10);
    expect(m.positions[9], 0);
    expect(builder.pop, throwsStateError);
  });

  test('srgb converts to linear color', () {
    expect(srgb(0xFFFFFF), Vector4(1, 1, 1, 1));
    expect(srgb(0x000000), Vector4(0, 0, 0, 1));
    expect(srgb(0x808080).x, closeTo(0.2158, 1e-3));
  });

  test('toEngineSpace mirrors Z and keeps faces pointing outwards', () {
    final m = (MeshBuilder()
          ..box(Vector3(-1, -1, 2), Vector3(1, 1, 4), srgb(0xFF0000)))
        .build()
        .toEngineSpace();

    for (var t = 0; t < m.triangleCount; t++) {
      final a = _vec(m.positions, m.indices[t * 3]);
      // El centro de la caja pasó de z = 3 a z = -3.
      expect(_faceNormal(m, t).dot(a - Vector3(0, 0, -3)), greaterThan(0));
      expect(
        _vec(m.normals, m.indices[t * 3]).dot(_faceNormal(m, t)),
        closeTo(1, 1e-5),
      );
    }
  });

  test('terrain has one upward quad per cell, colored by tile kind', () {
    final layout = MapLayout.parse(const ['.=', '"@']);
    final m = buildTerrain(layout, 2);

    expect(m.triangleCount, 2 * 4);
    for (var t = 0; t < m.triangleCount; t++) {
      expect(_faceNormal(m, t).y, closeTo(1, 1e-6));
    }
    // Primer vértice de la casilla (1,0) = camino.
    final pathColor = groundColor(TileKind.path, 1, 0);
    expect(m.colors[6 * 4], closeTo(pathColor.x, 1e-6));
  });
}
