import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../mesh/mesh_builder.dart';
import '../sim/dust.dart';

/// Dibuja el polvo: UNA malla instanciada (una bolita facetada repetida)
/// con [DustSystem.maxPuffs] huecos. Cada fotograma copia la posición,
/// el tamaño y la opacidad de cada nubecilla; los huecos libres se
/// esconden bajo el suelo.
class DustRenderer {
  DustRenderer() {
    final puff =
        (MeshBuilder()
              ..gem(vm.Vector3.zero(), vm.Vector3.all(1), srgb(0xE6D8B8)))
            .build()
            .toEngineSpace();
    final mesh = Mesh(
      MeshGeometry.fromArrays(
        positions: puff.positions,
        normals: puff.normals,
        colors: puff.colors,
        indices: puff.indices,
      ),
      UnlitMaterial()..alphaMode = AlphaMode.blend,
    );
    _instances = InstancedMesh(
      geometry: mesh.primitives.first.geometry,
      material: mesh.primitives.first.material,
      // Son nubecillas casi iguales: ordenarlas no se nota y cuesta.
      sortTransparentInstances: false,
    );
    for (var i = 0; i < DustSystem.maxPuffs; i++) {
      _instances.addInstance(_hidden, color: vm.Vector4.zero());
    }
    node = Node(name: 'dust')
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

  final _color = vm.Vector4.zero();

  void update(List<DustPuff> puffs) {
    _instances.updateInstanceTransforms((transforms) {
      for (var i = 0; i < transforms.length; i++) {
        if (i >= puffs.length) {
          transforms[i].setFrom(_hidden);
          continue;
        }
        final p = puffs[i];
        final r = p.radius;
        transforms[i].setFrom(
          vm.Matrix4.compose(
            vm.Vector3(p.position.x, p.position.y, -p.position.z), // motor
            vm.Quaternion.identity(),
            vm.Vector3(r, r * 0.8, r),
          ),
        );
      }
    }, recomputeWinding: false);
    for (var i = 0; i < DustSystem.maxPuffs; i++) {
      _color.setValues(1, 1, 1, i < puffs.length ? puffs[i].opacity : 0);
      _instances.setInstanceColor(i, _color);
    }
  }
}
