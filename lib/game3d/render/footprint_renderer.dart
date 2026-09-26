import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../mesh/footprint_mesh.dart';
import '../sim/footprints.dart';

/// Dibuja las huellas: UNA malla instanciada (la huella repetida) con
/// [FootprintTrail.maxPrints] huecos. Cada fotograma copia dónde está cada
/// huella, hacia dónde apunta y lo borrada que está (alfa por instancia);
/// los huecos libres se esconden bajo el suelo.
class FootprintRenderer {
  FootprintRenderer() {
    final print = buildFootprint().toEngineSpace();
    _instances = InstancedMesh(
      geometry: MeshGeometry.fromArrays(
        positions: print.positions,
        normals: print.normals,
        colors: print.colors,
        indices: print.indices,
      ),
      material: UnlitMaterial()..alphaMode = AlphaMode.blend,
      // Todas planas en el suelo: ordenarlas no se nota.
      sortTransparentInstances: false,
    );
    for (var i = 0; i < FootprintTrail.maxPrints; i++) {
      _instances.addInstance(_hidden, color: vm.Vector4.zero());
    }
    node = Node(name: 'footprints')
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
  /// F = invertir Z (como las nubes).
  static final _flip = vm.Matrix4.diagonal3Values(1, 1, -1);

  /// Altura sobre el suelo: lo justo para no parpadear con él.
  static const _y = 0.03;

  /// Para que el suelo se vea a través: el alfa de una huella recién hecha.
  static const _maxAlpha = 0.7;

  final _color = vm.Vector4.zero();

  void update(List<Footprint> prints) {
    _instances.updateInstanceTransforms((transforms) {
      for (var i = 0; i < transforms.length; i++) {
        if (i >= prints.length) {
          transforms[i].setFrom(_hidden);
          continue;
        }
        final p = prints[i];
        final m = vm.Matrix4.translation(
          vm.Vector3(p.position.x, _y, p.position.z),
        )..rotateY(p.facing);
        transforms[i].setFrom(_flip.multiplied(m)..multiply(_flip));
      }
    }, recomputeWinding: false);
    for (var i = 0; i < FootprintTrail.maxPrints; i++) {
      final alpha = i < prints.length ? prints[i].opacity * _maxAlpha : 0.0;
      _color.setValues(1, 1, 1, alpha);
      _instances.setInstanceColor(i, _color);
    }
  }
}
