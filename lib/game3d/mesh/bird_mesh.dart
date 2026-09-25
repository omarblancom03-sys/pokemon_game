import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'mesh_builder.dart';

/// Cuerpo de pájaro con las patas en el origen y el pico hacia +Z: cuerpo,
/// cabeza, pico naranja y cola. Casi blanco: el plumaje de cada pájaro se
/// multiplica por encima (el pico queda de un naranja más o menos oscuro).
MeshBuffers buildBirdBody() {
  final feather = srgb(0xF2EEE8);
  final belly = srgb(0xFFFFFF);
  final beak = srgb(0xF2A33A);
  final eye = srgb(0x202020);
  Vector4 shade(Vector3 dir) => dir.y < -0.3 ? belly : feather;
  final b = MeshBuilder()
    // Cuerpo y cabeza.
    ..gem(
      Vector3(0, 0.09, 0),
      Vector3(0.055, 0.052, 0.095),
      feather,
      colorAt: shade,
    )
    ..gem(Vector3(0, 0.145, 0.075), Vector3.all(0.042), feather)
    // Ojos.
    ..gem(Vector3(0.03, 0.155, 0.095), Vector3.all(0.009), eye)
    ..gem(Vector3(-0.03, 0.155, 0.095), Vector3.all(0.009), eye);
  // Pico: una punta hacia delante (un prisma vertical girado hacia +Z).
  b.withTransform(
    Matrix4.translation(Vector3(0, 0.14, 0.108))..rotateX(math.pi / 2),
    () => b.prism(
      base: Vector3.zero(),
      bottomRadius: 0.014,
      topRadius: 0.001,
      height: 0.04,
      sides: 4,
      color: beak,
    ),
  );
  // Cola: una cuña plana hacia atrás (dos caras).
  final t0 = Vector3(-0.03, 0.1, -0.07);
  final t1 = Vector3(0.03, 0.1, -0.07);
  final t2 = Vector3(0.045, 0.12, -0.17);
  final t3 = Vector3(-0.045, 0.12, -0.17);
  b
    ..quad(t0, t1, t2, t3, feather)
    ..quad(t0, t3, t2, t1, feather);
  return b.build();
}

/// Ala de pájaro (derecha: hacia +X; [left] la refleja hacia -X), con la
/// bisagra en el eje Z (el pájaro mira hacia +Z). Casi blanca y más
/// oscura en la punta; de doble cara.
MeshBuffers buildBirdWing({bool left = false}) {
  final s = left ? -1.0 : 1.0;
  final root = srgb(0xF2EEE8);
  final tip = srgb(0x9A948C);
  final a = Vector3(0, 0, 0.05);
  final b = Vector3(0.2 * s, 0, 0.0);
  final c = Vector3(0.17 * s, 0, -0.07);
  final d = Vector3(0, 0, -0.05);
  final m = MeshBuilder();
  // Arriba y abajo (orden contrario para cada cara).
  m
    ..shadedQuad(a, b, c, d, root, tip, tip, root)
    ..shadedQuad(a, d, c, b, root, root, tip, tip);
  return m.build();
}
