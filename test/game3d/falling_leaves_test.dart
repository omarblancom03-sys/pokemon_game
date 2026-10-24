// PRUEBAS de las HOJAS QUE CAEN: los árboles otoñales cercanos sueltan
// hojas (muchas más con las ráfagas; los lejanos, ninguna), cada hoja baja
// balanceándose sin dar saltos, el viento la arrastra, se posa plana y
// acaba desapareciendo; y una bola que sacude un árbol de hojas suelta un
// puñado (verdes en el árbol redondo; el pino, nada).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/capture/capture_calculator.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  final field = TreeField.fromLayout(
    MapLayout.parse(const ['A.P', '.@.', 'T..']),
    2,
    outerRing: 0,
  );
  Tree treeOf(TreeKind kind) => field.trees.firstWhere((t) => t.kind == kind);
  final autumn = treeOf(TreeKind.autumn);
  final near = Vector3(autumn.x + 3, 0, autumn.z);

  FallingLeafSystem system() => FallingLeafSystem(field, random: Random(1));

  /// Un instante en el que al árbol otoñal le llega una ráfaga fuerte
  /// ([strong]) o en el que está en calma.
  double timeWith({required bool strong}) {
    for (var t = 0.0; t < 120; t += 0.05) {
      final g = Wind.gustAt(t, autumn.x, autumn.z);
      if (strong ? g > 0.8 : g < 0.05) return t;
    }
    throw StateError('no gust found');
  }

  /// Avanza [seconds] con el viento congelado en [time].
  void run(
    FallingLeafSystem s,
    double seconds, {
    double time = 0,
    Vector3? at,
  }) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60, time: time, player: at ?? near);
    }
  }

  test('autumn trees drop many more leaves in a gust than in the calm', () {
    final gusty = system();
    run(gusty, 60, time: timeWith(strong: true));
    final calm = system();
    run(calm, 60, time: timeWith(strong: false));
    expect(gusty.dropped, greaterThan(40));
    expect(calm.dropped, inInclusiveRange(1, 20));
    expect(
      FallingLeafSystem.dropRate(1),
      FallingLeafSystem.calmRate + FallingLeafSystem.gustRate,
    );
  });

  test('only the trees near the player drop leaves; green ones never', () {
    final s = system();
    final far = Vector3(autumn.x + FallingLeafSystem.activeRadius + 5, 0, 0);
    run(s, 30, time: timeWith(strong: true), at: far);
    expect(s.dropped, 0);
    run(s, 30, time: timeWith(strong: true));
    expect(s.leaves, isNotEmpty);
    expect(s.leaves.every((l) => l.from == TreeKind.autumn), isTrue);
  });

  test('a leaf swings down without jumps, lands flat and then goes', () {
    final s = system()..shake(autumn, TreeField.maxKnock);
    final leaf = s.leaves.first;
    final last = leaf.position.clone();
    final tilts = <double>[];
    var maxStep = 0.0;
    while (!leaf.landed) {
      s.update(1 / 60, time: 0, player: near);
      maxStep = max(maxStep, leaf.position.distanceTo(last));
      last.setFrom(leaf.position);
      tilts.add(leaf.tilt);
      expect(leaf.age, lessThan(10), reason: 'it should land');
    }
    // Ni siquiera al salir (con el empujón del golpe) da saltos.
    expect(maxStep, lessThan(0.1));
    // Se ladea a un lado y al otro mientras cae.
    expect(tilts.reduce(max), greaterThan(0.3));
    expect(tilts.reduce(min), lessThan(-0.3));
    // En el suelo, plana y quieta; luego se encoge y desaparece.
    expect(leaf.position.y, closeTo(FallingLeafSystem.groundY, 1e-6));
    expect(leaf.tilt, 0);
    final rest = leaf.position.clone();
    s.update(FallingLeafSystem.restTime - 0.1, time: 0, player: near);
    expect(leaf.position, rest);
    expect(leaf.scale, 1);
    s.update(0.4, time: 0, player: near);
    expect(leaf.scale, inExclusiveRange(0, 1));
    s.update(FallingLeafSystem.shrinkTime, time: 0, player: near);
    expect(s.leaves, isNot(contains(leaf)));
  });

  test('the wind carries falling leaves downwind', () {
    final s = system();
    final time = timeWith(strong: true);
    final landedX = <double>[];
    for (var t = 0.0; t < 30 && landedX.length < 8; t += 1 / 60) {
      s.update(1 / 60, time: time, player: near);
      for (final l in s.leaves) {
        if (l.landedFor == 0) landedX.add(l.position.x);
      }
    }
    expect(landedX.length, greaterThanOrEqualTo(8));
    final meanDrift =
        landedX.reduce((a, b) => a + b) / landedX.length - autumn.x;
    expect(meanDrift, greaterThan(1)); // el viento va hacia +X
  });

  test('a knock drops a handful: more when harder, green from round trees, '
      'none from pines', () {
    final s = system();
    expect(s.shake(autumn, TreeField.maxKnock), FallingLeafSystem.knockLeaves);
    expect(
      s.shake(treeOf(TreeKind.round), 0.01),
      FallingLeafSystem.minKnockLeaves,
    );
    expect(s.shake(treeOf(TreeKind.pine), TreeField.maxKnock), 0);
    final leaves = s.leaves;
    expect(leaves, hasLength(15));
    expect(leaves.where((l) => l.from == TreeKind.round), hasLength(3));
    // Salen de la copa del árbol.
    final round = treeOf(TreeKind.round);
    for (final l in leaves.skip(12)) {
      expect(
        l.position.distanceTo(round.crown),
        lessThan(round.crownRadius * 1.5),
      );
    }
  });

  test('never more than maxLeaves at once', () {
    final s = system();
    for (var i = 0; i < 10; i++) {
      s.shake(autumn, TreeField.maxKnock);
    }
    expect(s.leaves, hasLength(FallingLeafSystem.maxLeaves));
    expect(s.dropped, 10 * FallingLeafSystem.knockLeaves);
  });

  test('a ball thrown at a round tree shakes green leaves off it', () {
    final s = World3DSim(
      layout: MapLayout.parse(const [
        'TTTTTTTTTTTT',
        'T..........T',
        'T..@...T...T',
        'T..........T',
        'TTTTTTTTTTTT',
      ]),
      maxFieldItems: 0,
      calculator: CaptureCalculator(random: Random(1)),
    )..camera.yaw = -pi / 2; // mirando a +X, hacia el árbol
    s.throwBall(PokeBallType.poke);
    for (var t = 0.0; t < 2; t += 1 / 60) {
      s.update(1 / 60);
    }
    final green = s.fallingLeaves.leaves.where((l) => l.from == TreeKind.round);
    expect(
      green.length,
      greaterThanOrEqualTo(FallingLeafSystem.minKnockLeaves),
    );
  });
}
