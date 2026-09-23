import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../mesh/butterfly_mesh.dart';
import '../mesh/mesh_builder.dart';
import '../sim/butterflies.dart';

/// Dibuja las mariposas con TRES mallas instanciadas (ala izquierda, ala
/// derecha y cuerpo): una llamada de dibujo por pieza para todas. Cada
/// fotograma copia posición, rumbo y aleteo de la simulación.
class ButterflyRenderer {
  ButterflyRenderer(this.swarm, Mesh Function(MeshBuffers) toMesh) {
    InstancedMesh instanced(MeshBuffers buffers) {
      final mesh = toMesh(buffers);
      return InstancedMesh(
        geometry: mesh.primitives.first.geometry,
        material: mesh.primitives.first.material,
      );
    }

    _left = instanced(buildWing(left: true));
    _right = instanced(buildWing());
    _body = instanced(buildButterflyBody());
    for (final b in swarm.butterflies) {
      final color = _palette[b.colorIndex % _palette.length];
      _left.addInstance(vm.Matrix4.identity(), color: color);
      _right.addInstance(vm.Matrix4.identity(), color: color);
      _body.addInstance(vm.Matrix4.identity());
    }
    node = Node(name: 'butterflies')
      ..castsShadows = false
      ..addComponent(InstancedMeshComponent(_left))
      ..addComponent(InstancedMeshComponent(_right))
      ..addComponent(InstancedMeshComponent(_body));
    update();
  }

  final ButterflySwarm swarm;
  late final InstancedMesh _left;
  late final InstancedMesh _right;
  late final InstancedMesh _body;
  late final Node node;

  /// Amarilla, blanca, naranja, celeste, rosa y lila.
  static final _palette = [
    srgb(0xFFD84D),
    srgb(0xF5F5F0),
    srgb(0xFF9A3C),
    srgb(0x7FC8FF),
    srgb(0xFF8FC8),
    srgb(0xB88CFF),
  ];

  /// Las mariposas son diminutas: se dibujan algo más grandes para que se
  /// vean (como los Pokémon).
  static const _scale = 1.6;

  /// Simulación (mano derecha) → motor (mano izquierda): F·M·F con
  /// F = invertir Z. Así la misma matriz sirve en los dos espacios.
  static final _flip = vm.Matrix4.diagonal3Values(1, 1, -1);
  static vm.Matrix4 _toEngine(vm.Matrix4 m) =>
      _flip.multiplied(m)..multiply(_flip);

  void update() {
    final list = swarm.butterflies;
    vm.Matrix4 base(Butterfly b) => vm.Matrix4.translation(b.position)
      ..rotateY(b.heading)
      ..scaleByDouble(_scale, _scale, _scale, 1);
    _left.updateInstanceTransforms((t) {
      for (var i = 0; i < list.length; i++) {
        t[i].setFrom(_toEngine(base(list[i])..rotateZ(-list[i].wingAngle)));
      }
    }, recomputeWinding: false);
    _right.updateInstanceTransforms((t) {
      for (var i = 0; i < list.length; i++) {
        t[i].setFrom(_toEngine(base(list[i])..rotateZ(list[i].wingAngle)));
      }
    }, recomputeWinding: false);
    _body.updateInstanceTransforms((t) {
      for (var i = 0; i < list.length; i++) {
        t[i].setFrom(_toEngine(base(list[i])));
      }
    }, recomputeWinding: false);
  }
}
