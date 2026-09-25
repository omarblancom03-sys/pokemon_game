import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'mesh_builder.dart';

/// Una nube de 1 m de radio: cinco bolas facetadas blancas, algo azuladas
/// por debajo (como las de verdad). Se dibuja SIN luz: con luz, la tripa
/// quedaba gris oscura, de tormenta.
MeshBuffers buildCloud() {
  final b = MeshBuilder();
  final white = srgb(0xFFFFFF);
  final belly = srgb(0xDCE6F2);
  Vector4 shade(Vector3 dir) => dir.y < -0.2 ? belly : white;
  for (final (center, radii) in [
    (Vector3(0, 0, 0), Vector3(0.62, 0.7, 0.62)),
    (Vector3(0.5, -0.12, 0.1), Vector3(0.48, 0.5, 0.48)),
    (Vector3(-0.52, -0.15, -0.05), Vector3(0.45, 0.45, 0.45)),
    (Vector3(0.1, -0.05, 0.45), Vector3(0.42, 0.42, 0.42)),
    (Vector3(-0.15, 0.2, -0.4), Vector3(0.4, 0.45, 0.4)),
  ]) {
    b.gem(center, radii, white, detail: 2, colorAt: shade);
  }
  return b.build();
}

/// Sombra de nube de 1 m de radio, tumbada en el suelo y mirando arriba:
/// negra y semitransparente (la opacidad va en el alfa de cada vértice),
/// con el borde difuminado en el último cuarto del radio para que se
/// reconozca su forma al pasar.
MeshBuffers buildCloudShadow({int segments = 28}) {
  final b = MeshBuilder();
  final center = srgb(0x000000, 0.72);
  final inner = srgb(0x000000, 0.68);
  final rim = srgb(0x000000, 0);
  Vector3 at(int i, double r) {
    final a = i * 2 * math.pi / segments;
    return Vector3(math.cos(a) * r, 0, math.sin(a) * r);
  }

  for (var i = 0; i < segments; i++) {
    // Centro → anillo interior (este orden deja la cara hacia arriba).
    b
      ..shadedTriangle(
        Vector3.zero(),
        at(i + 1, 0.72),
        at(i, 0.72),
        center,
        inner,
        inner,
      )
      // Anillo interior → borde, que se desvanece.
      ..shadedQuad(
        at(i, 0.72),
        at(i + 1, 0.72),
        at(i + 1, 1),
        at(i, 1),
        inner,
        inner,
        rim,
        rim,
      );
  }
  return b.build();
}
