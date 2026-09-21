import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';

import 'components/ash_component.dart';
import 'components/map_component.dart';
import 'components/smoke_component.dart';
import 'config/world_config.dart';
import 'input/keyboard_movement_component.dart';
import 'input/movement_input.dart';

/// Top-down overworld scene. Knows nothing about HTTP, dialogs or providers:
/// it reports [onSmokeReached] and is driven through [setPaused] and
/// [removeSmoke].
class PokeGame extends FlameGame
    with HasKeyboardHandlerComponents, HasCollisionDetection {
  PokeGame({
    required this.onSmokeReached,
    this.config = const WorldConfig(),
    MovementInput? input,
    Random? random,
  }) : input = input ?? MovementInput(),
       _random = random ?? Random();

  final WorldConfig config;

  /// Shared with the on-screen D-pad.
  final MovementInput input;

  final void Function(String smokeId) onSmokeReached;

  final Random _random;
  int _respawnCount = 0;

  late final AshComponent ash;

  @override
  Color backgroundColor() => const Color(0xFF0F1A30);

  @override
  Future<void> onLoad() async {
    ash = AshComponent(
      input: input,
      bounds: config.worldSize,
      speed: config.ashSpeed,
      position: config.ashStart,
      size: config.ashSize,
    );

    await world.addAll([
      MapComponent(config: config),
      for (final spawn in config.smokeSpawns)
        _buildSmoke(spawn.id, Vector2(spawn.x, spawn.y)),
      ash,
      KeyboardMovementComponent(input: input),
    ]);

    camera.follow(ash);
    camera.setBounds(
      Rectangle.fromLTRB(0, 0, config.width, config.height),
      considerViewport: true,
    );
  }

  Iterable<SmokeComponent> get smokes =>
      world.children.whereType<SmokeComponent>();

  /// Freezes or unfreezes player movement.
  void setPaused(bool paused) {
    input.enabled = !paused;
    if (paused) input.clear();
  }

  /// Removes a consumed smoke and schedules a new one elsewhere.
  void removeSmoke(String smokeId) {
    for (final smoke in smokes.where((s) => s.id == smokeId).toList()) {
      smoke.removeFromParent();
    }
    world.add(
      TimerComponent(
        period: config.smokeRespawnSeconds,
        removeOnFinish: true,
        onTick: () => world.add(
          _buildSmoke('smoke-respawn-${_respawnCount++}', _randomSpawnPoint()),
        ),
      ),
    );
  }

  SmokeComponent _buildSmoke(String id, Vector2 position) => SmokeComponent(
    id: id,
    position: position,
    radius: config.smokeRadius,
    onAshReached: onSmokeReached,
  );

  /// Random point inside the map, not on top of Ash.
  Vector2 _randomSpawnPoint() {
    final margin = config.smokeRadius * 2;
    Vector2 point;
    do {
      point = Vector2(
        margin + _random.nextDouble() * (config.width - margin * 2),
        margin + _random.nextDouble() * (config.height - margin * 2),
      );
    } while (point.distanceTo(ash.position) < 200);
    return point;
  }
}
