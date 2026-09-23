import 'package:flame/extensions.dart';

/// Punto donde aparece un humo al empezar la partida (en píxeles).
class SmokeSpawn {
  const SmokeSpawn(this.id, this.x, this.y);

  final String id;
  final double x;
  final double y;
}

/// Todos los números ajustables del mundo, en un solo sitio y sin lógica.
/// El TAMAÑO del mundo y el inicio de Ash ya no están aquí: salen del mapa
/// ASCII (MapLayout), que es quien sabe cuántas baldosas hay.
class WorldConfig {
  const WorldConfig({
    this.tileSize = 48,
    this.ashWidth = 42,
    this.ashHeight = 66,
    this.ashSpeed = 180,
    this.smokeRadius = 28,
    this.smokeRespawnSeconds = 4,
    this.smokeSpawns = const [
      // Centros de casillas de pasto alto o césped (col * 48 + 24).
      SmokeSpawn('smoke-a', 1224, 216),
      SmokeSpawn('smoke-b', 360, 840),
      SmokeSpawn('smoke-c', 1176, 408),
      SmokeSpawn('smoke-d', 1368, 936),
    ],
  });

  /// Lado de cada baldosa en pantalla: el arte mide 16 px y se dibuja x3.
  final double tileSize;

  /// Ash mide 14x22 px en el sprite; x3 = 42x66.
  final double ashWidth;
  final double ashHeight;

  /// Velocidad de Ash en píxeles por segundo.
  final double ashSpeed;

  final double smokeRadius;

  /// Segundos que tarda en reaparecer un humo ya usado.
  final double smokeRespawnSeconds;

  final List<SmokeSpawn> smokeSpawns;

  // Vector2 = par de números (x, y): tamaño, posición o dirección.
  Vector2 get ashSize => Vector2(ashWidth, ashHeight);
}
