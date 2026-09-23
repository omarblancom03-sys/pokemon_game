// PRUEBAS de la simulación 3D: el jugador empieza en `@`, se mueve relativo a
// la cámara, choca con los árboles del mapa ASCII, y la cámara responde al
// arrastre del ratón, a Q/E y a la rueda. En pausa no se mueve.

import 'dart:math' as math;

import 'package:flame/extensions.dart' show Vector2;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';

void main() {
  final layout = MapLayout.parse(const [
    'TTTTTTT',
    'T.....T',
    'T.....T',
    'T..@..T',
    'T.....T',
    'TTTTTTT',
  ]);

  World3DSim sim() => World3DSim(layout: layout);

  void step(World3DSim s, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60);
    }
  }

  test('the player starts at the center of the @ cell', () {
    final s = sim();
    expect(s.player.position.x, closeTo(3.5 * 2, 1e-6));
    expect(s.player.position.z, closeTo(3.5 * 2, 1e-6));
    expect(s.width, 14);
    expect(s.depth, 12);
  });

  test('"up" moves away from the camera (camera yaw 0 means -Z)', () {
    final s = sim();
    final start = s.player.position;
    s.input.setKeyboardDirection(Vector2(0, -1));
    step(s, 0.3);

    expect(s.player.position.z, lessThan(start.z));
    expect(s.player.position.x, closeTo(start.x, 1e-6));
  });

  test('movement follows the camera when it rotates', () {
    final s = sim();
    s.camera.yaw = math.pi / 2; // cámara en +X mirando hacia -X
    final start = s.player.position;
    s.input.setKeyboardDirection(Vector2(0, -1));
    step(s, 0.3);

    expect(s.player.position.x, lessThan(start.x));
    expect(s.player.position.z, closeTo(start.z, 1e-3));
  });

  test('trees block the player', () {
    final s = sim();
    s.input.setKeyboardDirection(Vector2(0, -1));
    step(s, 5);

    // La fila 0 son árboles: el borde del jugador no entra en z < 2.
    expect(
      s.player.position.z - s.config.playerRadius,
      greaterThanOrEqualTo(2),
    );
  });

  test('dragging the mouse and Q/E rotate the camera; wheel zooms', () {
    final s = sim();
    final yaw0 = s.camera.yaw;
    s.cameraInput.addDrag(-100, 0);
    s.update(1 / 60);
    expect(s.camera.yaw, greaterThan(yaw0));

    final yaw1 = s.camera.yaw;
    s.cameraInput.updateFromKeys({LogicalKeyboardKey.keyE});
    s.update(0.1);
    expect(s.camera.yaw, greaterThan(yaw1));

    final d0 = s.camera.distance;
    s.cameraInput.addZoom(2);
    s.update(1 / 60);
    expect(s.camera.distance, d0 + 2);
    // El zoom se consume: no se vuelve a aplicar.
    s.update(1 / 60);
    expect(s.camera.distance, d0 + 2);
  });

  test('when input is disabled (paused) the player does not move', () {
    final s = sim();
    final start = s.player.position;
    s.input
      ..setKeyboardDirection(Vector2(1, 0))
      ..enabled = false;
    step(s, 1);
    expect(s.player.position, start);
  });

  test('cellAt maps world meters back to map cells', () {
    final s = sim();
    expect(s.cellAt(s.cellCenter(5, 2)), (col: 5, row: 2));
  });
}
