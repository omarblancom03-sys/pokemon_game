// PRUEBAS de la cámara en tercera persona: posición del ojo según
// yaw/pitch/distancia, límites de inclinación y zoom, ejes adelante/derecha
// que no se meta dentro de árboles ni casas y que se recentre detrás del
// jugador (suave, por el camino corto; girarla a mano lo cancela).

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game3d/sim/orbit_camera.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('with yaw 0 the eye sits behind (+Z) and above the player', () {
    final camera = OrbitCamera(pitch: 0.5, distance: 10);
    final eye = camera.eyeFor(Vector3.zero());

    expect(eye.x, closeTo(0, 1e-5));
    expect(eye.y, closeTo(camera.targetHeight + math.sin(0.5) * 10, 1e-5));
    expect(eye.z, closeTo(math.cos(0.5) * 10, 1e-5));
  });

  test('the eye is always [distance] away from the target', () {
    final camera = OrbitCamera(yaw: 1.1, pitch: 0.8, distance: 6);
    final feet = Vector3(4, 0, -2);

    expect(
      camera.eyeFor(feet).distanceTo(camera.targetFor(feet)),
      closeTo(6, 1e-4),
    );
  });

  test('pitch and distance are clamped', () {
    final camera = OrbitCamera()
      ..rotate(0, 10)
      ..zoom(100);
    expect(camera.pitch, camera.maxPitch);
    expect(camera.distance, camera.maxDistance);

    camera
      ..rotate(0, -10)
      ..zoom(-100);
    expect(camera.pitch, camera.minPitch);
    expect(camera.distance, camera.minDistance);
  });

  test('yaw wraps around instead of growing forever', () {
    final camera = OrbitCamera()..rotate(7 * math.pi, 0);
    expect(camera.yaw.abs(), lessThanOrEqualTo(math.pi + 1e-9));
    expect(camera.yaw.abs(), closeTo(math.pi, 1e-9));
  });

  test('forward points from the camera to the player', () {
    final camera = OrbitCamera(yaw: 0.7);
    final feet = Vector3.zero();
    final toPlayer = camera.targetFor(feet) - camera.eyeFor(feet)
      ..y = 0
      ..normalize();

    expect(camera.forward.dot(toPlayer), closeTo(1, 1e-5));
    expect(camera.forward.dot(camera.right), closeTo(0, 1e-6));
    expect(camera.right.length, closeTo(1, 1e-6));
  });

  test('project: the look-at point is the screen center; right is right', () {
    final camera = OrbitCamera(yaw: 0.4, pitch: 0.5);
    final feet = Vector3(3, 0, -2);
    final center = camera.project(camera.targetFor(feet), feet, aspect: 1.6)!;
    expect(center.x, closeTo(0, 1e-5));
    expect(center.y, closeTo(0, 1e-5));

    final right = camera.project(
      camera.targetFor(feet) + camera.right,
      feet,
      aspect: 1.6,
    )!;
    expect(right.x, greaterThan(0.05));
    final up = camera.project(
      camera.targetFor(feet) + Vector3(0, 1, 0),
      feet,
      aspect: 1.6,
    )!;
    expect(up.y, greaterThan(0.05));

    // Detrás de la cámara no se ve.
    final behind = camera.eyeFor(feet) - camera.lookDirection(feet) * 2;
    expect(camera.project(behind, feet, aspect: 1.6), isNull);
  });

  test('aim moves the camera closer and over the right shoulder', () {
    final camera = OrbitCamera();
    final feet = Vector3.zero();
    final before = camera.targetFor(feet);
    for (var i = 0; i < 60; i++) {
      camera.updateAim(1 / 60, aiming: true);
    }
    expect(camera.aim, greaterThan(0.99));
    expect(camera.effectiveDistance, closeTo(camera.distance / 2, 0.05));
    expect(
      (camera.targetFor(feet) - before).dot(camera.right),
      greaterThan(0.6),
    );
  });

  group('avoidObstacles', () {
    // Una "pared" de 5 m de alto a partir de z = 3 (detrás del jugador,
    // que está en el origen y tiene la cámara en +Z con yaw 0).
    double wall(double x, double z) => z >= 3 ? 5 : 0;
    double nothing(double x, double z) => 0;

    test('with nothing behind, the camera keeps its distance', () {
      final camera = OrbitCamera(pitch: 0.3, distance: 8)
        ..avoidObstacles(Vector3.zero(), nothing, 1 / 60);
      expect(camera.obstructedDistance, isNull);
      expect(camera.effectiveDistance, 8);
    });

    test('a wall behind pulls the eye in at once, out of the wall', () {
      final camera = OrbitCamera(pitch: 0.3, distance: 8)
        ..avoidObstacles(Vector3.zero(), wall, 1 / 60);
      expect(camera.eyeFor(Vector3.zero()).z, lessThan(3));
      expect(camera.effectiveDistance, lessThan(8));
    });

    test('low obstacles (a fence) do not bother a camera above them', () {
      final camera = OrbitCamera(pitch: 0.3, distance: 8)
        ..avoidObstacles(Vector3.zero(), (x, z) => z >= 3 ? 1 : 0, 1 / 60);
      expect(camera.obstructedDistance, isNull);
    });

    test('never closer than minClearDistance, even inside a wall', () {
      final camera = OrbitCamera(pitch: 0.3, distance: 8)
        ..avoidObstacles(Vector3.zero(), (x, z) => 5, 1 / 60);
      expect(camera.effectiveDistance, OrbitCamera.minClearDistance);
    });

    test('when the wall is gone it backs off smoothly, not in one jump', () {
      final camera = OrbitCamera(pitch: 0.3, distance: 8)
        ..avoidObstacles(Vector3.zero(), wall, 1 / 60);
      final blocked = camera.effectiveDistance;

      camera.avoidObstacles(Vector3.zero(), nothing, 0.1);
      expect(
        camera.effectiveDistance,
        closeTo(blocked + OrbitCamera.clearRecoverSpeed * 0.1, 1e-9),
      );

      for (var i = 0; i < 120; i++) {
        camera.avoidObstacles(Vector3.zero(), nothing, 1 / 60);
      }
      expect(camera.obstructedDistance, isNull);
      expect(camera.effectiveDistance, 8);
    });

    test('with its back to a tall wall it rises to look from above', () {
      // Pared de 4 m pegada al jugador (a 0,4 m): detrás no cabe la cámara.
      double close(double x, double z) => z >= 0.4 ? 4 : 0;
      final camera = OrbitCamera(pitch: 0.4, distance: 7);
      for (var i = 0; i < 120; i++) {
        camera.avoidObstacles(Vector3.zero(), close, 1 / 60);
      }
      expect(camera.pitchLift, greaterThan(0.5));
      expect(
        camera.effectivePitch,
        lessThanOrEqualTo(OrbitCamera.maxLiftedPitch),
      );
      // La inclinación elegida por el jugador no cambia (la usa el tiro).
      expect(camera.pitch, 0.4);
      final eye = camera.eyeFor(Vector3.zero());
      expect(eye.y, greaterThan(close(eye.x, eye.z)));

      // Lejos de la pared vuelve a bajar poco a poco.
      camera.avoidObstacles(Vector3.zero(), nothing, 1 / 60);
      expect(camera.pitchLift, greaterThan(0.4));
      for (var i = 0; i < 240; i++) {
        camera.avoidObstacles(Vector3.zero(), nothing, 1 / 60);
      }
      expect(camera.pitchLift, lessThan(0.01));
    });

    test('aiming uses the shorter aim distance for the check', () {
      // Apuntando la cámara está a 4 m (la mitad): una pared a 6 m no estorba.
      final camera = OrbitCamera(pitch: 0.3, distance: 8)..aim = 1;
      camera.avoidObstacles(Vector3.zero(), (x, z) => z >= 6 ? 5 : 0, 1 / 60);
      expect(camera.obstructedDistance, isNull);
      expect(camera.effectiveDistance, 4);
    });
  });

  group('recenter behind the player', () {
    /// Adelante del jugador que mira hacia [facing] (misma convención que
    /// PlayerBody: 0 = hacia +Z).
    Vector3 facingDir(double facing) =>
        Vector3(math.sin(facing), 0, math.cos(facing));

    void run(OrbitCamera c, double seconds) {
      for (var t = 0.0; t < seconds; t += 1 / 60) {
        c.updateRecenter(1 / 60);
      }
    }

    test('ends up looking where the player looks, smoothly', () {
      for (final facing in [0.0, 1.0, -2.5, math.pi]) {
        final camera = OrbitCamera(yaw: 0.3)..recenterBehind(facing);
        camera.updateRecenter(1 / 60);
        // Un fotograma no basta: gira poco a poco.
        expect(camera.forward.dot(facingDir(facing)), lessThan(0.9999));
        run(camera, 1);
        expect(camera.forward.dot(facingDir(facing)), closeTo(1, 1e-6));
        expect(camera.recenterGoal, isNull, reason: 'done');
      }
    });

    test('takes the short way round (across ±π)', () {
      // De 3,0 a -3,0 rad: por π son 0,28 rad; por 0 serían 6.
      final camera = OrbitCamera(yaw: 3)..recenterBehind(-3 + math.pi);
      var maxAway = 0.0;
      for (var t = 0.0; t < 1; t += 1 / 60) {
        camera.updateRecenter(1 / 60);
        maxAway = math.max(maxAway, (camera.yaw.abs() - math.pi).abs());
      }
      expect(maxAway, lessThan(0.3));
      expect(camera.yaw, closeTo(-3, 1e-9));
    });

    test('turning it by hand cancels the recenter; zoom does not', () {
      final camera = OrbitCamera()
        ..recenterBehind(1)
        ..zoom(1)
        ..rotate(0, 0.1);
      expect(camera.recenterGoal, isNotNull);
      camera.rotate(0.05, 0);
      expect(camera.recenterGoal, isNull);
      final yaw = camera.yaw;
      run(camera, 0.5);
      expect(camera.yaw, yaw);
    });

    test('only the yaw changes: the chosen pitch stays', () {
      final camera = OrbitCamera(pitch: 0.9)..recenterBehind(2);
      run(camera, 1);
      expect(camera.pitch, 0.9);
    });
  });

  group('breathing with your stance', () {
    test('running pulls it back a little', () {
      final camera = OrbitCamera(distance: 8);
      camera.stance = 1;
      expect(
        camera.effectiveDistance,
        closeTo(8 * (1 + OrbitCamera.runPullBack), 1e-9),
      );
    });

    test('crouching brings it closer and lower', () {
      final camera = OrbitCamera(distance: 8);
      final feet = Vector3.zero();
      final standing = camera.targetFor(feet).y;
      camera.stance = -1;
      expect(
        camera.effectiveDistance,
        closeTo(8 * (1 - OrbitCamera.crouchPullIn), 1e-9),
      );
      expect(
        camera.targetFor(feet).y,
        closeTo(standing - OrbitCamera.crouchDrop, 1e-6),
      );
    });
  });
}
