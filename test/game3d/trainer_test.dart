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

  group('throw gesture', () {
    TrainerPose throwing(double? t, {bool lob = false, double speed = 0}) =>
        TrainerPose.fromMotion(
          distanceWalked: TrainerPose.strideLength / 4,
          speed: speed,
          walkSpeed: 4.5,
          runSpeed: 7.5,
          aiming: true,
          throwProgress: t,
          lob: lob,
        );

    /// Hacia dónde apunta el brazo: (hacia delante, hacia arriba).
    (double, double) dir(double angle) => (math.sin(angle), -math.cos(angle));

    test('aiming a ball: arm up and back, the left one points ahead, '
        'right shoulder turned back', () {
      final p = throwing(null);
      final (fwd, up) = dir(p.rightArm!);
      expect(fwd, lessThan(-0.3)); // atrás
      expect(up, greaterThan(0.5)); // arriba
      expect(dir(p.leftArm!).$1, greaterThan(0.9)); // señala delante
      expect(p.twist, greaterThan(0.3));
    });

    test('a ball goes OVER the shoulder: the arm passes above the head '
        'and is up and forward when the ball leaves the hand', () {
      const release = 0.18 / 0.5; // World3DSim.releaseTime / throwDuration
      var last = throwing(0).rightArm!;
      var overHead = false;
      for (var t = 0.0; t <= 1; t += 1 / 30) {
        final a = throwing(t).rightArm!;
        expect(a, lessThanOrEqualTo(last + 1e-9), reason: 'never swings back');
        expect((a - last).abs(), lessThan(0.45), reason: 'no jumps');
        if (dir(a).$2 > 0.95) overHead = true;
        last = a;
      }
      expect(overHead, isTrue);
      final (fwd, up) = dir(throwing(release).rightArm!);
      expect(fwd, greaterThan(0.3));
      expect(up, greaterThan(0.3));
    });

    test('the torso turns before the arm and the left leg steps in', () {
      final start = throwing(0);
      final top = throwing(TrainerPose.peak);
      expect(start.twist, greaterThan(0.3));
      expect(top.twist, lessThan(-0.3)); // hombro derecho delante
      expect(top.lean, greaterThan(start.lean));
      // Parado: la pierna izquierda adelantada (legSwing negativo).
      final standing = TrainerPose.fromMotion(
        distanceWalked: 0,
        speed: 0,
        walkSpeed: 4.5,
        runSpeed: 7.5,
        throwProgress: TrainerPose.peak,
      );
      expect(standing.legSwing, lessThan(-0.3));
      // Andando, mandan las piernas: el paso no se suma.
      final walking = throwing(TrainerPose.peak, speed: 4.5);
      final plainWalk = pose(TrainerPose.strideLength / 4, 4.5);
      expect(walking.legSwing, closeTo(plainWalk.legSwing, 1e-9));
    });

    test('at the end everything is back at rest (arm hanging)', () {
      final end = throwing(1 - 1e-9);
      expect(math.cos(end.rightArm!), closeTo(1, 1e-6)); // colgando
      expect(end.twist.abs(), lessThan(1e-6));
      expect(end.lean, closeTo(0, 1e-6));
      final after = TrainerPose.fromMotion(
        distanceWalked: 0,
        speed: 0,
        walkSpeed: 4.5,
        runSpeed: 7.5,
        throwProgress: 1,
      );
      expect(after.rightArm, isNull);
      expect(after.leftArm, isNull);
      expect(after.twist, 0);
    });

    test('a berry is lobbed UNDERHAND: from low behind to up in front', () {
      final aim = throwing(null, lob: true);
      final (fwd, up) = dir(aim.rightArm!);
      expect(fwd, lessThan(-0.3)); // atrás
      expect(up, lessThan(0)); // abajo
      var last = aim.rightArm!;
      for (var t = 0.0; t < TrainerPose.peak; t += 1 / 30) {
        final a = throwing(t, lob: true).rightArm!;
        expect(a, greaterThanOrEqualTo(last - 1e-9));
        expect(dir(a).$2, lessThan(0.95), reason: 'never over the head');
        last = a;
      }
      final (f2, u2) = dir(throwing(0.36, lob: true).rightArm!);
      expect(f2, greaterThan(0.8)); // hacia delante, casi a la altura
      // del hombro (un globo se suelta un poco por debajo)
      expect(u2, greaterThan(-0.4));
    });
  });
}
