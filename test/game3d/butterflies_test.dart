// PRUEBAS de las mariposas: nacen sobre los macizos de flores (repartidas y
// sin pasarse del máximo), revolotean sin alejarse de sus flores, aletean,
// se espantan si te acercas (desde más lejos si corres, casi nada si vas
// agachado) volando hacia arriba y lejos de ti, y al rato vuelven.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/butterflies.dart';
import 'package:pokemon_game/game3d/sim/wild_behavior.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  // Macizos de flores en las esquinas de un prado de 20 x 8 casillas.
  final layout = MapLayout.parse([
    'T' * 22,
    'T,,${'.' * 16},,T',
    for (var i = 0; i < 5; i++) 'T${i == 2 ? '@' : '.'}${'.' * 19}T',
    'T,,${'.' * 16},,T',
    'T' * 22,
  ]);

  ButterflySwarm swarm({int max = 12}) =>
      ButterflySwarm.fromLayout(layout, 2, random: Random(4), max: max);

  /// Una sola mariposa sobre las flores de (1,1).
  ButterflySwarm single() => ButterflySwarm([
    Butterfly(home: Vector3(3, 0, 3), colorIndex: 0),
  ], random: Random(5));

  void step(
    ButterflySwarm s,
    double seconds, {
    Vector3? player,
    PlayerStealth stealth = PlayerStealth.normal,
    bool moving = true,
  }) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(
        1 / 60,
        player ?? Vector3(100, 0, 100),
        stealth: stealth,
        moving: moving,
      );
    }
  }

  test('one per flower patch, spread out and never above the maximum', () {
    final s = swarm();
    expect(s.butterflies, hasLength(4)); // una por esquina
    for (final b in s.butterflies) {
      final cell = layout.tileAt(
        (b.home.x / 2).floor(),
        (b.home.z / 2).floor(),
      );
      expect(cell, TileKind.flowers);
    }
    expect(swarm(max: 2).butterflies, hasLength(2));
  });

  test('calm butterflies flutter over their flowers and flap', () {
    final s = single();
    final b = s.butterflies.single;
    final wings = <double>{};
    for (var i = 0; i < 600; i++) {
      step(s, 1 / 60);
      final flat = Vector3(b.position.x - 3, 0, b.position.z - 3);
      expect(flat.length, lessThan(ButterflySwarm.wanderRadius + 0.1));
      expect(b.position.y, inInclusiveRange(0.3, 1.4));
      wings.add((b.wingAngle * 10).roundToDouble());
    }
    expect(wings.length, greaterThan(3)); // las alas se mueven
    expect(b.isScared, isFalse);
  });

  test('walking up scares it: it flies up and away from you', () {
    final s = single();
    final b = s.butterflies.single;
    final player = b.position.clone()
      ..y = 0
      ..x -= 2; // a 2 m, por su izquierda (-X)
    step(s, 1 / 60, player: player);
    expect(b.isScared, isTrue);

    step(s, 1, player: player);
    expect(b.position.x, greaterThan(player.x + 3));
    expect(b.position.y, greaterThan(1.5));
  });

  test('running scares from farther; crouching lets you get close', () {
    final far = ButterflySwarm.scareDistance(PlayerStealth.noisy);
    final walk = ButterflySwarm.scareDistance(PlayerStealth.normal);
    final crouch = ButterflySwarm.scareDistance(PlayerStealth.crouching);
    expect(far, greaterThan(walk));
    expect(walk, greaterThan(crouch));

    final s = single();
    final b = s.butterflies.single;
    // Agachado a 1,6 m: no se entera.
    step(
      s,
      1 / 60,
      player: Vector3(b.position.x - 1.6, 0, b.position.z),
      stealth: PlayerStealth.crouching,
    );
    expect(b.isScared, isFalse);
    // Quieto a 1 m tampoco.
    step(
      s,
      1 / 60,
      player: Vector3(b.position.x - 1, 0, b.position.z),
      moving: false,
    );
    expect(b.isScared, isFalse);
  });

  test('after fleeing it comes back to its flowers', () {
    final s = single();
    final b = s.butterflies.single;
    step(s, 1 / 60, player: b.position.clone()..y = 0);
    expect(b.isScared, isTrue);
    step(s, 3);
    expect(b.isScared, isFalse);
    step(s, 20);
    final flat = Vector3(b.position.x - 3, 0, b.position.z - 3);
    expect(flat.length, lessThan(ButterflySwarm.wanderRadius + 0.1));
  });
}
