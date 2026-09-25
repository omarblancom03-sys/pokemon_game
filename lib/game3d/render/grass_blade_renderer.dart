import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../mesh/grass_mesh.dart';
import '../mesh/mesh_builder.dart';
import '../sim/grass_blades.dart';

/// Dibuja las briznas sueltas: UNA malla instanciada (una hoja repetida)
/// con [GrassBladeSystem.maxBlades] huecos. Cada fotograma copia la
/// posición, el giro y el tamaño de cada brizna; los huecos libres se
/// esconden bajo el suelo.
class GrassBladeRenderer {
  GrassBladeRenderer(Mesh Function(MeshBuffers) toMesh) {
    final mesh = toMesh(buildLooseBlade());
    _instances = InstancedMesh(
      geometry: mesh.primitives.first.geometry,
      material: mesh.primitives.first.material,
    );
    for (var i = 0; i < GrassBladeSystem.maxBlades; i++) {
      _instances.addInstance(_hidden);
    }
    node = Node(name: 'grassBlades')
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

  /// Simulación (mano derecha) → motor (mano izquierda): F·M·F con
  /// F = invertir Z (como las mariposas).
  static final _flip = vm.Matrix4.diagonal3Values(1, 1, -1);

  final _color = vm.Vector4.zero();

  void update(List<GrassBlade> blades) {
    _instances.updateInstanceTransforms((transforms) {
      for (var i = 0; i < transforms.length; i++) {
        if (i >= blades.length) {
          transforms[i].setFrom(_hidden);
          continue;
        }
        final b = blades[i];
        final s = b.size * b.scale;
        final m = vm.Matrix4.translation(b.position)
          ..rotateY(b.heading)
          ..rotateX(b.angle)
          ..scaleByDouble(s, s, s, 1);
        transforms[i].setFrom(_flip.multiplied(m)..multiply(_flip));
      }
    }, recomputeWinding: false);
    for (var i = 0; i < blades.length; i++) {
      // Unas más oscuras y otras más claras.
      final light = 0.8 + 0.4 * blades[i].shade;
      _color.setValues(light, light, light, 1);
      _instances.setInstanceColor(i, _color);
    }
  }
}
