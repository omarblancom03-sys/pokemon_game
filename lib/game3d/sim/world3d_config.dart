/// Números ajustables del mundo 3D, en un solo sitio y sin lógica.
/// Unidades: metros y segundos. Cada casilla del mapa ASCII mide
/// [tileSize] x [tileSize] metros en el suelo.
class World3DConfig {
  const World3DConfig({
    this.tileSize = 2,
    this.playerRadius = 0.35,
    this.walkSpeed = 4.5,
    this.runSpeed = 7.5,
    this.crouchSpeed = 2.1,
    this.acceleration = 30,
    this.turnSpeed = 12,
  });

  final double tileSize;

  /// El jugador choca como un círculo de este radio (visto desde arriba).
  final double playerRadius;

  /// Velocidades en metros por segundo (andar y correr con Mayús).
  final double walkSpeed;
  final double runSpeed;

  /// Velocidad agachado (sigilo): lenta pero silenciosa.
  final double crouchSpeed;

  /// Cuánto tarda en alcanzar la velocidad deseada (m/s²).
  final double acceleration;

  /// Rapidez con la que el cuerpo gira hacia donde camina (más = más brusco).
  final double turnSpeed;
}
