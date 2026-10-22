import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../mesh/mesh_builder.dart';
import '../mesh/props.dart';
import '../sim/trees.dart';

/// Dibuja las COPAS de los árboles: una malla instanciada por tipo de copa
/// (redonda, otoñal, pino) con un hueco por árbol. En cada fotograma copia
/// la inclinación que da la simulación ([TreeField.leanOf]): el viento y
/// las sacudidas. Los troncos no se mueven y van en la malla fija.
///
/// Cada copa proyecta su sombra (como antes, cuando iba en la malla fija).
class TreeRenderer {
  TreeRenderer(this.field, Mesh Function(MeshBuffers) toMesh) {
    for (final kind in TreeKind.values) {
      final trees = [
        for (final t in field.trees)
          if (t.kind == kind) t,
      ];
      if (trees.isEmpty) continue;
      final mesh = toMesh(buildCanopy(kind));
      final instances = InstancedMesh(
        geometry: mesh.primitives.first.geometry,
        material: mesh.primitives.first.material,
      );
      for (final t in trees) {
        // Cada copa un pelín más clara u oscura: el bosque no se ve
        // copiado y pegado.
        final light = 0.9 + 0.2 * cellNoise(t.col, t.row, 94);
        instances.addInstance(
          _engine(TreeField.canopyTransform(t, (x: 0, z: 0), _scratch)),
          color: vm.Vector4(light, light, light, 1),
        );
      }
      root.add(
        Node(name: 'canopies-${kind.name}')
          ..addComponent(InstancedMeshComponent(instances)),
      );
      _groups.add((instances: instances, trees: trees));
    }
  }

  final TreeField field;

  /// Nodo a añadir a la escena.
  final Node root = Node(name: 'trees');

  final List<({InstancedMesh instances, List<Tree> trees})> _groups = [];
  final _scratch = vm.Matrix4.zero();

  void update(double time) {
    for (final (:instances, :trees) in _groups) {
      instances.updateInstanceTransforms((transforms) {
        for (var i = 0; i < trees.length; i++) {
          final t = trees[i];
          TreeField.canopyTransform(t, TreeField.leanOf(t, time), _scratch);
          transforms[i].setFrom(_engine(_scratch));
        }
      }, recomputeWinding: false);
    }
  }

  /// Simulación (mano derecha) → motor (mano izquierda): F·M·F con F =
  /// invertir Z. Sin multiplicar: cambian de signo los elementos que
  /// mezclan Z con X, Y o la traslación (fila 2 y columna 2, salvo el
  /// de la diagonal). Se escribe en la misma matriz.
  static vm.Matrix4 _engine(vm.Matrix4 m) {
    final s = m.storage; // por columnas: (fila r, columna c) = s[c * 4 + r]
    for (final i in const [2, 6, 8, 9, 11, 14]) {
      s[i] = -s[i];
    }
    return m;
  }
}
