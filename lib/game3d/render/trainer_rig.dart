import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../models/poke_ball.dart';
import '../mesh/ball_mesh.dart';
import '../mesh/mesh_builder.dart';
import '../mesh/props.dart' show buildBerry;
import '../mesh/trainer_mesh.dart';
import '../sim/throwing.dart';
import '../sim/trainer_pose.dart';

/// El entrenador como jerarquía de nodos del motor ("esqueleto" simple):
///
///   raíz (posición y giro) → cadera (rebote e inclinación)
///     → cuerpo, 2 piernas y 2 brazos (cada uno gira en su articulación).
///
/// Solo traduce una [TrainerPose] a transformaciones; la lógica de la
/// postura vive en la simulación.
class TrainerRig {
  TrainerRig(Mesh Function(MeshBuffers) toMesh) {
    final parts = buildTrainerParts();
    final legMesh = toMesh(parts.leg);
    final armMesh = toMesh(parts.arm);
    _hips.add(Node(mesh: toMesh(parts.body)));
    for (final limb in [_leftLeg, _rightLeg]) {
      limb.add(Node(mesh: legMesh.clone()));
      _hips.add(limb);
    }
    for (final limb in [_leftArm, _rightArm]) {
      limb.add(Node(mesh: armMesh.clone()));
      _hips.add(limb);
    }
    // Una bola de cada tipo en el guante derecho (solo se ve la que toca).
    for (final type in PokeBallType.values) {
      final ball = Node(mesh: toMesh(buildPokeBall(type, radius: ballRadius)))
        ..position = vm.Vector3(0, -0.62, 0)
        // Con el brazo en alto, la mitad de color queda hacia arriba.
        ..rotation = vm.Quaternion.axisAngle(_x, math.pi)
        ..visible = false;
      _handBalls[type] = ball;
      _rightArm.add(ball);
    }
    // Y una baya (cuando la lleva en la mano para lanzarla).
    _rightArm.add(_handBerry..add(Node(mesh: toMesh(buildBerry()))));
    root.add(_hips);
  }

  /// Nodo a añadir a la escena.
  final Node root = Node(name: 'trainer');
  final Node _hips = Node(name: 'hips');
  final Node _leftLeg = Node(name: 'leftLeg');
  final Node _rightLeg = Node(name: 'rightLeg');
  final Node _leftArm = Node(name: 'leftArm');
  final Node _rightArm = Node(name: 'rightArm');
  final Map<PokeBallType, Node> _handBalls = {};
  final Node _handBerry = Node(name: 'handBerry')
    ..position = vm.Vector3(0, -0.62, 0)
    ..visible = false;

  static final _x = vm.Vector3(1, 0, 0);
  static final _y = vm.Vector3(0, 1, 0);

  /// Coloca al entrenador. [feet] y [facing] vienen de la simulación (mano
  /// derecha); aquí se pasan al espacio del motor (Z invertida, giros con
  /// el signo cambiado). [heldBall] es la bola que lleva en la mano y
  /// [heldBerry], si lleva una baya.
  void apply({
    required vm.Vector3 feet,
    required double facing,
    required TrainerPose pose,
    PokeBallType? heldBall,
    bool heldBerry = false,
  }) {
    _handBerry.visible = heldBerry;
    for (final MapEntry(:key, :value) in _handBalls.entries) {
      value.visible = key == heldBall;
    }
    root
      ..position = _engine(feet)
      ..rotation = vm.Quaternion.axisAngle(_y, -facing);
    _hips
      ..position = vm.Vector3(0, pose.bob - 0.14 * pose.crouch, 0)
      ..rotation = vm.Quaternion.axisAngle(_x, -pose.lean);
    // Ángulo positivo en X lleva el pie hacia atrás: por eso el signo menos
    // para "hacia delante".
    // Agachado: una pierna adelantada y la otra atrás (medio arrodillado).
    _setLimb(
      _rightLeg,
      TrainerJoints.rightHip,
      -pose.legSwing - 0.6 * pose.crouch,
    );
    _setLimb(
      _leftLeg,
      TrainerJoints.leftHip,
      pose.legSwing + 0.3 * pose.crouch,
    );
    _setLimb(
      _rightArm,
      TrainerJoints.rightShoulder,
      // rightArm/armSwing son "positivo = hacia delante"; aquí es al revés.
      -(pose.rightArm ?? pose.armSwing),
    );
    _setLimb(_leftArm, TrainerJoints.leftShoulder, pose.armSwing);
  }

  void _setLimb(Node limb, vm.Vector3 joint, double simAngle) {
    limb
      ..position = _engine(joint)
      ..rotation = vm.Quaternion.axisAngle(_x, -simAngle);
  }

  static vm.Vector3 _engine(vm.Vector3 v) => vm.Vector3(v.x, v.y, -v.z);
}
