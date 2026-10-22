// PRUEBAS de los ÁRBOLES que se mecen: dónde los pone el campo (los del
// mapa centrados en su casilla y el bosque del borde alrededor), las
// ráfagas de viento que avanzan con el viento, la inclinación de la copa
// (a favor del viento, acotada, el pino más rígido), la transformación
// de la copa sobre su pivote y la sacudida cuando les da una Poké Ball.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/capture/capture_calculator.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  final layout = MapLayout.parse(const ['T.P', '.@.', 'A..']);

  Tree treeOf(TreeKind kind) => TreeField.fromLayout(
    layout,
    2,
    outerRing: 0,
  ).trees.firstWhere((t) => t.kind == kind);

  group('field', () {
    test('map trees sit in the middle of their T / P / A cell', () {
      final field = TreeField.fromLayout(layout, 2, outerRing: 0);
      expect(field.trees.map((t) => (t.kind, t.col, t.row)), [
        (TreeKind.round, 0, 0),
        (TreeKind.pine, 2, 0),
        (TreeKind.autumn, 0, 2),
      ]);
      final pine = field.trees[1];
      expect(pine.x, 5);
      expect(pine.z, 1);
      expect(pine.size, 1);
      expect(pine.height, inInclusiveRange(1, 1.4));
    });

    test('a forest ring surrounds the map, always the same', () {
      final a = TreeField.fromLayout(layout, 2);
      final b = TreeField.fromLayout(layout, 2);
      const ring = 4;
      expect(a.trees.length, (3 + 2 * ring) * (3 + 2 * ring) - 9 + 3);
      for (var i = 0; i < a.trees.length; i++) {
        expect(a.trees[i].x, b.trees[i].x);
        expect(a.trees[i].kind, b.trees[i].kind);
      }
      // El bosque del borde: pinos, redondos y algún otoñal (color).
      final outer = a.trees.where((t) => !layout.contains(t.col, t.row));
      final kinds = outer.map((t) => t.kind).toSet();
      expect(kinds, containsAll(TreeKind.values));
      for (final t in outer) {
        // Cada árbol se queda dentro de su casilla aunque se desplace.
        expect(t.x, inInclusiveRange(t.col * 2.0, (t.col + 1) * 2.0));
        expect(t.z, inInclusiveRange(t.row * 2.0, (t.row + 1) * 2.0));
      }
    });

    test('treeAt finds the tree of the cell that holds a point', () {
      final field = TreeField.fromLayout(layout, 2);
      expect(field.treeAt(Vector3(1.9, 3, 0.1))?.kind, TreeKind.round);
      expect(field.treeAt(Vector3(4.5, 0, 1.5))?.kind, TreeKind.pine);
      expect(field.treeAt(Vector3(3, 0, 3)), isNull); // el inicio
      expect(field.treeAt(Vector3(-1, 0, -1)), isNotNull); // el bosque
    });
  });

  group('wind', () {
    test('gusts stay within 0..1 and travel with the wind', () {
      final d = TreeField.windDirection;
      for (var t = 0.0; t < 20; t += 0.37) {
        final here = TreeField.gustAt(t, 3, 4);
        expect(here, inInclusiveRange(0, 1));
        // La misma ráfaga, 14 m más allá a favor del viento, 2 s después.
        final later = TreeField.gustAt(
          t + 14 / TreeField.gustSpeed,
          3 + d.x * 14,
          4 + d.z * 14,
        );
        // La segunda ola va más despacio: se parecen, no son idénticas.
        expect((later - here).abs(), lessThan(0.45));
      }
    });

    test('canopies lean downwind on average, never too far', () {
      final tree = treeOf(TreeKind.round);
      var along = 0.0;
      var maxAngle = 0.0;
      for (var t = 0.0; t < 60; t += 0.05) {
        final l = TreeField.leanOf(tree, t);
        along +=
            l.x * TreeField.windDirection.x + l.z * TreeField.windDirection.z;
        maxAngle = max(maxAngle, sqrt(l.x * l.x + l.z * l.z));
      }
      expect(along, greaterThan(0));
      final limit =
          TreeField.baseLean +
          TreeField.gustLean +
          (TreeField.baseSway + TreeField.gustSway) * 1.1;
      expect(maxAngle, lessThanOrEqualTo(limit));
      expect(maxAngle, greaterThan(TreeField.baseLean));
    });

    test('a pine sways less than a round tree', () {
      final round = treeOf(TreeKind.round);
      final pine = treeOf(TreeKind.pine);
      double peak(Tree tree) {
        var m = 0.0;
        for (var t = 0.0; t < 60; t += 0.05) {
          final l = TreeField.leanOf(tree, t);
          m = max(m, sqrt(l.x * l.x + l.z * l.z));
        }
        return m;
      }

      expect(peak(pine), lessThan(peak(round)));
    });

    test('the canopy turns on its pivot, its top going where it leans', () {
      final tree = treeOf(TreeKind.round);
      final top = Vector3(0, 2, 0); // casilla unidad, por encima del pivote

      final still = TreeField.canopyTransform(tree, (x: 0, z: 0));
      final pivot = still.transformed3(Vector3.zero());
      expect(pivot.x, closeTo(tree.x, 1e-6));
      expect(pivot.y, closeTo(tree.pivotHeight, 1e-6));
      expect(pivot.z, closeTo(tree.z, 1e-6));
      final upright = still.transformed3(top.clone());
      expect(upright.x, closeTo(tree.x, 1e-6));
      expect(upright.z, closeTo(tree.z, 1e-6));

      final east = TreeField.canopyTransform(tree, (x: 0.1, z: 0));
      expect(east.transformed3(top.clone()).x, greaterThan(tree.x + 0.1));
      expect(east.transformed3(Vector3.zero()).x, closeTo(tree.x, 1e-6));
      final south = TreeField.canopyTransform(tree, (x: 0, z: 0.1));
      expect(south.transformed3(top.clone()).z, greaterThan(tree.z + 0.1));

      // Escribe en la matriz que se le da (el renderer no crea matrices).
      final into = Matrix4.zero();
      expect(
        identical(TreeField.canopyTransform(tree, (x: 0, z: 0), into), into),
        isTrue,
      );
      expect(into.storage, still.storage);
    });
  });

  group('knock', () {
    test('a fast ball shakes the canopy towards where it was going', () {
      final field = TreeField.fromLayout(layout, 2, outerRing: 0);
      final at = Vector3(1, 2, 1);
      final knocked = field.knock(at, Vector3(0, -1, 12));
      expect(knocked?.tree.kind, TreeKind.round);
      expect(knocked!.strength, closeTo(12 * TreeField.knockPerSpeed, 1e-9));
      final tree = knocked.tree;
      expect(field.shaking, [tree]);

      // Un cuarto de vaivén después, la copa va hacia +Z (hacia donde iba
      // la bola), no de lado.
      field.update(0.25 / TreeField.knockFrequency);
      final lean = tree.knockLean;
      expect(lean.z, greaterThan(0.05));
      expect(lean.x.abs(), lessThan(1e-9));

      // Y se apaga.
      field.update(TreeField.knockSeconds);
      expect(tree.isShaking, isFalse);
      expect(field.shaking, isEmpty);
      expect(tree.knockLean, (x: 0.0, z: 0.0));
    });

    test('slow balls, houses and open ground shake nothing', () {
      final field = TreeField.fromLayout(layout, 2, outerRing: 0);
      expect(field.knock(Vector3(1, 1, 1), Vector3(1.5, 0, 0)), isNull);
      expect(field.knock(Vector3(3, 1, 3), Vector3(12, 0, 0)), isNull);
      expect(field.shaking, isEmpty);
    });

    test('pines shake less; the strength has a ceiling', () {
      final field = TreeField.fromLayout(layout, 2, outerRing: 0);
      final round = field.knock(Vector3(1, 1, 1), Vector3(40, 0, 0))!;
      final pine = field.knock(Vector3(5, 1, 1), Vector3(40, 0, 0))!;
      expect(round.strength, TreeField.maxKnock);
      expect(pine.strength, closeTo(round.strength * 0.55, 1e-9));
    });

    test('a weak knock does not cut short a strong one', () {
      final field = TreeField.fromLayout(layout, 2, outerRing: 0);
      final tree = field.knock(Vector3(1, 1, 1), Vector3(13, 0, 0))!.tree;
      field.update(0.1);
      final before = tree.knockLean;
      field.knock(Vector3(1, 1, 1), Vector3(0, 0, 2.5));
      expect(tree.knockLean, before);
    });
  });

  test('a ball thrown at a tree shakes it (and says so)', () {
    final events = <World3DEvent>[];
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
      onEvent: events.add,
    )..camera.yaw = -pi / 2; // mirando a +X, hacia el árbol
    s.throwBall(PokeBallType.poke);
    for (var t = 0.0; t < 2; t += 1 / 60) {
      s.update(1 / 60);
    }
    final shaken = events.whereType<TreeShaken>().toList();
    expect(shaken, isNotEmpty);
    expect((shaken.first.tree.col, shaken.first.tree.row), (7, 2));
    expect(shaken.first.strength, greaterThan(0.05));
  });
}
