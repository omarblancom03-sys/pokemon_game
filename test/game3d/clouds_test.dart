// PRUEBAS de las nubes: pasan con el viento y, al salir de su zona por un
// lado, vuelven a entrar por el otro; la nube está en la línea del sol que
// pasa por su sombra; las lejanas están lo bastante lejos y altas para
// verse sobre el bosque; la sombra mira hacia arriba y se difumina en el
// borde; y en pausa no se mueven.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/mesh/cloud_mesh.dart';
import 'package:pokemon_game/game3d/sim/clouds.dart';
import 'package:pokemon_game/game3d/sim/world3d_config.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  CloudLayer layer() => CloudLayer(width: 60, depth: 40, random: Random(3));

  test('there are near clouds (with shadow) and far ones (to be seen)', () {
    final l = layer();
    expect(l.clouds, hasLength(16));
    expect(l.farClouds, hasLength(30));
    for (final c in l.clouds) {
      expect(c.shadow.y, 0);
      expect(c.shadow.x, inInclusiveRange(-45, 105));
      expect(c.shadow.z, inInclusiveRange(-45, 85));
    }
    // Varias lejanas quedan a más de 110 m del centro del mapa: esas son
    // las que asoman por encima del bosque.
    final center = Vector3(30, 0, 20);
    final seen = l.farClouds.where(
      (c) => CloudLayer.skyOf(c).xz.distanceTo(center.xz) > 110,
    );
    expect(seen.length, greaterThan(10));
    for (final c in l.farClouds) {
      expect(c.height, inInclusiveRange(50, 80));
    }
  });

  test('they drift with the wind', () {
    final l = layer();
    final before = [for (final c in l.clouds) c.shadow.clone()];
    l.update(2);
    for (var i = 0; i < l.clouds.length; i++) {
      final moved = l.clouds[i].shadow - before[i];
      if (moved.length > 50) continue; // dio la vuelta
      expect(moved.x, closeTo(CloudLayer.wind.x * 2, 1e-4));
      expect(moved.z, closeTo(CloudLayer.wind.z * 2, 1e-4));
    }
  });

  test('leaving on one side they come back on the other, forever', () {
    final l = layer();
    var wrapped = false;
    for (var t = 0; t < 200; t++) {
      final xs = [for (final c in l.clouds) c.shadow.x];
      l.update(1);
      for (var i = 0; i < l.clouds.length; i++) {
        final c = l.clouds[i];
        if (c.shadow.x < xs[i]) wrapped = true;
        expect(c.shadow.x, lessThanOrEqualTo(60 + CloudLayer.nearReach));
        expect(c.shadow.z, lessThanOrEqualTo(40 + CloudLayer.nearReach));
        expect(c.shadow.x, greaterThanOrEqualTo(-CloudLayer.nearReach - 2));
      }
    }
    expect(wrapped, isTrue);
    expect(l.clouds, hasLength(16));
  });

  test('the cloud sits on the sun ray that goes through its shadow', () {
    final sun = World3DConfig.sunDirection;
    for (final c in layer().clouds) {
      final sky = CloudLayer.skyOf(c);
      expect(sky.y, closeTo(c.height, 1e-4));
      // Siguiendo la luz desde la nube se llega a la sombra.
      final ground = sky + sun * (sky.y / -sun.y);
      expect(ground.x, closeTo(c.shadow.x, 1e-4)); // float32
      expect(ground.y, closeTo(0, 1e-4));
      expect(ground.z, closeTo(c.shadow.z, 1e-4));
    }
  });

  test('the shadow faces up and fades out at the rim', () {
    final m = buildCloudShadow();
    var centerAlpha = 0.0;
    for (var i = 0; i < m.vertexCount; i++) {
      expect(m.normals[i * 3 + 1], closeTo(1, 1e-6), reason: 'faces up');
      final x = m.positions[i * 3];
      final z = m.positions[i * 3 + 2];
      final r = sqrt(x * x + z * z);
      final alpha = m.colors[i * 4 + 3];
      if (r < 1e-6) centerAlpha = alpha;
      if ((r - 1).abs() < 1e-6) expect(alpha, 0, reason: 'soft rim');
      expect(r, lessThanOrEqualTo(1 + 1e-6));
    }
    expect(centerAlpha, greaterThan(0.5));
    expect(buildCloud().isEmpty, isFalse);
  });

  test('in the world they move, but not while the world is frozen', () {
    final s = World3DSim(
      layout: MapLayout.parse(['TTTT', 'T@.T', 'TTTT']),
      random: Random(1),
      maxFieldItems: 0,
    );
    final first = s.clouds.clouds.first;
    final x = first.shadow.x;
    s.update(1);
    expect(first.shadow.x, greaterThan(x));
    s.setPaused(true);
    final frozen = first.shadow.x;
    s.update(1);
    expect(first.shadow.x, frozen);
  });
}
