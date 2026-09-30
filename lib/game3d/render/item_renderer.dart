import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../models/poke_ball.dart';
import '../mesh/ball_mesh.dart';
import '../sim/field_items.dart';
import '../sim/throwing.dart';
import 'ball_model.dart';

/// Dibuja las Poké Balls que hay en el suelo: la bola flotando y girando
/// despacio, con un haz de luz que se ve desde lejos y aparece con un
/// pequeño "pop". Solo copia el estado de la simulación.
class ItemRenderer {
  ItemRenderer({required this.root}) {
    for (final type in PokeBallType.values) {
      _balls[type] = BallModel(
        type,
        buildPokeBall(type, radius: ballRadius),
      ).mesh();
      final beam = buildGlowBeam(_glowColor(type)).toEngineSpace();
      _beams[type] = Mesh(
        MeshGeometry.fromArrays(
          positions: beam.positions,
          normals: beam.normals,
          colors: beam.colors,
          indices: beam.indices,
        ),
        UnlitMaterial()..alphaMode = AlphaMode.blend,
      );
    }
  }

  /// Nodo de la escena donde se cuelgan los objetos.
  final Node root;

  final Map<PokeBallType, Mesh> _balls = {};
  final Map<PokeBallType, Mesh> _beams = {};
  final Map<String, ({Node node, Node ball})> _visuals = {};

  static final _y = vm.Vector3(0, 1, 0);

  /// Brillo del haz: más de 1 en rgb para que el "bloom" lo haga relucir.
  static vm.Vector4 _glowColor(PokeBallType type) => switch (type) {
    PokeBallType.poke => vm.Vector4(1.6, 1.35, 0.9, 0.42),
    PokeBallType.great => vm.Vector4(0.8, 1.2, 1.9, 0.42),
    PokeBallType.ultra => vm.Vector4(1.9, 1.5, 0.4, 0.5),
  };

  void update(List<GroundItem> items, double time) {
    final alive = {for (final i in items) i.id};
    for (final id in _visuals.keys.toList()) {
      if (!alive.contains(id)) root.remove(_visuals.remove(id)!.node);
    }
    for (final item in items) {
      final v = _visuals[item.id] ??= _create(item);
      final pop = math.min(1.0, item.age / 0.3);
      final p = item.position;
      v.node
        ..position =
            vm.Vector3(p.x, 0, -p.z) // espacio del motor
        ..scale = vm.Vector3.all(pop);
      // Las falladas descansan en el suelo; las del campo flotan y giran.
      v.ball
        ..position = vm.Vector3(
          0,
          item.dropped
              ? ballRadius
              : 0.35 + 0.07 * math.sin(item.age * 2.4 + p.x),
          0,
        )
        ..rotation = vm.Quaternion.axisAngle(
          _y,
          item.dropped ? p.x : -item.age * 1.4,
        );
    }
  }

  ({Node node, Node ball}) _create(GroundItem item) {
    final ball = Node(mesh: _balls[item.ball]!.clone())
      ..scale = vm.Vector3.all(item.dropped ? 1 : 1.5);
    final beam = Node(mesh: _beams[item.ball]!.clone())..castsShadows = false;
    final node = Node(name: item.id)
      ..add(ball)
      ..add(beam);
    root.add(node);
    return (node: node, ball: ball);
  }
}
