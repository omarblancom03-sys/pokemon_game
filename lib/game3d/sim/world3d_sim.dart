import 'dart:async';
import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../../controllers/capture/capture_calculator.dart';
import '../../game/input/movement_input.dart';
import '../../game/map/map_layout.dart';
import '../../models/poke_ball.dart';
import '../../models/pokemon.dart';
import 'aiming.dart';
import 'camera_input.dart';
import 'field_items.dart';
import 'grass_field.dart';
import 'orbit_camera.dart';
import 'player_body.dart';
import 'throwing.dart';
import 'wild_pokemon.dart';
import 'world3d_config.dart';
import 'world3d_events.dart';

export 'field_items.dart' show GroundItem;
export 'throwing.dart' show BallPhase, ThrownBall;
export 'world3d_events.dart';

/// Un Pokémon para hacer aparecer, con su ratio de captura real.
typedef WildSpawn = ({Pokemon pokemon, int captureRate});

/// Pide un Pokémon para hacer aparecer en la hierba (null = ahora no).
typedef WildSpawnSource = Future<WildSpawn?> Function();

/// LA SIMULACIÓN del mundo 3D: jugador, cámara, hierba alta, Pokémon
/// salvajes, Poké Balls en el suelo y lanzadas, sobre el mapa ASCII.
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
    this.onEvent,
    int maxFieldItems = 6,
    CaptureCalculator? calculator,
  }) : input = input ?? MovementInput(),
       cameraInput = cameraInput ?? CameraInput(),
       camera = camera ?? OrbitCamera(),
       _random = random ?? math.Random() {
    ballSystem = BallSystem(
      layout: layout,
      tileSize: config.tileSize,
      calculator: calculator ?? CaptureCalculator(random: _random),
    );
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
    fieldItems = FieldItems(
      layout: layout,
      tileSize: config.tileSize,
      random: _random,
      maxItems: maxFieldItems,
    )..fill(player.position);
  }

  final MapLayout layout;
  final World3DConfig config;

  /// Movimiento (teclado + D-pad), compartido con el modo 2D.
  final MovementInput input;
  final CameraInput cameraInput;
  final OrbitCamera camera;
  late final PlayerBody player;
  late final GrassField grass;

  /// Poké Balls en el suelo para recoger.
  late final FieldItems fieldItems;

  /// Poké Balls lanzadas (vuelo, choques y secuencia de captura).
  late final BallSystem ballSystem;

  /// El jugador está apuntando (botón derecho / tecla): la cámara se pone
  /// al hombro, el cuerpo mira adonde apunta la cámara y no se corre.
  bool aiming = false;

  /// Pokémon al que se lanzaría ahora mismo (null = tiro a ojo).
  WildPokemon? lockedTarget;

  /// Bola elegida en la bolsa (la pone la pantalla); null = bolsa vacía.
  PokeBallType? readyBall = PokeBallType.poke;

  final WildSpawnSource? spawnWild;
  final void Function(WildPokemon wild)? onWildContact;
  final void Function()? onGrassEncounter;

  /// Recogidas, capturas, bolas falladas... (ver [World3DEvent]).
  final void Function(World3DEvent event)? onEvent;

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

  // Lanzamiento en curso: tiempo desde que empezó, bola y objetivo.
  double? _throwTime;
  PokeBallType? _throwBall;
  WildPokemon? _throwTarget;
  bool _released = false;

  /// Duración de la animación de lanzar y momento en que suelta la bola.
  static const throwDuration = 0.5;
  static const releaseTime = 0.18;

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

  void _emit(World3DEvent event) => onEvent?.call(event);

  /// 0..1 mientras dura la animación de lanzar; null si no lanza.
  double? get throwProgress =>
      _throwTime == null ? null : _throwTime! / throwDuration;

  /// ¿Se puede lanzar ahora? (una bola cada vez que termina el gesto).
  bool get canThrow => !_paused && _throwTime == null;

  /// Bola que se ve en la mano: al apuntar, la elegida; al lanzar, la
  /// lanzada hasta que sale de la mano.
  PokeBallType? get heldBall {
    if (_throwTime != null) return _released ? null : _throwBall;
    return aiming ? readyBall : null;
  }

  /// Probabilidad de capturar al objetivo fijado con la bola elegida
  /// (null si no hay objetivo o no quedan bolas).
  double? get lockedChance {
    final target = lockedTarget;
    final ball = readyBall;
    if (target == null || ball == null) return null;
    final toTarget = target.position - player.position
      ..y = 0;
    if (toTarget.length2 > 0) toTarget.normalize();
    return CaptureCalculator.chance(
      captureRate: target.captureRate,
      ball: ball,
      unaware: !target.isAlert,
      fromBehind: toTarget.dot(target.facingDirection) > 0.5,
    );
  }

  /// Bolas en el aire o en el suelo con un Pokémon dentro.
  List<ThrownBall> get balls => ballSystem.balls;

  /// Empieza a lanzar [ball] al objetivo fijado (o hacia donde mira la
  /// cámara). La bola sale de la mano un instante después, cuando el brazo
  /// pasa por delante. Devuelve false si ahora no se puede.
  bool throwBall(PokeBallType ball) {
    if (!canThrow) return false;
    _throwTime = 0;
    _throwBall = ball;
    _throwTarget = lockedTarget;
    _released = false;
    return true;
  }

  /// Hacia dónde mira el cuerpo al apuntar o lanzar (en el suelo).
  Vector3 get _aimDirection {
    final target = _throwTarget ?? lockedTarget;
    if (target != null) {
      final to = target.position - player.position
        ..y = 0;
      if (to.length2 > 1e-6) return to..normalize();
    }
    return camera.forward;
  }

  /// De dónde sale la bola: la mano derecha (o el pecho si la mano queda
  /// dentro de un árbol, pegado a él).
  Vector3 get _hand {
    final hand = handPosition(player.position, player.facing);
    if (hand.y > ballSystem.heightAt(hand.x, hand.z)) return hand;
    return player.position + Vector3(0, 1.55, 0);
  }

  Vector3 _releaseVelocity(Vector3 hand, WildPokemon? target) {
    if (target != null && target.isFree) {
      final v = lockedThrowVelocity(hand, target);
      if (v != null) return v;
    }
    return freeThrowVelocity(camera);
  }

  /// Trayectoria que seguiría la bola si se lanzara ahora (se dibuja al
  /// apuntar). Vacía si no se está apuntando.
  List<Vector3> get aimPreview {
    if (!aiming || !canThrow || readyBall == null) return const [];
    final hand = _hand;
    return ballSystem.predict(
      hand,
      _releaseVelocity(hand, lockedTarget),
      wild: wild,
    );
  }

  void _updateThrow(double dt) {
    final t = _throwTime;
    if (t == null) return;
    final now = t + dt;
    _throwTime = now;
    if (!_released && now >= releaseTime) {
      _released = true;
      final hand = _hand;
      ballSystem.launch(
        _throwBall!,
        hand,
        _releaseVelocity(hand, _throwTarget),
      );
    }
    if (now >= throwDuration) {
      _throwTime = null;
      _throwTarget = null;
    }
  }

  /// Deja en el suelo una bola fallada. Si cayó sobre algo que no se
  /// pisa (una valla), se lleva a la casilla libre más cercana.
  void _dropBall(PokeBallType ball, Vector3 at) {
    final cell = cellAt(at);
    var spot = at;
    if (!layout.isWalkable(cell.col, cell.row)) {
      var best = double.infinity;
      for (var dr = -2; dr <= 2; dr++) {
        for (var dc = -2; dc <= 2; dc++) {
          if (!layout.isWalkable(cell.col + dc, cell.row + dr)) continue;
          final c = cellCenter(cell.col + dc, cell.row + dr);
          final d = c.distanceTo(Vector3(at.x, 0, at.z));
          if (d < best) {
            best = d;
            spot = c;
          }
        }
      }
    }
    fieldItems.drop(ball, spot);
  }

  /// Quita un Pokémon salvaje (tras su encuentro).
  void removeWild(String id) => wild.removeWhere((w) => w.id == id);

  /// Deja de aceptar Pokémon que lleguen tarde (la pantalla se cerró).
  void dispose() => _disposed = true;

  /// Avanza la simulación [dt] segundos.
  void update(double dt) {
    time += dt;
    if (_paused) aiming = false;
    _updateCamera(dt);
    camera.updateAim(dt, aiming: aiming);
    lockedTarget = _paused
        ? null
        : findLockTarget(
            player: player.position,
            forward: camera.forward,
            wild: wild,
          );
    _updateThrow(dt);

    // Jugador: la dirección pulsada es RELATIVA A LA CÁMARA
    // (arriba = alejarse de la cámara), como en GTA. Al apuntar o lanzar,
    // el cuerpo mira al objetivo aunque camine de lado.
    final dir = input.direction; // x: derecha, y: abajo (convención 2D)
    final wish = camera.right * dir.x + camera.forward * -dir.y;
    player.update(
      dt,
      wish,
      running: cameraInput.running && input.enabled && !aiming,
      face: aiming || _throwTime != null ? _aimDirection : null,
    );

    final moved = player.distanceWalked - _lastDistance;
    _lastDistance = player.distanceWalked;
    if (_paused) return;

    fieldItems.update(dt, player.position, _emit);
    for (final w in wild.toList()) {
      _updateWild(w, dt);
    }
    ballSystem.update(
      dt,
      wild: wild,
      drop: _dropBall,
      remove: (w) => removeWild(w.id),
      emit: _emit,
    );
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

  /// Todos los que apartan la hierba al pasar: jugador y Pokémon (los que
  /// están dentro de una bola, no).
  Iterable<Vector3> get grassPushers sync* {
    yield player.position;
    for (final w in wild) {
      if (w.isFree) yield w.position;
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
            if (pokemon != null && !_disposed) {
              spawn(pokemon.pokemon, captureRate: pokemon.captureRate);
            }
          })
          .catchError((Object _) {
            _pendingSpawns--; // sin red: se reintentará en el siguiente turno
          }),
    );
  }

  /// Hace aparecer [pokemon] en una casilla de hierba alta lejos del
  /// jugador y de los demás. Devuelve null si no hay sitio.
  WildPokemon? spawn(Pokemon pokemon, {int captureRate = 45}) {
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
      captureRate: captureRate,
      position: spot,
      facing: _random.nextDouble() * 2 * math.pi,
    )..idleTime = _random.nextDouble() * 2;
    wild.add(w);
    return w;
  }

  /// Relojes del Pokémon y su movimiento (si no está dentro de una bola).
  void _updateWild(WildPokemon w, double dt) {
    w.age += dt;
    if (w.alertTime > 0) w.alertTime = math.max(0, w.alertTime - dt);
    final released = w.releasedFor;
    if (released != null) {
      w.releasedFor = released + dt > 0.6 ? null : released + dt;
    }
    if (!w.isFree) {
      w.velocity = Vector3.zero();
      return;
    }
    final before = w.position;
    _wander(w, dt);
    w.velocity = dt > 0 ? (w.position - before) / dt : Vector3.zero();
  }

  /// Paseo aleatorio sin salir de la hierba alta.
  void _wander(WildPokemon w, double dt) {
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
      if (w.engaged || !w.isFree) continue;
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
