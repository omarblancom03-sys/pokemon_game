import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../mesh/mesh_builder.dart';
import '../mesh/props.dart';
import '../sim/falling_leaves.dart';
import '../sim/trees.dart';

/// Dibuja las hojas que caen: UNA malla instanciada (una hoja repetida)
/// con [FallingLeafSystem.maxLeaves] huecos. Cada fotograma copia la
/// posición, el rumbo, el ladeo y el tamaño de cada hoja, y su color (las
/// otoñales, de cuatro tonos; las verdes, entre dos). Los huecos libres se
/// esconden bajo el suelo.
class FallingLeafRenderer {
  FallingLeafRenderer(Mesh Function(MeshBuffers) toMesh) {
    final mesh = toMesh(buildFallingLeaf());
    _instances = InstancedMesh(
      geometry: mesh.primitives.first.geometry,
      material: mesh.primitives.first.material,
    );
    for (var i = 0; i < FallingLeafSystem.maxLeaves; i++) {
      _instances.addInstance(_hidden);
    }
    node = Node(name: 'fallingLeaves')
      ..castsShadows = false
      ..addComponent(InstancedMeshComponent(_instances));
  }

  late final InstancedMesh _instances;
  late final Node node;

  /// Hueco libre: diminuto y muy por debajo del suelo.
  static final _hidden = vm.Matrix4.compose(
    vm.Vector3(0, -50, 0),
    vm.Quaternion.identity(),
    vm.Vector3.all(0.001),
  );

  /// Naranja, naranja claro, rojo y amarillo (otoñales).
  static final _autumn = [
    Palette.autumn,
    Palette.autumnLight,
    srgb(0xC8452B),
    srgb(0xF2C94C),
  ];

  /// Simulación (mano derecha) → motor (mano izquierda): F·M·F con
  /// F = invertir Z (como las briznas).
  static final _flip = vm.Matrix4.diagonal3Values(1, 1, -1);

  final _color = vm.Vector4.zero();

  void update(List<FallingLeaf> leaves) {
    _instances.updateInstanceTransforms((transforms) {
      for (var i = 0; i < transforms.length; i++) {
        if (i >= leaves.length) {
          transforms[i].setFrom(_hidden);
          continue;
        }
        final l = leaves[i];
        final s = l.size * l.scale;
        final m = vm.Matrix4.translation(l.position)
          ..rotateY(l.yaw)
          ..rotateZ(l.tilt)
          ..scaleByDouble(s, s, s, 1);
        transforms[i].setFrom(_flip.multiplied(m)..multiply(_flip));
      }
    }, recomputeWinding: false);
    for (var i = 0; i < leaves.length; i++) {
      final l = leaves[i];
      if (l.from == TreeKind.autumn) {
        final c = _autumn[(l.shade * _autumn.length).floor().clamp(0, 3)];
        _color.setFrom(c);
      } else {
        // Verdes: entre el verde de la copa y el claro.
        vm.Vector4.mix(Palette.leaf, Palette.leafLight, l.shade, _color);
      }
      _instances.setInstanceColor(i, _color);
    }
  }
}
