import 'package:vector_math/vector_math.dart';

import '../../models/poke_ball.dart';
import 'mesh_builder.dart';

/// Colores de las Poké Balls (sRGB → lineal con [srgb]).
abstract final class BallPalette {
  static final red = srgb(0xE53935);
  static final blue = srgb(0x2D6CDF);
  static final black = srgb(0x303030);
  static final yellow = srgb(0xF4C430);
  static final white = srgb(0xF2F2F2);
  static final band = srgb(0x2B2B2B);
  static final button = srgb(0xFAFAFA);
}

/// Una Poké Ball en dos mitades para poder ABRIRLA (al absorber al Pokémon
/// o cuando se escapa): la tapa gira sobre la bisagra trasera.
///
/// [top] ya está desplazada para que su origen sea la bisagra
/// ([hinge], en la parte de atrás de la bola); [bottom] tiene el origen en
/// el centro de la bola. El botón mira hacia +Z.
typedef PokeBallParts = ({MeshBuffers top, MeshBuffers bottom, Vector3 hinge});

/// Color de la cara que mira en la dirección [d] (unitaria desde el centro).
Vector4 pokeBallColor(PokeBallType type, Vector3 d) {
  // Botón delantero con su aro negro, y la franja negra del ecuador.
  if (d.z > 0.93) return BallPalette.button;
  if (d.z > 0.8 && d.y.abs() < 0.38) return BallPalette.band;
  if (d.y.abs() < 0.1) return BallPalette.band;
  if (d.y < 0) return BallPalette.white;
  return switch (type) {
    PokeBallType.poke => BallPalette.red,
    // Super Ball: azul con dos "alas" rojas a los lados.
    PokeBallType.great =>
      d.x.abs() > 0.45 && d.y > 0.3 && d.z.abs() < 0.6
          ? BallPalette.red
          : BallPalette.blue,
    // Ultra Ball: negra con la "H" amarilla.
    PokeBallType.ultra =>
      d.x.abs() > 0.4 && d.x.abs() < 0.85 && d.y > 0.2
          ? BallPalette.yellow
          : BallPalette.black,
  };
}

/// Poké Ball entera de radio [radius], centrada en el origen.
MeshBuffers buildPokeBall(PokeBallType type, {double radius = 1}) {
  final b = MeshBuilder()
    ..gem(
      Vector3.zero(),
      Vector3.all(radius),
      BallPalette.white,
      detail: 3,
      colorAt: (d) => pokeBallColor(type, d),
    );
  return b.build();
}

/// La misma bola partida en tapa y base (ver [PokeBallParts]).
PokeBallParts buildPokeBallParts(PokeBallType type, {double radius = 1}) {
  final hinge = Vector3(0, 0, -radius);
  final top = MeshBuilder()..push(Matrix4.translation(-hinge));
  final bottom = MeshBuilder();
  final whole = buildPokeBall(type, radius: radius);
  // Reparte cada triángulo según la altura de su centro.
  final p = whole.positions;
  final c = whole.colors;
  Vector3 vertex(int i) => Vector3(p[i * 3], p[i * 3 + 1], p[i * 3 + 2]);
  Vector4 color(int i) =>
      Vector4(c[i * 4], c[i * 4 + 1], c[i * 4 + 2], c[i * 4 + 3]);
  for (var t = 0; t < whole.indices.length; t += 3) {
    final [i, j, k] = whole.indices.sublist(t, t + 3);
    final centerY = (vertex(i).y + vertex(j).y + vertex(k).y) / 3;
    (centerY >= 0 ? top : bottom).shadedTriangle(
      vertex(i),
      vertex(j),
      vertex(k),
      color(i),
      color(j),
      color(k),
    );
  }
  return (top: top.build(), bottom: bottom.build(), hinge: hinge);
}

/// Haz de luz vertical (dos planos cruzados) que se desvanece hacia
/// arriba: marca desde lejos dónde hay algo que recoger. [color] lleva el
/// brillo en rgb (puede pasar de 1 para que el "bloom" lo haga resplandecer)
/// y la opacidad de la base en alfa.
MeshBuffers buildGlowBeam(
  Vector4 color, {
  double width = 0.55,
  double height = 2.4,
}) {
  final b = MeshBuilder();
  final top = Vector4(color.x, color.y, color.z, 0);
  final w = width / 2;
  for (final (dx, dz) in [(w, 0.0), (0.0, w)]) {
    final a = Vector3(-dx, 0, -dz);
    final bb = Vector3(dx, 0, dz);
    final c = Vector3(dx, height, dz);
    final d = Vector3(-dx, height, -dz);
    // Las dos caras (se ve desde cualquier lado).
    b
      ..shadedTriangle(a, bb, c, color, color, top)
      ..shadedTriangle(a, c, d, color, top, top)
      ..shadedTriangle(a, c, bb, color, top, color)
      ..shadedTriangle(a, d, c, color, top, top);
  }
  return b.build();
}
