import 'dart:async';
import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../../game/input/movement_input.dart';
import '../../game/map/map_layout.dart';
import '../../models/pokemon.dart';
import 'camera_input.dart';
import 'grass_field.dart';
import 'orbit_camera.dart';
import 'player_body.dart';
import 'wild_pokemon.dart';
import 'world3d_config.dart';

/// Pide un Pokémon para hacer aparecer en la hierba (null = ahora no).
typedef WildSpawnSource = Future<Pokemon?> Function();

/// LA SIMULACIÓN del mundo 3D: jugador, cámara, hierba alta y Pokémon
/// salvajes sobre el mapa ASCII.
///
/// No dibuja nada ni conoce el motor: el renderer llama a [update] en cada
/// fotograma y luego lee el estado para colocar la escena. Avisa hacia
/// fuera con [onWildContact] (tocó un Pokémon visible) y [onGrassEncounter]
/// (encuentro al azar andando por la hierba). Por eso toda la jugabilidad
/// se puede probar con tests normales.
class World3DSim {
  World3DSim({
    required this.layout,
    this.config = const World3DConfig(),
    MovementInput? input,
    CameraInput? cameraInput,
    OrbitCamera? camera,
    math.Random? random,
    this.spawnWild,
    this.onWildContact,
    this.onGrassEncounter,
  }) : input = input ?? MovementInput(),
       cameraInput = cameraInput ?? CameraInput(),
       camera = camera ?? OrbitCamera(),
       _random = random ?? math.Random() {
    player = PlayerBody(
      config: config,
      canOccupy: (footprint) =>
          layout.isAreaWalkable(footprint, config.tileSize),
      position: cellCenter(layout.start.col, layout.start.row),
    );
    grass = GrassField.fromLayout(layout, config.tileSize);
    _tallGrassCells = [
      for (final cell in layout.walkableCells)
        if (layout.tileAt(cell.col, cell.row) == TileKind.tallGrass) cell,
    ];
    _lastDistance = player.distanceWalked;
  }

  final MapLayout layout;
  final World3DConfig config;

  /// Movimiento (teclado + D-pad), compartido con el modo 2D.
  final MovementInput input;
  final CameraInput cameraInput;
  final OrbitCamera camera;
  late final PlayerBody player;
  late final GrassField grass;

  final WildSpawnSource? spawnWild;
  final void Function(WildPokemon wild)? onWildContact;
  final void Function()? onGrassEncounter;

  final math.Random _random;
  late final List<({int col, int row})> _tallGrassCells;

  /// Pokémon salvajes visibles ahora mismo.
  final List<WildPokemon> wild = [];

  /// Segundos de simulación transcurridos (para animaciones).
  double time = 0;

  bool _paused = false;
  bool _disposed = false;
  int _pendingSpawns = 0;
  int _spawnCount = 0;
  double _spawnTimer = 0.5;
  double _grace = 0;
  double _grassMeters = 0;
  double _lastDistance = 0;

  /// Radianes por segundo al girar con Q/E.
  static const keyTurnSpeed = 2.2;

  /// Radianes por píxel arrastrado con el ratón.
  static const dragSensitivity = 0.008;

  /// Máximo de Pokémon visibles a la vez.
  static const maxWild = 6;

  /// Segundos entre apariciones.
  static const spawnInterval = 2.5;

  /// Nunca aparecen más cerca de esto del jugador (m).
  static const minSpawnDistance = 9.0;

  /// Probabilidad de encuentro por cada metro andado en hierba alta.
  static const grassEncounterChance = 0.035;

  /// Segundos sin encuentros tras reanudar (para no encadenarlos).
  static const graceSeconds = 2.0;

  /// Tamaño del mundo en metros (ancho en X, fondo en Z).
  double get width => layout.columns * config.tileSize;
  double get depth => layout.rows * config.tileSize;

  bool get isPaused => _paused;

  /// Centro de una casilla, en metros (y = 0: el suelo).
  Vector3 cellCenter(int col, int row) =>
      Vector3((col + 0.5) * config.tileSize, 0, (row + 0.5) * config.tileSize);

  /// Casilla bajo un punto del mundo.
  ({int col, int row}) cellAt(Vector3 p) => (
    col: (p.x / config.tileSize).floor(),
    row: (p.z / config.tileSize).floor(),
  );

  bool isTallGrass(Vector3 p) {
    final cell = cellAt(p);
    return layout.tileAt(cell.col, cell.row) == TileKind.tallGrass;
  }

  /// Congela (encuentro en marcha) o reanuda el mundo. Al congelar se
  /// suelta la entrada para que nadie salga disparado al reanudar.
  void setPaused(bool paused) {
    if (paused == _paused) return;
    _paused = paused;
    input.enabled = !paused;
    if (paused) {
      input.clear();
    } else {
      _grace = graceSeconds;
    }
  }

  /// Quita un Pokémon salvaje (tras su encuentro).
  void removeWild(String id) => wild.removeWhere((w) => w.id == id);

  /// Deja de aceptar Pokémon que lleguen tarde (la pantalla se cerró).
  void dispose() => _disposed = true;

