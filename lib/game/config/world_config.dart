import 'package:flame/extensions.dart';

/// Where a smoke appears at game start.
class SmokeSpawn {
  const SmokeSpawn(this.id, this.x, this.y);

  final String id;
  final double x;
  final double y;
}

/// Static tuning of the game world. Pure data: no Flame components here, so
/// level layout can change without touching game logic.
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

  /// World size in logical pixels.
  final double width;
  final double height;

  /// Size of one ground tile of the placeholder map.
  final double tileSize;

  final double ashWidth;
  final double ashHeight;

  /// Movement speed in pixels per second.
  final double ashSpeed;

  final double smokeRadius;

  /// Delay before a consumed smoke reappears somewhere else.
  final double smokeRespawnSeconds;

  final List<SmokeSpawn> smokeSpawns;

  Vector2 get worldSize => Vector2(width, height);

  Vector2 get ashSize => Vector2(ashWidth, ashHeight);

  Vector2 get ashStart => Vector2(width / 2, height / 2);
}
