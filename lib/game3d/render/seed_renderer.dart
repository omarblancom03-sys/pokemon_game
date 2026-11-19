import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../mesh/mesh_builder.dart';
import '../sim/seeds.dart';

/// Dibuja los vilanos: UNA malla instanciada (una pelusa repetida) con
/// [SeedDrift.maxSeeds] huecos, SIN LUZ (blancos también a la sombra,
/// como se ven de verdad a contraluz). Cada fotograma copia la posición,
/// el giro y el tamaño de cada uno; los huecos libres, bajo el suelo.
class SeedRenderer {
  SeedRenderer() {
    final puff = buildSeedPuff().toEngineSpace();
    _instances = InstancedMesh(
      geometry: MeshGeometry.fromArrays(
        positions: puff.positions,
        normals: puff.normals,
        colors: puff.colors,
        indices: puff.indices,
      ),
      material: UnlitMaterial(),
    );
    for (var i = 0; i < SeedDrift.maxSeeds; i++) {
      _instances.addInstance(_hidden);
    }
    node = Node(name: 'seeds')
      ..castsShadows = false
      ..addComponent(InstancedMeshComponent(_instances));
  }

  late final InstancedMesh _instances;
  late final Node node;

  /// Tamaño de la pelusa (m).
  static const size = 0.09;

  /// Hueco libre: diminuto y muy por debajo del suelo.
  static final _hidden = vm.Matrix4.compose(
    vm.Vector3(0, -50, 0),
    vm.Quaternion.identity(),
    vm.Vector3.all(0.001),
  );

  /// Simulación (mano derecha) → motor (mano izquierda): F·M·F con
  /// F = invertir Z (como las briznas).
  static final _flip = vm.Matrix4.diagonal3Values(1, 1, -1);

  void update(List<FloatingSeed> seeds) {
    _instances.updateInstanceTransforms((transforms) {
      for (var i = 0; i < transforms.length; i++) {
        if (i >= seeds.length) {
          transforms[i].setFrom(_hidden);
          continue;
        }
        final s = seeds[i];
        final k = size * s.scale;
        final m = vm.Matrix4.translation(s.position)
          ..rotateY(s.angle)
          ..rotateX(0.4 * math.sin(s.angle * 0.7))
          ..scaleByDouble(k, k, k, 1);
        transforms[i].setFrom(_flip.multiplied(m)..multiply(_flip));
      }
    }, recomputeWinding: false);
  }
}

/// La pelusa de un vilano: tres cuadrados cruzados (uno por eje), con las
/// dos caras, de lado 1 y centrados; blanca por dentro y algo gris en los
/// bordes. Desde cualquier lado se ve como una motita esponjosa.
MeshBuffers buildSeedPuff() {
  final b = MeshBuilder();
  final center = vm.Vector4(1, 1, 1, 1);
  final edge = vm.Vector4(0.82, 0.84, 0.86, 1);
  // Cada cuadrado: un abanico de 4 triángulos desde el centro.
  for (final corners in [
    [
      vm.Vector3(-0.5, -0.5, 0),
      vm.Vector3(0.5, -0.5, 0),
      vm.Vector3(0.5, 0.5, 0),
      vm.Vector3(-0.5, 0.5, 0),
    ],
    [
      vm.Vector3(0, -0.5, -0.5),
      vm.Vector3(0, -0.5, 0.5),
      vm.Vector3(0, 0.5, 0.5),
      vm.Vector3(0, 0.5, -0.5),
    ],
    [
      vm.Vector3(-0.5, 0, -0.5),
      vm.Vector3(0.5, 0, -0.5),
      vm.Vector3(0.5, 0, 0.5),
      vm.Vector3(-0.5, 0, 0.5),
    ],
  ]) {
    for (var i = 0; i < 4; i++) {
      final a = corners[i];
      final c = corners[(i + 1) % 4];
      b
        ..shadedTriangle(vm.Vector3.zero(), a, c, center, edge, edge)
        ..shadedTriangle(vm.Vector3.zero(), c, a, center, edge, edge);
    }
  }
  return b.build();
}