  /// Avanza la simulación [dt] segundos.
  void update(double dt) {
    time += dt;
    _updateCamera(dt);

    // Jugador: la dirección pulsada es RELATIVA A LA CÁMARA
    // (arriba = alejarse de la cámara), como en GTA.
    final dir = input.direction; // x: derecha, y: abajo (convención 2D)
    final wish = camera.right * dir.x + camera.forward * -dir.y;
    player.update(dt, wish, running: cameraInput.running && input.enabled);

    final moved = player.distanceWalked - _lastDistance;
    _lastDistance = player.distanceWalked;
    if (_paused) return;

    for (final w in wild) {
      _wander(w, dt);
    }
    _maybeSpawn(dt);

    if (_grace > 0) {
      _grace -= dt;
      return;
    }
    if (_checkContacts()) return;
    _checkGrassSteps(moved);
  }

  void _updateCamera(double dt) {
    final (dragX, dragY) = cameraInput.takeDrag();
    camera
      ..rotate(
        -dragX * dragSensitivity + cameraInput.turnAxis * keyTurnSpeed * dt,
        dragY * dragSensitivity,
      )
      ..zoom(cameraInput.takeZoom());
  }

  /// Todos los que apartan la hierba al pasar: jugador y Pokémon.
  Iterable<Vector3> get grassPushers sync* {
    yield player.position;
    for (final w in wild) {
      yield w.position;
    }
  }

  // --- Pokémon salvajes -------------------------------------------------

  void _maybeSpawn(double dt) {
    final source = spawnWild;
    if (source == null || _tallGrassCells.isEmpty) return;
    _spawnTimer -= dt;
    if (_spawnTimer > 0 || wild.length + _pendingSpawns >= maxWild) return;
    _spawnTimer = spawnInterval;

    _pendingSpawns++;
    unawaited(
      source()
          .then((pokemon) {
            _pendingSpawns--;
            if (pokemon != null && !_disposed) spawn(pokemon);
          })
          .catchError((Object _) {
            _pendingSpawns--; // sin red: se reintentará en el siguiente turno
          }),
    );
  }

  /// Hace aparecer [pokemon] en una casilla de hierba alta lejos del
  /// jugador y de los demás. Devuelve null si no hay sitio.
  WildPokemon? spawn(Pokemon pokemon) {
    final playerPos = player.position;
    final spots =
        [for (final cell in _tallGrassCells) cellCenter(cell.col, cell.row)]
          ..removeWhere(
            (p) =>
                p.distanceTo(playerPos) < minSpawnDistance ||
                wild.any((w) => w.position.distanceTo(p) < 3),
          );
    if (spots.isEmpty) return null;
    final spot = spots[_random.nextInt(spots.length)];
    final w = WildPokemon(
      id: 'wild-${_spawnCount++}',
      pokemon: pokemon,
      position: spot,
      facing: _random.nextDouble() * 2 * math.pi,
    )..idleTime = _random.nextDouble() * 2;
    wild.add(w);
    return w;
  }

  /// Paseo aleatorio sin salir de la hierba alta.
  void _wander(WildPokemon w, double dt) {
    w.age += dt;
    final target = w.target;
    if (target == null) {
      w.idleTime -= dt;
      if (w.idleTime <= 0) w.target = _pickWanderTarget(w);
      return;
    }
    final toTarget = target - w.position
      ..y = 0;
    final dist = toTarget.length;
    if (dist < 0.1) {
      w
        ..target = null
        ..idleTime = 1 + _random.nextDouble() * 2.5;
      return;
    }
    final step = math.min(dist, WildPokemon.wanderSpeed * dt);
    final next = w.position + toTarget.normalized() * step;
    if (!isTallGrass(next)) {
      w
        ..target = null
        ..idleTime = 0.5;
      return;
    }
    w
      ..position = next
      ..distanceMoved += step
      ..facing = math.atan2(toTarget.x, toTarget.z);
  }

  Vector3? _pickWanderTarget(WildPokemon w) {
    final here = cellAt(w.position);
    final near = _tallGrassCells
        .where(
          (c) => (c.col - here.col).abs() <= 3 && (c.row - here.row).abs() <= 3,
        )
        .toList();
    if (near.isEmpty) return null;
    final cell = near[_random.nextInt(near.length)];
    final jitter = config.tileSize * 0.3;
    return cellCenter(cell.col, cell.row) +
        Vector3(
          (_random.nextDouble() - 0.5) * jitter,
          0,
          (_random.nextDouble() - 0.5) * jitter,
        );
  }

  // --- Encuentros --------------------------------------------------------

  /// ¿Toca el jugador algún Pokémon? Dispara como mucho uno.
  bool _checkContacts() {
    final p = player.position;
    for (final w in wild) {
      if (w.engaged) continue;
      if (w.position.distanceTo(p) < w.contactRadius) {
        w.engaged = true;
        onWildContact?.call(w);
        return true;
      }
    }
    return false;
  }

  /// Cada metro andado por la hierba alta tiene una probabilidad de
  /// encuentro al azar (como los pasos en los juegos clásicos).
  void _checkGrassSteps(double moved) {
    if (moved <= 0 || !isTallGrass(player.position)) return;
    _grassMeters += moved;
    while (_grassMeters >= 1) {
      _grassMeters -= 1;
      if (_random.nextDouble() < grassEncounterChance) {
        _grassMeters = 0;
        onGrassEncounter?.call();
        return;
      }
    }
  }
}
