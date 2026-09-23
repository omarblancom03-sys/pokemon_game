// PRUEBAS de la malla de la Poké Ball: cada tipo tiene sus colores (roja,
// azul, negra por arriba; blanca por abajo), la bola partida conserva todos
// los triángulos y la tapa queda colgando de la bisagra trasera.

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game3d/mesh/ball_mesh.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  final up = Vector3(0.3, 0.9, -0.3)..normalize();
  final down = Vector3(0.3, -0.9, -0.3)..normalize();

  test('each ball type has its own top color and a white bottom', () {
    expect(pokeBallColor(PokeBallType.poke, up), BallPalette.red);
    expect(pokeBallColor(PokeBallType.great, up), BallPalette.blue);
    expect(pokeBallColor(PokeBallType.ultra, up), BallPalette.black);
    for (final type in PokeBallType.values) {
      expect(pokeBallColor(type, down), BallPalette.white);
      expect(pokeBallColor(type, Vector3(1, 0, 0)), BallPalette.band);
      expect(pokeBallColor(type, Vector3(0, 0, 1)), BallPalette.button);
    }
    // La "H" amarilla de la Ultra Ball y las alas rojas de la Super Ball.
    final side = Vector3(0.6, 0.6, 0.1)..normalize();
    expect(pokeBallColor(PokeBallType.ultra, side), BallPalette.yellow);
    expect(pokeBallColor(PokeBallType.great, side), BallPalette.red);
  });

  test('the whole ball fits its radius', () {
    final ball = buildPokeBall(PokeBallType.poke, radius: 0.5);
    expect(ball.triangleCount, 20 * 64); // icosaedro subdividido 3 veces
    for (var i = 0; i < ball.positions.length; i += 3) {
      final v = Vector3(
        ball.positions[i],
        ball.positions[i + 1],
        ball.positions[i + 2],
      );
      expect(v.length, closeTo(0.5, 1e-4));
    }
  });

  test('split ball: all triangles kept, the lid hangs from the back hinge', () {
    final whole = buildPokeBall(PokeBallType.great);
    final parts = buildPokeBallParts(PokeBallType.great);
    expect(
      parts.top.triangleCount + parts.bottom.triangleCount,
      whole.triangleCount,
    );
    expect(parts.hinge, Vector3(0, 0, -1));
    // La tapa está movida +1 en Z: su punto más atrasado queda en la bisagra.
    var minZ = double.infinity;
    for (var i = 2; i < parts.top.positions.length; i += 3) {
      minZ = parts.top.positions[i] < minZ ? parts.top.positions[i] : minZ;
    }
    expect(minZ, closeTo(0, 0.05));
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
