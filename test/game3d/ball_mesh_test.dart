// PRUEBAS de la malla de la Poké Ball (rediseño de la ficha "PokeBall
// Spec"): cada tipo tiene sus colores y marcas, todas las caras miran hacia
// donde apuntan sus normales, las calcomanías no se hunden en la carcasa,
// la bola cabe en su radio y no pasa de 2000 triángulos, y la tapa cuelga
// de la bisagra trasera.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game3d/mesh/ball_mesh.dart';
import 'package:pokemon_game/game3d/mesh/mesh_builder.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

Vector3 _vertex(MeshBuffers m, int i) =>
    Vector3(m.positions[i * 3], m.positions[i * 3 + 1], m.positions[i * 3 + 2]);

Vector3 _normal(MeshBuffers m, int i) =>
    Vector3(m.normals[i * 3], m.normals[i * 3 + 1], m.normals[i * 3 + 2]);

Vector4 _color(MeshBuffers m, int i) => Vector4(
  m.colors[i * 4],
  m.colors[i * 4 + 1],
  m.colors[i * 4 + 2],
  m.colors[i * 4 + 3],
);

/// Colores (distintos) de todos los vértices de la pieza.
Set<Vector4> _colors(MeshBuffers m) => {
  for (var i = 0; i < m.vertexCount; i++) _color(m, i),
};

int _triangles(BallPieces pieces) =>
    pieces.values.fold(0, (sum, m) => sum + m.triangleCount);

void main() {
  test(
    'each ball type has its own top color and marks, and a white bottom',
    () {
      Set<Vector4> shell(PokeBallType type) =>
          _colors(buildPokeBall(type)[BallSurface.shell]!);
      expect(shell(PokeBallType.poke), {BallPalette.red, BallPalette.white});
      expect(shell(PokeBallType.great), {
        BallPalette.blue,
        BallPalette.red, // las alas
        BallPalette.white,
      });
      expect(shell(PokeBallType.ultra), {
        BallPalette.black,
        BallPalette.yellow, // la "H"
        BallPalette.white,
      });
      final ball = buildPokeBall(PokeBallType.poke);
      expect(_colors(ball[BallSurface.button]!), {BallPalette.button});
      expect(_colors(ball[BallSurface.ring]!), {BallPalette.ring});
      expect(_colors(ball[BallSurface.matte]!), {
        BallPalette.band,
        BallPalette.inside,
        BallPalette.rim,
      });
    },
  );

  test('every face looks the way its normals point (none inside out)', () {
    for (final type in PokeBallType.values) {
      for (final piece in buildPokeBall(type).values) {
        for (var t = 0; t < piece.indices.length; t += 3) {
          final [i, j, k] = piece.indices.sublist(t, t + 3);
          final face = (_vertex(piece, j) - _vertex(piece, i)).cross(
            _vertex(piece, k) - _vertex(piece, i),
          );
          final normals =
              _normal(piece, i) + _normal(piece, j) + _normal(piece, k);
          expect(face.dot(normals), greaterThan(0), reason: '$type, tri $t');
        }
      }
    }
  });

  test('the shell is smooth: normals point out from the center', () {
    final shell = buildPokeBall(PokeBallType.poke)[BallSurface.shell]!;
    for (var i = 0; i < shell.vertexCount; i++) {
      final v = _vertex(shell, i);
      expect(v.length, closeTo(1, 1e-5));
      expect(_normal(shell, i).dot(v), closeTo(1, 1e-5));
    }
  });

  test('the marks float just above the shell, never sink into it', () {
    for (final type in [PokeBallType.great, PokeBallType.ultra]) {
      final shell = buildPokeBall(type)[BallSurface.shell]!;
      final mark = type == PokeBallType.great
          ? BallPalette.red
          : BallPalette.yellow;
      var marks = 0;
      for (var t = 0; t < shell.indices.length; t += 3) {
        final [i, j, k] = shell.indices.sublist(t, t + 3);
        if (_color(shell, i) != mark) continue;
        marks++;
        // El punto medio de un triángulo plano es lo más hundido que tiene.
        final center =
            (_vertex(shell, i) + _vertex(shell, j) + _vertex(shell, k))
              ..scale(1 / 3);
        expect(center.length, greaterThan(1.001), reason: '$type, tri $t');
        expect(center.y, greaterThan(0)); // solo en la tapa
      }
      expect(marks, greaterThan(100));
    }
  });

  test('the whole ball fits its radius and stays light', () {
    for (final type in PokeBallType.values) {
      final ball = buildPokeBall(type, radius: 0.5);
      expect(_triangles(ball), lessThanOrEqualTo(2000), reason: '$type');
      for (final piece in ball.values) {
        for (var i = 0; i < piece.vertexCount; i++) {
          // Lo más alejado es el borde del botón: (0.17, 1.07) → 1.083 R.
          expect(_vertex(piece, i).length, lessThanOrEqualTo(0.5 * 1.085));
        }
      }
    }
  });

  test('the button sits in front (+Z) and belongs to the base', () {
    final parts = buildPokeBallParts(PokeBallType.poke);
    expect(parts.top.keys, {BallSurface.shell, BallSurface.matte});
    expect(parts.bottom.keys, BallSurface.values.toSet());
    final button = parts.bottom[BallSurface.button]!;
    for (var i = 0; i < button.vertexCount; i++) {
      final v = _vertex(button, i);
      expect(v.z, greaterThan(1));
      expect(v.x * v.x + v.y * v.y, lessThanOrEqualTo(0.17 * 0.17 + 1e-6));
    }
  });

  test('split ball: all triangles kept, the lid hangs from the back hinge', () {
    for (final type in PokeBallType.values) {
      final parts = buildPokeBallParts(type);
      expect(
        _triangles(parts.top) + _triangles(parts.bottom),
        _triangles(buildPokeBall(type)),
      );
    }
    final parts = buildPokeBallParts(PokeBallType.great, radius: 2);
    expect(parts.hinge, Vector3(0, 0, -0.975 * 2));
    // La tapa está movida hacia delante: su canto de corte trasero queda
    // en la bisagra (solo la carcasa asoma un poco por detrás).
    var minZ = double.infinity;
    for (final piece in parts.top.values) {
      for (var i = 0; i < piece.vertexCount; i++) {
        final z = _vertex(piece, i).z;
        if (z < minZ) minZ = z;
      }
    }
    // Lo más atrasado es la carcasa junto a la franja: z = −√(1 − 0.075²).
    expect(minZ, closeTo((0.975 - math.sqrt(1 - 0.075 * 0.075)) * 2, 1e-4));
  });

  test('shiny plastic shell, matte band, the button is the shiniest', () {
    for (final type in PokeBallType.values) {
      final shell = BallSurface.shell.roughnessFor(type);
      expect(shell, lessThan(BallSurface.matte.roughnessFor(type)));
      expect(BallSurface.button.roughnessFor(type), lessThan(shell));
    }
  });

  test('the glow beam fades out towards the top', () {
    final beam = buildGlowBeam(Vector4(1, 1, 1, 0.5), height: 2);
    for (var v = 0; v < beam.vertexCount; v++) {
      final y = beam.positions[v * 3 + 1];
      final alpha = beam.colors[v * 4 + 3];
      expect(alpha, y > 1 ? 0 : 0.5);
    }
  });
}
