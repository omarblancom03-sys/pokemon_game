import 'dart:math';
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';

import 'art/game_art.dart';
import 'components/ash_component.dart';
import 'components/map_component.dart';
import 'components/smoke_component.dart';
import 'config/world_config.dart';
import 'input/keyboard_movement_component.dart';
import 'input/movement_input.dart';
import 'map/map_layout.dart';
import 'map/tile_map_component.dart';
import 'map/world_map.dart';
import 'visuals/ash_sprite_visual.dart';

/// Carga el arte del juego. Se inyecta para que los tests puedan no pasarla.
typedef ArtLoader = Future<GameArt> Function(Images images);

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
    this.loadArt,
    MapLayout? layout,
    MovementInput? input,
    Random? random,
  }) : layout = layout ?? MapLayout.parse(worldMapRows),
       input = input ?? MovementInput(),
       _random = random ?? Random();

  final WorldConfig config;

  /// Qué hay en cada casilla (árboles, caminos...).
  final MapLayout layout;

  /// Si es null, se dibuja con figuras simples (placeholders).
  final ArtLoader? loadArt;

  /// Se comparte con el D-pad de la pantalla.
  final MovementInput input;

  /// Aviso hacia el controlador: "Ash tocó este humo".
  final void Function(String smokeId) onSmokeReached;

  final Random _random;
  int _respawnCount = 0;

  late final AshComponent ash;

  /// Tamaño del mundo en píxeles: casillas x lado de cada baldosa.
  Vector2 get worldSize =>
      Vector2(layout.columns * config.tileSize, layout.rows * config.tileSize);

  /// Color de fondo (solo se ve si la cámara se saliera del mapa).
  @override
  Color backgroundColor() => const Color(0xFF0F1A30);

  /// Monta la escena una sola vez, al arrancar el juego.
  @override
  Future<void> onLoad() async {
    final art = await loadArt?.call(images);
    final tile = config.tileSize;

    // Ash empieza con los pies dentro de la casilla `@` del mapa.
    final start = Vector2(
      (layout.start.col + 0.5) * tile,
      (layout.start.row + 1) * tile - config.ashHeight / 2 - 2,
    );
    ash = AshComponent(
      input: input,
      bounds: worldSize,
      speed: config.ashSpeed,
      position: start,
      size: config.ashSize,
      visual: art == null
          ? null
          : AshSpriteVisual(art: art, size: config.ashSize),
      canOccupy: (feet) => layout.isAreaWalkable(feet, tile),
    );

    await world.addAll([
      if (art == null)
        MapComponent(layout: layout, tileSize: tile)
      else
        ...buildTileMap(layout: layout, art: art, tileSize: tile),
      for (final spawn in config.smokeSpawns)
        _buildSmoke(spawn.id, Vector2(spawn.x, spawn.y)),
      ash,
      KeyboardMovementComponent(input: input),
    ]);

    // La cámara sigue a Ash, pero sin salirse del mapa.
    camera.follow(ash);
    camera.setBounds(
      Rectangle.fromLTRB(0, 0, worldSize.x, worldSize.y),
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
  )..priority = position.y.round(); // y-sorting, como Ash y los árboles

  /// Centro de una casilla pisable al azar, nunca cerca de Ash (si no, el
  /// encuentro saltaría al instante).
  Vector2 _randomSpawnPoint() {
    final tile = config.tileSize;
    final candidates = [
      for (final cell in layout.walkableCells)
        Vector2((cell.col + 0.5) * tile, (cell.row + 0.5) * tile),
    ]..removeWhere((p) => p.distanceTo(ash.position) < 200);
    return candidates[_random.nextInt(candidates.length)];
  }
}
