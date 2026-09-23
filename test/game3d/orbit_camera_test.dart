// PRUEBAS de la cámara en tercera persona: posición del ojo según
// yaw/pitch/distancia, límites de inclinación y zoom, y ejes adelante/derecha.

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
}
