import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../mesh/mesh_builder.dart';
import '../mesh/trainer_mesh.dart';
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
    root.add(_hips);
  }

  /// Nodo a añadir a la escena.
  final Node root = Node(name: 'trainer');
  final Node _hips = Node(name: 'hips');
  final Node _leftLeg = Node(name: 'leftLeg');
  final Node _rightLeg = Node(name: 'rightLeg');
  final Node _leftArm = Node(name: 'leftArm');
  final Node _rightArm = Node(name: 'rightArm');

  static final _x = vm.Vector3(1, 0, 0);
  static final _y = vm.Vector3(0, 1, 0);

  /// Coloca al entrenador. [feet] y [facing] vienen de la simulación (mano
  /// derecha); aquí se pasan al espacio del motor (Z invertida, giros con
  /// el signo cambiado).
  void apply({
    required vm.Vector3 feet,
    required double facing,
    required TrainerPose pose,
  }) {
    root
      ..position = _engine(feet)
      ..rotation = vm.Quaternion.axisAngle(_y, -facing);
    _hips
      ..position = vm.Vector3(0, pose.bob, 0)
      ..rotation = vm.Quaternion.axisAngle(_x, -pose.lean);
    // Ángulo positivo en X lleva el pie hacia atrás: por eso el signo menos
    // para "hacia delante".
    _setLimb(_rightLeg, TrainerJoints.rightHip, -pose.legSwing);
    _setLimb(_leftLeg, TrainerJoints.leftHip, pose.legSwing);
    _setLimb(_rightArm, TrainerJoints.rightShoulder, -pose.armSwing);
    _setLimb(_leftArm, TrainerJoints.leftShoulder, pose.armSwing);
  }

  void _setLimb(Node limb, vm.Vector3 joint, double simAngle) {
    limb
      ..position = _engine(joint)
      ..rotation = vm.Quaternion.axisAngle(_x, -simAngle);
  }

  static vm.Vector3 _engine(vm.Vector3 v) => vm.Vector3(v.x, v.y, -v.z);
}
