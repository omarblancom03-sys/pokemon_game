// PRUEBAS de las HUELLAS: cada pisada en la tierra del camino deja una
// huella en el suelo que apunta hacia donde ibas; corriendo se marca más y
// agachado menos; se borran poco a poco y desaparecen; nunca hay más de
// maxPrints; en las losas, el césped o la hierba alta no quedan.

import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/mesh/footprint_mesh.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('FootprintTrail', () {
    test('a print lies on the ground, pointing where you went', () {
      final trail = FootprintTrail()
        ..step(Vector3(3, 0.4, 5), 1.2, depth: FootprintTrail.runDepth);
      final p = trail.prints.single;
      expect(p.position, Vector3(3, 0, 5));
      expect(p.facing, 1.2);
      expect(p.opacity, FootprintTrail.runDepth);
    });

    test('it stays sharp, then fades out and disappears', () {
      final trail = FootprintTrail()..step(Vector3.zero(), 0);
      const sharp = FootprintTrail.life - FootprintTrail.fadeTime;
      trail.update(sharp - 1);
      expect(trail.prints.single.opacity, FootprintTrail.walkDepth);
      trail.update(1 + FootprintTrail.fadeTime / 2);
      expect(
        trail.prints.single.opacity,
        closeTo(FootprintTrail.walkDepth / 2, 1e-9),
      );
      trail.update(FootprintTrail.fadeTime / 2 + 0.01);
      expect(trail.prints, isEmpty);
    });

    test('never more than maxPrints (the oldest go first)', () {
      final trail = FootprintTrail();
      for (var i = 0; i < FootprintTrail.maxPrints + 10; i++) {
        trail.step(Vector3(i.toDouble(), 0, 0), 0);
      }
      expect(trail.prints, hasLength(FootprintTrail.maxPrints));
      expect(trail.prints.first.position.x, 10);
    });

    test('running marks deeper than walking; crouching, the least', () {
      double depth({bool running = false, bool crouching = false}) =>
          FootprintTrail.depthFor(running: running, crouching: crouching);
      expect(depth(running: true), greaterThan(depth()));
      expect(depth(crouching: true), lessThan(depth()));
      // Agachado manda, aunque la velocidad fuera de carrera.
      expect(depth(running: true, crouching: true), depth(crouching: true));
    });
  });

  test('the print mesh is flat on the ground, facing up, toe to +Z', () {
    final mesh = buildFootprint();
    expect(mesh.positions, isNotEmpty);
    var minZ = double.infinity, maxZ = -double.infinity;
    for (var i = 0; i < mesh.positions.length; i += 3) {
      expect(mesh.positions[i + 1], 0);
      minZ = min(minZ, mesh.positions[i + 2]);
      maxZ = max(maxZ, mesh.positions[i + 2]);
    }
    expect(maxZ - minZ, closeTo(0.24, 0.02));
    // La suela (delante, más ancha) va hacia +Z.
    expect(maxZ.abs(), greaterThan(minZ.abs()));
    for (var i = 0; i < mesh.normals.length; i += 3) {
      expect(mesh.normals[i + 1], closeTo(1, 1e-6));
    }
  });

  group('in the world', () {
    // Fila 3: el jugador en el césped (1), camino de tierra (2..15),
    // losas (16..21) y césped (22..28).
    final layout = MapLayout.parse([
      'T' * 30,
      for (var row = 1; row < 6; row++)
        row == 3 ? 'T@${'=' * 14}${'o' * 6}${'.' * 7}T' : 'T${'.' * 28}T',
      'T' * 30,
    ]);

    // Ya mirando al este (el giro es suave: si no, las primeras huellas
    // saldrían torcidas).
    World3DSim world() =>
        World3DSim(layout: layout, random: Random(1), maxFieldItems: 0)
          ..player.facing = pi / 2;

    void walk(World3DSim s, double seconds) {
      for (var t = 0.0; t < seconds; t += 1 / 60) {
        s.update(1 / 60);
      }
    }

    test('walking along the dirt path leaves a print per step, on both '
        'sides', () {
      final s = world()..player.teleport(Vector3(5, 0, 7));
      s.input.setKeyboardDirection(Vector2(1, 0));
      final x0 = s.player.position.x;
      walk(s, 2);
      final walked = s.player.position.x - x0;
      final prints = s.footprints.prints;
      expect(prints.length, closeTo(walked / World3DSim.footstepSpacing, 1.5));
      // Una a cada lado de por donde pasó, apuntando hacia +X.
      expect(prints.map((p) => p.position.z > 7).toSet(), {true, false});
      for (final p in prints) {
        expect((p.position.z - 7).abs(), closeTo(0.12, 0.02));
        expect(p.facing, closeTo(pi / 2, 0.05));
        expect(p.depth, FootprintTrail.walkDepth);
      }
    });

    test('running marks deeper; crouching, lighter', () {
      final runner = world()..player.teleport(Vector3(5, 0, 7));
      runner.input.setKeyboardDirection(Vector2(1, 0));
      runner.cameraInput.updateFromKeys({LogicalKeyboardKey.shiftLeft});
      walk(runner, 1);
      expect(
        runner.footprints.prints.map((p) => p.depth),
        everyElement(FootprintTrail.runDepth),
      );

      final sneaker = world()
        ..player.teleport(Vector3(5, 0, 7))
        ..crouching = true;
      sneaker.input.setKeyboardDirection(Vector2(1, 0));
      walk(sneaker, 2);
      expect(sneaker.footprints.prints, isNotEmpty);
      expect(
        sneaker.footprints.prints.map((p) => p.depth),
        everyElement(FootprintTrail.crouchDepth),
      );
    });

    test('no prints on the stone slabs or the lawn', () {
      final s = world()..player.teleport(s0(16.2));
      s.input.setKeyboardDirection(Vector2(1, 0));
      walk(s, 5);
      expect(s.player.position.x, greaterThan(22 * 2.0 + 2));
      expect(s.footprints.prints, isEmpty);
      expect(s.isDirtPath(s.cellCenter(5, 3)), isTrue);
      expect(s.isDirtPath(s.cellCenter(17, 3)), isFalse);
      expect(s.isDirtPath(s.cellCenter(25, 3)), isFalse);
    });

    test('left alone, the prints fade and are gone', () {
      final s = world()..player.teleport(Vector3(5, 0, 7));
      s.input.setKeyboardDirection(Vector2(1, 0));
      walk(s, 1);
      s.input.setKeyboardDirection(Vector2.zero());
      expect(s.footprints.prints, isNotEmpty);
      walk(s, FootprintTrail.life + 1);
      expect(s.footprints.prints, isEmpty);
    });
  });
}

/// En la fila 3 (z = 7 m), a [col] casillas del borde oeste.
Vector3 s0(double col) => Vector3(col * 2.0, 0, 7);
