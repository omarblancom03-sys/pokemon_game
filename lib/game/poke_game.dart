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

/// LA ESCENA del juego (vista cenital). No sabe nada de HTTP, diálogos ni
/// providers: avisa con [onSmokeReached] y se maneja desde fuera con
/// [setPaused] y [removeSmoke].
///
/// Los dos "with" añaden capacidades: manejar teclado y detectar colisiones.
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

  /// Se comparte con el D-pad de la pantalla.
  final MovementInput input;

  /// Aviso hacia el controlador: "Ash tocó este humo".
  final void Function(String smokeId) onSmokeReached;

  final Random _random;
  int _respawnCount = 0;

  late final AshComponent ash;

  /// Color de fondo (solo se ve si la cámara se saliera del mapa).
  @override
  Color backgroundColor() => const Color(0xFF0F1A30);

  /// Monta la escena una sola vez, al arrancar el juego.
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

    // La cámara sigue a Ash, pero sin salirse del mapa.
    camera.follow(ash);
    camera.setBounds(
      Rectangle.fromLTRB(0, 0, config.width, config.height),
      considerViewport: true,
    );
  }

  /// Los humos que hay ahora mismo en el mundo.
  Iterable<SmokeComponent> get smokes =>
      world.children.whereType<SmokeComponent>();

  /// Congela o descongela al jugador. No para el motor: lo que se apaga es
  /// la ENTRADA. Se limpia la dirección para que al reanudar Ash no salga
  /// disparado por una tecla que se quedó pulsada.
  void setPaused(bool paused) {
    input.enabled = !paused;
    if (paused) input.clear();
  }

  /// Quita el humo ya usado y programa otro en un punto distinto.
  void removeSmoke(String smokeId) {
    for (final smoke in smokes.where((s) => s.id == smokeId).toList()) {
      smoke.removeFromParent();
    }
    world.add(
      // TimerComponent = temporizador de Flame (aquí, 4 segundos).
      TimerComponent(
        period: config.smokeRespawnSeconds,
        removeOnFinish: true,
        onTick: () => world.add(
          // Id nuevo para no confundirlo con el humo anterior.
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

  /// Punto al azar dentro del mapa, nunca encima de Ash (si no, el
  /// encuentro saltaría al instante).
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
