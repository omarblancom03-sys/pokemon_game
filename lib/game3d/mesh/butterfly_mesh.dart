import 'package:vector_math/vector_math.dart';

import 'mesh_builder.dart';

/// Ala de mariposa (derecha: hacia +X; [left] la refleja hacia -X), con la
/// bisagra en el eje Z (el cuerpo mira hacia +Z). Blanca por dentro y gris
/// en el borde: el color de cada mariposa se multiplica por encima. Tiene
/// las dos caras (se ve por arriba y por abajo).
MeshBuffers buildWing({bool left = false}) {
  final s = left ? -1.0 : 1.0;
  // Contorno: ala delantera grande y trasera más pequeña.
  final outline = [
    Vector3(0, 0, 0.05),
    Vector3(0.1 * s, 0, 0.12),
    Vector3(0.16 * s, 0, 0.05),
    Vector3(0.12 * s, 0, -0.02),
    Vector3(0.11 * s, 0, -0.09),
    Vector3(0.04 * s, 0, -0.1),
    Vector3(0, 0, -0.04),
  ];
  final center = Vector3.zero();
  final inner = Vector4(1, 1, 1, 1);
  final edge = Vector4(0.45, 0.45, 0.45, 1);
  final b = MeshBuilder();
  for (var i = 0; i < outline.length - 1; i++) {
    final a = outline[i];
    final c = outline[i + 1];
    final ca = i == 0 ? inner : edge;
    final cc = i + 1 == outline.length - 1 ? inner : edge;
    // Una cara hacia arriba y otra hacia abajo (orden contrario).
    b
      ..shadedTriangle(center, a, c, inner, ca, cc)
      ..shadedTriangle(center, c, a, inner, cc, ca);
  }
  return b.build();
}

/// Cuerpo de la mariposa: un bastoncillo oscuro a lo largo de Z.
MeshBuffers buildButterflyBody() =>
    (MeshBuilder()
          ..gem(Vector3.zero(), Vector3(0.018, 0.018, 0.08), srgb(0x3A2E2A)))
        .build();
