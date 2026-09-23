import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'mesh_builder.dart';

/// Piezas de los EFECTOS de la captura (se dibujan sin luz, con colores
/// que pueden pasar de 1 para que el "bloom" las haga brillar).

/// Estrella de cinco puntas con algo de grosor, de radio 1, plana en el
/// plano XY (mira hacia ±Z).
MeshBuffers buildStar(Vector4 color, {double depth = 0.3}) {
  final b = MeshBuilder();
  final points = [
    for (var i = 0; i < 10; i++)
      () {
        final a = math.pi / 2 + i * math.pi / 5;
        final r = i.isEven ? 1.0 : 0.45;
        return Vector3(math.cos(a) * r, math.sin(a) * r, 0);
      }(),
  ];
  final front = Vector3(0, 0, depth / 2);
  final back = Vector3(0, 0, -depth / 2);
  for (var i = 0; i < 10; i++) {
    final a = points[i];
    final c = points[(i + 1) % 10];
    // Cara delantera y trasera (la estrella "abombada": centro más grueso).
    b
      ..triangle(front, a, c, color)
      ..triangle(back, c, a, color);
  }
  return b.build();
}

/// Anillo plano en el suelo (radio interior [inner], exterior [outer]),
/// visible por las dos caras: marca dónde caerá la bola.
MeshBuffers buildRing(Vector4 color, {double inner = 0.8, double outer = 1}) {
  final b = MeshBuilder();
  const segments = 24;
  for (var i = 0; i < segments; i++) {
    final a0 = i / segments * 2 * math.pi;
    final a1 = (i + 1) / segments * 2 * math.pi;
    Vector3 at(double a, double r) =>
        Vector3(math.cos(a) * r, 0, math.sin(a) * r);
    final p0 = at(a0, inner);
    final p1 = at(a0, outer);
    final p2 = at(a1, outer);
    final p3 = at(a1, inner);
    b
      ..quad(p0, p3, p2, p1, color) // mirando hacia arriba
      ..quad(p0, p1, p2, p3, color); // y hacia abajo
  }
  return b.build();
}
