import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'mesh_builder.dart';

/// HUELLA de zapatilla, plana en el suelo (y = 0, cara hacia arriba) y con
/// la punta hacia +Z: una suela ovalada delante y el tacón detrás, algo
/// separados. Mide ~0,24 m de largo. Es simétrica, así que vale para los
/// dos pies. Color de tierra húmeda y opaco: lo que se borra es el alfa de
/// cada huella (por instancia).
MeshBuffers buildFootprint({int segments = 14}) {
  final b = MeshBuilder();
  final color = srgb(0x7A5E38);
  // (centro en z, radio en x, radio en z)
  for (final (cz, rx, rz) in const [
    (0.05, 0.05, 0.075),
    (-0.08, 0.04, 0.035),
  ]) {
    final center = Vector3(0, 0, cz);
    Vector3 at(int i) {
      final a = i * 2 * math.pi / segments;
      return Vector3(math.cos(a) * rx, 0, cz + math.sin(a) * rz);
    }

    for (var i = 0; i < segments; i++) {
      // Este orden deja la cara hacia arriba (como la sombra de las nubes).
      b.triangle(center, at(i + 1), at(i), color);
    }
  }
  return b.build();
}
