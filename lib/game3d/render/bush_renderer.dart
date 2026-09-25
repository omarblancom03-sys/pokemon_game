import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../mesh/mesh_builder.dart';
import '../mesh/props.dart';
import '../sim/berries.dart';

/// Dibuja los ARBUSTOS con bayas (se balancean al sacudirlos y sus bayas
/// aparecen y desaparecen) y las bayas sueltas que saltan y quedan en el
/// suelo. Solo copia el estado de la simulación ([BerrySystem]).
///
/// Cada arbusto es un nodo con su baya en cada hueco como hijo: así las
/// bayas se balancean con él. Son pocos (uno por `b` del mapa).
class BushRenderer {
  BushRenderer(this.system, Mesh Function(MeshBuffers) toMesh) {
    final half = system.tileSize / 2;
    final leaves = MeshBuilder();
    leaves.withTransform(
      vm.Matrix4.identity()..scaleByDouble(half, half, half, 1),
      () => addBush(leaves),
    );
    final leafMesh = toMesh(leaves.build());
    _berryMesh = toMesh(buildBerry(radius: BerrySystem.radius));
    for (final bush in system.bushes) {
      final node = Node(name: 'bush', mesh: leafMesh.clone())
        ..position = _engine(bush.center);
      final berries = [
        for (final slot in bush.slots)
          Node(mesh: _berryMesh.clone())
            ..position = _engine(slot - bush.center),
      ];
      berries.forEach(node.add);
      root.add(node);
      _bushes.add((node: node, berries: berries));
    }
  }

  final BerrySystem system;

  /// Nodo a añadir a la escena.
  final Node root = Node(name: 'bushes');

  late final Mesh _berryMesh;
  final List<({Node node, List<Node> berries})> _bushes = [];
  final Map<String, Node> _loose = {};

  static final _x = vm.Vector3(1, 0, 0);

  void update() {
    for (var i = 0; i < _bushes.length; i++) {
      final bush = system.bushes[i];
      final (:node, :berries) = _bushes[i];
      // Se inclina hacia donde lo empujaron (y de vuelta), aplastándose un
      // poco. El eje es horizontal y perpendicular al empujón; en el motor
      // (Z invertida) el giro cambia de signo.
      final sway = bush.sway;
      final h = bush.shakeHeading;
      final squash = sway.abs();
      node
        ..rotation = vm.Quaternion.axisAngle(
          vm.Vector3(math.cos(h), 0, math.sin(h)),
          -sway,
        )
        ..scale = vm.Vector3(
          1 + squash * 0.5,
          1 - squash * 0.6,
          1 + squash * 0.5,
        );
      for (var b = 0; b < berries.length; b++) {
        final s = bush.berryScale(b);
        berries[b]
          ..visible = s > 0
          ..scale = vm.Vector3.all(s > 0 ? s : 1);
      }
    }

    final loose = system.loose;
    final alive = {for (final b in loose) b.id};
    for (final id in _loose.keys.toList()) {
      if (!alive.contains(id)) root.remove(_loose.remove(id)!);
    }
    for (final berry in loose) {
      final node = _loose[berry.id] ??= _create();
      node
        ..position = _engine(berry.position)
        ..rotation = vm.Quaternion.axisAngle(_x, berry.spin)
        ..scale = vm.Vector3.all(berry.scale);
    }
  }

  Node _create() {
    final node = Node(name: 'berry', mesh: _berryMesh.clone());
    root.add(node);
    return node;
  }

  static vm.Vector3 _engine(vm.Vector3 v) => vm.Vector3(v.x, v.y, -v.z);
}
