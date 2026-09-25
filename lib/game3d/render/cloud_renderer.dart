import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../mesh/cloud_mesh.dart';
import '../mesh/mesh_builder.dart';
import '../sim/clouds.dart';

/// Dibuja las nubes con DOS mallas instanciadas: las nubes (bolas blancas
/// facetadas, allá arriba: las de encima y las lejanas) y las sombras de
/// las de encima en el suelo (un disco negro semitransparente con el borde
/// difuminado). Cada fotograma copia dónde está cada una.
class CloudRenderer {
  CloudRenderer(this.layer) {
    _clouds = InstancedMesh(
      geometry: _geometry(buildCloud()),
      // Sin luz y algo por encima de 1: blancas y luminosas contra el cielo.
      material: UnlitMaterial()..baseColorFactor = vm.Vector4(1.3, 1.3, 1.3, 1),
    );
    _shadows = InstancedMesh(
      geometry: _geometry(buildCloudShadow()),
      material: UnlitMaterial()..alphaMode = AlphaMode.blend,
      // Son pocas y todas en el suelo: ordenarlas no se nota.
      sortTransparentInstances: false,
    );
    for (var i = 0; i < layer.clouds.length + layer.farClouds.length; i++) {
      _clouds.addInstance(vm.Matrix4.identity());
    }
    for (var i = 0; i < layer.clouds.length; i++) {
      _shadows.addInstance(vm.Matrix4.identity());
    }
    node = Node(name: 'clouds')
      ..castsShadows = false
      ..addComponent(InstancedMeshComponent(_clouds))
      ..addComponent(InstancedMeshComponent(_shadows));
    update();
  }

  final CloudLayer layer;

  static MeshGeometry _geometry(MeshBuffers buffers) {
    final engine = buffers.toEngineSpace();
    return MeshGeometry.fromArrays(
      positions: engine.positions,
      normals: engine.normals,
      colors: engine.colors,
      indices: engine.indices,
    );
  }

  late final InstancedMesh _clouds;
  late final InstancedMesh _shadows;
  late final Node node;

  /// Simulación (mano derecha) → motor (mano izquierda): F·M·F con
  /// F = invertir Z (como las mariposas).
  static final _flip = vm.Matrix4.diagonal3Values(1, 1, -1);
  static vm.Matrix4 _toEngine(vm.Matrix4 m) =>
      _flip.multiplied(m)..multiply(_flip);

  /// Altura de la sombra sobre el suelo: por encima de las losas del
  /// camino (a menos, parpadea con ellas).
  static const _shadowY = 0.1;

  void update() {
    final list = layer.clouds;
    final all = [...list, ...layer.farClouds];
    _clouds.updateInstanceTransforms((t) {
      for (var i = 0; i < all.length; i++) {
        final c = all[i];
        final m = vm.Matrix4.translation(CloudLayer.skyOf(c))
          ..rotateY(c.yaw)
          ..scaleByDouble(c.radius * c.stretch, c.radius * 0.6, c.radius, 1);
        t[i].setFrom(_toEngine(m));
      }
    }, recomputeWinding: false);
    _shadows.updateInstanceTransforms((t) {
      for (var i = 0; i < list.length; i++) {
        final c = list[i];
        final m =
            vm.Matrix4.translation(vm.Vector3(c.shadow.x, _shadowY, c.shadow.z))
              ..rotateY(c.yaw)
              ..scaleByDouble(c.radius * c.stretch, 1, c.radius, 1);
        t[i].setFrom(_toEngine(m));
      }
    }, recomputeWinding: false);
  }
}
