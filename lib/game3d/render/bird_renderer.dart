import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../mesh/bird_mesh.dart';
import '../mesh/mesh_builder.dart';
import '../sim/birds.dart';

/// Dibuja los pájaros con TRES mallas instanciadas (ala izquierda, ala
/// derecha y cuerpo), como las mariposas: una llamada de dibujo por pieza
/// para todos. Cada fotograma copia posición, rumbo, picoteo y alas.
class BirdRenderer {
  BirdRenderer(this.system, Mesh Function(MeshBuffers) toMesh) {
    InstancedMesh instanced(MeshBuffers buffers) {
      final mesh = toMesh(buffers);
      return InstancedMesh(
        geometry: mesh.primitives.first.geometry,
        material: mesh.primitives.first.material,
      );
    }

    _left = instanced(buildBirdWing(left: true));
    _right = instanced(buildBirdWing());
    _body = instanced(buildBirdBody());
    for (final b in system.birds) {
      final color = _palette[b.colorIndex % _palette.length];
      _left.addInstance(vm.Matrix4.identity(), color: color);
      _right.addInstance(vm.Matrix4.identity(), color: color);
      _body.addInstance(vm.Matrix4.identity(), color: color);
    }
    node = Node(name: 'birds')
      ..castsShadows = false
      ..addComponent(InstancedMeshComponent(_left))
      ..addComponent(InstancedMeshComponent(_right))
      ..addComponent(InstancedMeshComponent(_body));
    update();
  }

  final BirdSystem system;
  late final InstancedMesh _left;
  late final InstancedMesh _right;
  late final InstancedMesh _body;
  late final Node node;

  /// Plumajes: pardo, gris paloma, marrón oscuro y canela.
  static final _palette = [
    srgb(0xA8784A),
    srgb(0x8E97A3),
    srgb(0x6A5A4E),
    srgb(0xD2B48C),
  ];

  /// Son pequeños: se dibujan algo más grandes para que se vean.
  static const _scale = 1.5;

  /// Dónde va la bisagra de cada ala (hombros, en el cuerpo sin escalar).
  static final _leftShoulder = vm.Vector3(-0.045, 0.115, 0.01);
  static final _rightShoulder = vm.Vector3(0.045, 0.115, 0.01);

  /// Simulación (mano derecha) → motor (mano izquierda): F·M·F con
  /// F = invertir Z (como las mariposas).
  static final _flip = vm.Matrix4.diagonal3Values(1, 1, -1);
  static vm.Matrix4 _toEngine(vm.Matrix4 m) =>
      _flip.multiplied(m)..multiply(_flip);

  void update() {
    final list = system.birds.toList(growable: false);
    vm.Matrix4 base(Bird b) => vm.Matrix4.translation(b.position)
      ..rotateY(b.heading)
      // Picotear = inclinarse hacia delante sobre las patas.
      ..rotateX(b.peck * 0.7)
      ..scaleByDouble(_scale, _scale, _scale, 1);
    _left.updateInstanceTransforms((t) {
      for (var i = 0; i < list.length; i++) {
        final m = base(list[i])
          ..translateByVector3(_leftShoulder)
          ..rotateZ(-list[i].wingAngle);
        t[i].setFrom(_toEngine(m));
      }
    }, recomputeWinding: false);
    _right.updateInstanceTransforms((t) {
      for (var i = 0; i < list.length; i++) {
        final m = base(list[i])
          ..translateByVector3(_rightShoulder)
          ..rotateZ(list[i].wingAngle);
        t[i].setFrom(_toEngine(m));
      }
    }, recomputeWinding: false);
    _body.updateInstanceTransforms((t) {
      for (var i = 0; i < list.length; i++) {
        t[i].setFrom(_toEngine(base(list[i])));
      }
    }, recomputeWinding: false);
  }
}
