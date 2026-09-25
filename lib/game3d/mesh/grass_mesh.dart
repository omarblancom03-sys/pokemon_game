import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'mesh_builder.dart';

/// Colores de la hierba alta: base oscura y puntas claras (degradado por
/// hoja, que da volumen sin texturas).
abstract final class GrassPalette {
  static final base = srgb(0x2C7A2E);
  static final middle = srgb(0x44A23A);
  static final tip = srgb(0x8FD45A);
}

/// Una mata de hierba alta: [blades] hojas finas en abanico, con la base
/// en el origen. Cada hoja es de doble cara (se ve por delante y por
/// detrás), porque el motor descarta las caras traseras.
MeshBuffers buildGrassTuft({int blades = 7, double height = 0.75}) {
  final b = MeshBuilder();
  for (var i = 0; i < blades; i++) {
    final angle = i * 2 * math.pi / blades + (i.isEven ? 0.3 : -0.2);
    final h = height * (0.75 + 0.25 * math.sin(i * 1.7).abs());
    final lean = 0.18 + 0.1 * math.cos(i * 2.3).abs();
    // Dirección hacia la que se abre la hoja y su perpendicular (anchura).
    final out = Vector3(math.sin(angle), 0, math.cos(angle));
    final side = Vector3(out.z, 0, -out.x);
    const w = 0.07;

    final baseL = out * 0.05 - side * w;
    final baseR = out * 0.05 + side * w;
    final midL = out * (lean * 0.5) + Vector3(0, h * 0.55, 0) - side * w * 0.7;
    final midR = out * (lean * 0.5) + Vector3(0, h * 0.55, 0) + side * w * 0.7;
    final tip = out * lean + Vector3(0, h, 0);

    // Cara exterior y su gemela interior (orden inverso).
    b
      ..quad(baseL, baseR, midR, midL, GrassPalette.base)
      ..triangle(midL, midR, tip, GrassPalette.tip)
      ..quad(baseR, baseL, midL, midR, GrassPalette.middle)
      ..triangle(midR, midL, tip, GrassPalette.tip);
  }
  return b.build();
}

/// Una brizna suelta (la que salta al pisar la hierba): hoja plana de
/// 1 m de largo a lo largo de Y, centrada en el origen para que gire
/// sobre su mitad, con la punta arriba y de doble cara. Se escala al
/// tamaño real al dibujarla.
MeshBuffers buildLooseBlade() {
  const w = 0.1; // media anchura
  final baseL = Vector3(-w, -0.5, 0);
  final baseR = Vector3(w, -0.5, 0);
  final midL = Vector3(-w * 1.1, 0.1, 0);
  final midR = Vector3(w * 1.1, 0.1, 0);
  final tip = Vector3(0, 0.5, 0);
  return (MeshBuilder()
        // Cara delantera (mirando a +Z) y su gemela trasera.
        ..shadedQuad(
          baseL,
          baseR,
          midR,
          midL,
          GrassPalette.middle,
          GrassPalette.middle,
          GrassPalette.tip,
          GrassPalette.tip,
        )
        ..triangle(midL, midR, tip, GrassPalette.tip)
        ..shadedQuad(
          baseR,
          baseL,
          midL,
          midR,
          GrassPalette.middle,
          GrassPalette.middle,
          GrassPalette.tip,
          GrassPalette.tip,
        )
        ..triangle(midR, midL, tip, GrassPalette.tip))
      .build();
}
