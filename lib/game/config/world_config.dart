import 'package:flame/extensions.dart';

/// Punto donde aparece un humo al empezar la partida.
class SmokeSpawn {
  const SmokeSpawn(this.id, this.x, this.y);

  final String id;
  final double x;
  final double y;
}

/// Todos los números ajustables del mundo, en un solo sitio y sin lógica.
/// Cambiar la velocidad o el tamaño del mapa no obliga a tocar el juego.
class WorldConfig {
  const WorldConfig({
    this.width = 1600,
    this.height = 1200,
    this.tileSize = 48,
    this.ashWidth = 32,
    this.ashHeight = 40,
    this.ashSpeed = 180,
    this.smokeRadius = 28,
    this.smokeRespawnSeconds = 4,
    this.smokeSpawns = const [
      SmokeSpawn('smoke-a', 560, 420),
      SmokeSpawn('smoke-b', 1180, 330),
      SmokeSpawn('smoke-c', 300, 950),
      SmokeSpawn('smoke-d', 1300, 900),
    ],
  });

  /// Tamaño del mundo en píxeles (más grande que la pantalla: hay cámara).
  final double width;
  final double height;

  /// Lado de cada baldosa del césped.
  final double tileSize;

  final double ashWidth;
  final double ashHeight;

  /// Velocidad de Ash en píxeles por segundo.
  final double ashSpeed;

  final double smokeRadius;

  /// Segundos que tarda en reaparecer un humo ya usado.
  final double smokeRespawnSeconds;

  final List<SmokeSpawn> smokeSpawns;

  // Vector2 = par de números (x, y): tamaño, posición o dirección.
  Vector2 get worldSize => Vector2(width, height);

  Vector2 get ashSize => Vector2(ashWidth, ashHeight);

  /// Ash empieza en el centro del mapa.
  Vector2 get ashStart => Vector2(width / 2, height / 2);
}
