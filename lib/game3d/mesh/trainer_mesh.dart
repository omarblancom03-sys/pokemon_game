import 'package:vector_math/vector_math.dart';

import 'mesh_builder.dart';

/// Colores del entrenador (gorra roja, chaqueta azul: estilo protagonista).
abstract final class TrainerPalette {
  static final skin = srgb(0xF2C49B);
  static final hair = srgb(0x2B2118);
  static final capRed = srgb(0xE0302B);
  static final capWhite = srgb(0xF7F5F0);
  static final jacket = srgb(0x2F66C8);
  static final jacketDark = srgb(0x244F9E);
  static final shirt = srgb(0xF4F1EA);
  static final jeans = srgb(0x2C3E66);
  static final shoe = srgb(0xD8352E);
  static final sole = srgb(0xF3F3F3);
  static final pack = srgb(0xF2B632);
  static final eye = srgb(0x1B1B22);
  static final glove = srgb(0x2E9E4F);
}

/// Articulaciones (en metros, con el entrenador mirando a +Z y los pies en
/// y = 0). Las piernas cuelgan de la cadera y los brazos del hombro.
abstract final class TrainerJoints {
  static final leftHip = Vector3(0.12, 0.78, 0);
  static final rightHip = Vector3(-0.12, 0.78, 0);
  static final leftShoulder = Vector3(0.27, 1.27, 0);
  static final rightShoulder = Vector3(-0.27, 1.27, 0);
}

/// Piezas del entrenador. Cada extremidad está modelada con su
/// articulación en el origen, para poder girarla sin moverla de sitio.
class TrainerParts {
  const TrainerParts({
    required this.body,
    required this.leg,
    required this.arm,
  });

  /// Tronco, cabeza, gorra y mochila (lo que no se balancea).
  final MeshBuffers body;

  /// Una pierna (sirve para las dos: es simétrica).
  final MeshBuffers leg;

  /// Un brazo (sirve para los dos).
  final MeshBuffers arm;
}

TrainerParts buildTrainerParts() {
  // Cuerpo.
  final body = MeshBuilder()
    // Cadera (vaquero) y torso (chaqueta con cremallera blanca).
    ..box(
      Vector3(-0.2, 0.72, -0.12),
      Vector3(0.2, 0.86, 0.12),
      TrainerPalette.jeans,
    )
    ..box(
      Vector3(-0.23, 0.86, -0.14),
      Vector3(0.23, 1.33, 0.14),
      TrainerPalette.jacket,
      topColor: TrainerPalette.jacketDark,
    )
    ..box(
      Vector3(-0.05, 0.9, 0.14),
      Vector3(0.05, 1.3, 0.155),
      TrainerPalette.shirt,
    )
    // Cuello y cabeza.
    ..prism(
      base: Vector3(0, 1.33, 0),
      bottomRadius: 0.07,
      topRadius: 0.07,
      height: 0.07,
      sides: 6,
      color: TrainerPalette.skin,
    )
    ..gem(Vector3(0, 1.56, 0), Vector3(0.19, 0.2, 0.18), TrainerPalette.skin)
    // Pelo asomando bajo la gorra (detrás y a los lados).
    ..gem(
      Vector3(0, 1.58, -0.05),
      Vector3(0.2, 0.17, 0.16),
      TrainerPalette.hair,
    )
    // Ojos.
    ..box(
      Vector3(0.055, 1.55, 0.155),
      Vector3(0.095, 1.62, 0.185),
      TrainerPalette.eye,
    )
    ..box(
      Vector3(-0.095, 1.55, 0.155),
      Vector3(-0.055, 1.62, 0.185),
      TrainerPalette.eye,
    )
    // Gorra: copa roja, frente blanco y visera.
    ..gem(Vector3(0, 1.68, 0), Vector3(0.21, 0.13, 0.2), TrainerPalette.capRed)
    ..box(
      Vector3(-0.1, 1.64, 0.13),
      Vector3(0.1, 1.77, 0.2),
      TrainerPalette.capWhite,
    )
    ..box(
      Vector3(-0.15, 1.63, 0.12),
      Vector3(0.15, 1.66, 0.36),
      TrainerPalette.capRed,
    )
    // Mochila.
    ..box(
      Vector3(-0.18, 0.9, -0.3),
      Vector3(0.18, 1.28, -0.14),
      TrainerPalette.pack,
    )
    ..box(
      Vector3(-0.14, 0.93, -0.33),
      Vector3(0.14, 1.07, -0.3),
      TrainerPalette.pack,
    );

  // Pierna (cadera en el origen): vaquero + zapatilla roja con suela.
  final leg = MeshBuilder()
    ..box(
      Vector3(-0.08, -0.66, -0.08),
      Vector3(0.08, 0, 0.08),
      TrainerPalette.jeans,
    )
    ..box(
      Vector3(-0.09, -0.78, -0.1),
      Vector3(0.09, -0.66, 0.16),
      TrainerPalette.shoe,
    )
    ..box(
      Vector3(-0.095, -0.8, -0.105),
      Vector3(0.095, -0.76, 0.165),
      TrainerPalette.sole,
    );

  // Brazo (hombro en el origen): manga azul, antebrazo y guante.
  final arm = MeshBuilder()
    ..box(
      Vector3(-0.065, -0.3, -0.065),
      Vector3(0.065, 0.03, 0.065),
      TrainerPalette.jacket,
    )
    ..box(
      Vector3(-0.055, -0.5, -0.055),
      Vector3(0.055, -0.3, 0.055),
      TrainerPalette.shirt,
    )
    ..gem(
      Vector3(0, -0.56, 0),
      Vector3(0.07, 0.07, 0.07),
      TrainerPalette.glove,
      detail: 0,
    );

  return TrainerParts(body: body.build(), leg: leg.build(), arm: arm.build());
}
