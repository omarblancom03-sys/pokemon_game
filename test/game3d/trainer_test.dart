// PRUEBAS del entrenador 3D: la postura sale del movimiento real (quieto =
// sin balanceo, brazos contrarios a piernas, más inclinación al correr) y
// las piezas del modelo tienen su articulación en el origen.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game3d/mesh/mesh_builder.dart';
import 'package:pokemon_game/game3d/mesh/trainer_mesh.dart';
import 'package:pokemon_game/game3d/sim/trainer_pose.dart';

void main() {
  TrainerPose pose(double distance, double speed) => TrainerPose.fromMotion(
    distanceWalked: distance,
    speed: speed,
    walkSpeed: 4.5,
    runSpeed: 7.5,
  );

  test('standing still means no swing, bob or lean', () {
    final p = pose(3.3, 0);
    expect(p.legSwing, 0);
    expect(p.armSwing, 0);
    expect(p.bob, 0);
    expect(p.lean, 0);
  });

  test('arms swing against the legs', () {
    // Un cuarto de zancada: pierna derecha al máximo hacia delante.
    final p = pose(TrainerPose.strideLength / 4, 4.5);
    expect(p.legSwing, greaterThan(0.5));
    expect(p.armSwing, lessThan(0));
    expect(p.armSwing.sign, -p.legSwing.sign);
  });

  test('the legs swing back half a stride later', () {
    final p = pose(TrainerPose.strideLength * 3 / 4, 4.5);
    expect(p.legSwing, lessThan(-0.5));
  });

  test('running leans forward more than walking', () {
    expect(pose(1, 7.5).lean, greaterThan(pose(1, 4.5).lean));
    expect(pose(1, 7.5).lean, closeTo(0.18, 1e-9));
  });

  test('swing is bounded even at full run', () {
    for (var d = 0.0; d < 5; d += 0.1) {
      expect(pose(d, 7.5).legSwing.abs(), lessThanOrEqualTo(0.55 * 1.3));
    }
    expect(math.pi / 4, greaterThan(0.55 * 1.3)); // < 45°: natural
  });

  test('limbs hang from their joint at the origin', () {
    final parts = buildTrainerParts();

    double maxY(MeshBuffers m) {
      var y = double.negativeInfinity;
      for (var i = 0; i < m.vertexCount; i++) {
        y = math.max(y, m.positions[i * 3 + 1]);
      }
      return y;
    }

    // Todo lo de la pierna queda por debajo de la cadera (y <= 0).
    expect(maxY(parts.leg), lessThanOrEqualTo(0));
    // El brazo sube apenas sobre el hombro (la hombrera).
    expect(maxY(parts.arm), lessThanOrEqualTo(0.05));
    // La cabeza (con gorra) mide algo menos de 1.8 m.
    expect(maxY(parts.body), inInclusiveRange(1.6, 1.85));
  });
}
