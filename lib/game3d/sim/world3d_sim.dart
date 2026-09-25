import 'dart:async';
import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../../controllers/capture/capture_calculator.dart';
import '../../game/input/movement_input.dart';
import '../../game/map/map_layout.dart';
import '../../models/poke_ball.dart';
import '../../models/pokemon.dart';
import 'aiming.dart';
import 'butterflies.dart';
import 'clouds.dart';
import 'camera_input.dart';
import 'dust.dart';
import 'field_items.dart';
import 'grass_blades.dart';
import 'grass_field.dart';
import 'orbit_camera.dart';
import 'player_body.dart';
import 'signs.dart';
import 'throwing.dart';
import 'trainer_pose.dart';
import 'wild_behavior.dart';
import 'wild_pokemon.dart';
import 'world3d_config.dart';
import 'world3d_events.dart';

export 'dust.dart' show DustPuff;
export 'field_items.dart' show GroundItem;
export 'grass_blades.dart' show GrassBlade;
export 'signs.dart' show MapCell;
export 'throwing.dart' show BallPhase, ThrownBall;
export 'wild_behavior.dart' show PlayerStealth;
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
/// fuera con [onWildContact] (un Pokémon agresivo te alcanzó: combate),
/// [onGrassEncounter] (encuentro al azar en la hierba, desactivado por
/// defecto) y [onEvent] (recogidas, capturas...). Por eso toda la
/// jugabilidad se puede probar con tests normales.
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
    this.grassEncounters = false,
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
    behavior = WildBehavior(
      random: _random,
      isWalkable: (p) {
        final c = cellAt(p);
        return layout.isWalkable(c.col, c.row);
      },
      isTallGrass: isTallGrass,
      nearbyGrass: _nearbyGrass,
    );
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

  /// Vista, oído y reacciones de los Pokémon salvajes.
  late final WildBehavior behavior;

  /// Polvo que levantan los pies al correr y las bolas al botar. Es solo
  /// decorado: usa su propio azar para no alterar el del juego.
  final DustSystem dust = DustSystem(random: math.Random(7));

  /// Briznas que saltan de la hierba alta al pisarla, sobre los escondidos
  /// y cuando uno sale. Decorado con su propio azar, como el polvo.
  final GrassBladeSystem blades = GrassBladeSystem(random: math.Random(13));

  /// Mariposas sobre los macizos de flores (decorado, con su propio azar).
  late final ButterflySwarm butterflies = ButterflySwarm.fromLayout(
    layout,
    config.tileSize,
    random: math.Random(11),
  );

  /// Nubes que pasan con el viento (y sus sombras). Decorado con su
  /// propio azar, como el polvo.
  late final CloudLayer clouds = CloudLayer(
    width: width,
    depth: depth,
    random: math.Random(17),
  );

  /// Carteles del mapa: cuál se puede leer y cuál está abierto.
  late final SignReader signReader = SignReader.fromLayout(
    layout,
    config.tileSize,
  );

  /// Encuentros al azar andando por la hierba alta (como en los juegos
  /// clásicos). En 3D van apagados: los Pokémon ya se ven y se capturan
  /// en el mundo (ver DECISIONES.md).
  final bool grassEncounters;

  /// El jugador quiere ir agachado (sigilo). Correr lo levanta.
  bool crouching = false;

  /// 0 de pie … 1 agachado, suavizado (para la postura).
  double crouchAmount = 0;

  /// El jugador está apuntando (botón derecho / tecla): la cámara se pone
  /// al hombro, el cuerpo mira adonde apunta la cámara y no se corre.
  bool aiming = false;

  /// Pokémon al que se lanzaría ahora mismo (null = tiro a ojo).
  WildPokemon? lockedTarget;

  /// Bola elegida en la bolsa (la pone la pantalla); null = bolsa vacía.
  PokeBallType? readyBall = PokeBallType.poke;

  /// Probabilidad de captura crítica (la pone la pantalla según cuántas
  /// especies ha capturado el entrenador).
  double get criticalChance => ballSystem.criticalChance;
  set criticalChance(double value) => ballSystem.criticalChance = value;

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
  int _lastFootstep = 0;
  double _runTime = 0;

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

  /// Probabilidad de que un Pokémon aparezca ESCONDIDO en la hierba alta
  /// (no se ve; solo se agita la hierba donde está).
  static const hiddenChance = 0.35;

  /// Si nadie encuentra a un escondido en este tiempo (s), se va.
  static const hiddenLifetime = 60.0;

  /// Distancia (m) a la que un escondido sale de la hierba, según lo que
  /// se note el jugador. Quieto, solo si está pegado.
  static double revealDistance(PlayerStealth stealth, {required bool moving}) {
    if (!moving) return 1.2;
    return switch (stealth) {
      PlayerStealth.noisy => 6.5,
      PlayerStealth.normal => 4.0,
      PlayerStealth.crouching => 2.2,
      PlayerStealth.hidden => 1.6,
    };
  }

  /// Metros entre dos pisadas (medio ciclo de pasos del entrenador).
  static const footstepSpacing = TrainerPose.strideLength / 2;

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

  /// Cartel que el jugador tiene delante y podría leer ahora (null si no
  /// hay ninguno o el mundo está congelado).
  MapCell? get readableSign =>
      _paused ? null : signReader.readable(player.position, player.facing);

  /// Cartel que se está leyendo (null = ninguno).
  MapCell? get openSign => signReader.open;

  /// Vuelve a poner la cámara detrás del jugador (girando con suavidad).
  void recenterCamera() => camera.recenterBehind(player.facing);

  /// Leer el cartel de delante o cerrar el abierto. Devuelve si cambió.
  bool toggleSign() =>
      !_paused && signReader.toggle(player.position, player.facing);

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
    final running = cameraInput.running && input.enabled && !aiming;
    if (running && wish.length2 > 0.01) crouching = false;
    player.update(
      dt,
      wish,
      running: running,
      crouching: crouching,
      face: aiming || _throwTime != null ? _aimDirection : null,
    );
    crouchAmount += ((crouching ? 1 : 0) - crouchAmount) * math.min(1, dt * 10);
    camera.avoidObstacles(player.position, ballSystem.heightAt, dt);
    signReader.update(player.position);

    final moved = player.distanceWalked - _lastDistance;
    _lastDistance = player.distanceWalked;
    if (_paused) return;

    _kickUp(dt, wish);
    clouds.update(dt);
    butterflies.update(
      dt,
      player.position,
      stealth: stealth,
      moving: player.isMoving,
    );
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
      impact: _startleAround,
      bounce: (at, speed) {
        if (speed > 2) dust.burst(at, strength: speed / 10);
      },
    );
    _maybeSpawn(dt);

    if (_grace > 0) {
      _grace -= dt;
      return;
    }
    if (_checkContacts()) return;
    if (grassEncounters) _checkGrassSteps(moved);
  }

  void _updateCamera(double dt) {
    final (dragX, dragY) = cameraInput.takeDrag();
    camera
      ..rotate(
        -dragX * dragSensitivity + cameraInput.turnAxis * keyTurnSpeed * dt,
        dragY * dragSensitivity,
      )
      ..zoom(cameraInput.takeZoom())
      ..updateRecenter(dt);
  }

  /// Lo que levantan los pies. Fuera de la hierba alta, polvo al correr
  /// (una nubecilla por pisada, en el pie que toca el suelo) y al frenar
  /// en seco tras una carrera. Dentro, briznas en cada pisada: tres
  /// corriendo, una andando y ninguna agachado (se ve el ruido que haces).
  void _kickUp(double dt, Vector3 wish) {
    dust.update(dt);
    blades.update(dt);
    final feet = player.position;
    final onDirt = !isTallGrass(feet);
    final running = player.speed > config.walkSpeed * 1.15;
    final step = (player.distanceWalked / footstepSpacing).floor();
    if (step != _lastFootstep) {
      _lastFootstep = step;
      final f = player.facing;
      final right = Vector3(-math.cos(f), 0, math.sin(f));
      final foot = feet + right * (step.isEven ? 0.12 : -0.12);
      if (running && onDirt) dust.footstep(foot, player.velocity);
      if (!onDirt && !crouching) {
        blades.footstep(foot, player.velocity, running: running);
      }
    }
    final stopping = wish.length2 < 0.01;
    if (stopping && _runTime > 0.3 && onDirt) {
      final f = player.facing;
      dust.burst(
        feet + Vector3(math.sin(f), 0, math.cos(f)) * 0.35,
        strength: 0.35,
      );
    }
    _runTime = running && !stopping ? _runTime + dt : 0;
  }

  /// Todos los que apartan la hierba al pasar: jugador y Pokémon (los que
  /// están dentro de una bola, no ni los escondidos: esos la agitan).
  Iterable<Vector3> get grassPushers sync* {
    yield player.position;
    for (final w in wild) {
      if (w.isFree && !w.hidden) yield w.position;
    }
  }

  /// Dónde se agita la hierba: sobre los Pokémon escondidos.
  Iterable<Vector3> get grassRustlers sync* {
    for (final w in wild) {
      if (w.hidden) yield w.position;
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
              spawn(
                pokemon.pokemon,
                captureRate: pokemon.captureRate,
                hidden: _random.nextDouble() < hiddenChance,
              );
            }
          })
          .catchError((Object _) {
            _pendingSpawns--; // sin red: se reintentará en el siguiente turno
          }),
    );
  }

  /// Hace aparecer [pokemon] en una casilla de hierba alta lejos del
  /// jugador y de los demás ([hidden]: escondido en la hierba). Devuelve
  /// null si no hay sitio.
  WildPokemon? spawn(
    Pokemon pokemon, {
    int captureRate = 45,
    bool hidden = false,
  }) {
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
    final w =
        WildPokemon(
            id: 'wild-${_spawnCount++}',
            pokemon: pokemon,
            captureRate: captureRate,
            position: spot,
            facing: _random.nextDouble() * 2 * math.pi,
          )
          ..idleTime = _random.nextDouble() * 2
          ..hidden = hidden;
    wild.add(w);
    return w;
  }

  /// ¿Cuánto se deja notar el jugador? (agachado, corriendo, en la hierba)
  PlayerStealth get stealth {
    if (crouching) {
      return isTallGrass(player.position)
          ? PlayerStealth.hidden
          : PlayerStealth.crouching;
    }
    if (player.speed > config.walkSpeed * 1.15) return PlayerStealth.noisy;
    return PlayerStealth.normal;
  }

  /// Relojes del Pokémon, lo que percibe y cómo reacciona (si no está
  /// dentro de una bola).
  void _updateWild(WildPokemon w, double dt) {
    w.age += dt;
    if (w.alertTime > 0) {
      w.alertTime -= dt;
      if (w.alertTime <= 0) {
        // Se calma, pero sigue algo mosqueado un rato.
        w
          ..alertTime = 0
          ..awareness = 0.6;
      }
    }
    final released = w.releasedFor;
    if (released != null) {
      w.releasedFor = released + dt > 0.6 ? null : released + dt;
    }
    final revealed = w.revealedFor;
    if (revealed != null) {
      w.revealedFor = revealed + dt > WildPokemon.revealJumpTime
          ? null
          : revealed + dt;
    }
    if (!w.isFree) {
      w.velocity = Vector3.zero();
      return;
    }
    if (w.hidden) {
      _updateHidden(w, dt);
      return;
    }
    behavior.perceive(
      w,
      player: player.position,
      stealth: stealth,
      moving: player.isMoving,
      dt: dt,
    );
    final before = w.position;
    final fled = behavior.act(w, player.position, dt);
    w.velocity = dt > 0 ? (w.position - before) / dt : Vector3.zero();
    if (fled) removeWild(w.id);
  }

  /// Un escondido no se mueve ni te busca: espera en la hierba. Sale si te
  /// acercas (según lo que se te note) y se va si nadie lo encuentra.
  void _updateHidden(WildPokemon w, double dt) {
    w
      ..velocity = Vector3.zero()
      ..hiddenTime += dt;
    blades.rustle(w.position, GrassField.rustleBurst(time, w.position), dt);
    if (w.hiddenTime > hiddenLifetime) {
      removeWild(w.id);
      return;
    }
    final to = player.position - w.position
      ..y = 0;
    final sneaky =
        stealth == PlayerStealth.crouching || stealth == PlayerStealth.hidden;
    if (to.length < revealDistance(stealth, moving: player.isMoving)) {
      _reveal(w, startled: !sneaky);
    }
  }

  /// Sale de la hierba de un salto. Asustado: te mira y reacciona según su
  /// carácter. Si te acercaste con sigilo, se asoma distraído, mirando
  /// hacia otro lado (¡la ocasión de lanzarle por la espalda!).
  void _reveal(WildPokemon w, {required bool startled}) {
    final to = player.position - w.position
      ..y = 0;
    final towards = math.atan2(to.x, to.z);
    w
      ..hidden = false
      ..revealedFor = 0
      ..target = null
      ..facing = startled
          ? towards
          : towards + math.pi + (_random.nextDouble() - 0.5) * 1.6;
    if (startled) behavior.startle(w);
    blades.burst(w.position);
    _emit(PokemonRevealed(w, startled: startled));
  }

  /// Una bola que cae cerca asusta a los Pokémon de alrededor.
  void _startleAround(Vector3 at) {
    for (final w in wild) {
      if (w.isFree && w.position.distanceTo(Vector3(at.x, 0, at.z)) < 4) {
        if (w.hidden) {
          _reveal(w, startled: true);
        } else {
          behavior.startle(w);
        }
      }
    }
  }

  /// Un punto de hierba alta al azar a menos de [radius] casillas de [p]
  /// (null si no hay ninguna).
  Vector3? _nearbyGrass(Vector3 p, int radius) {
    final here = cellAt(p);
    final near = _tallGrassCells
        .where(
          (c) =>
              (c.col - here.col).abs() <= radius &&
              (c.row - here.row).abs() <= radius,
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

  /// ¿Toca el jugador algún Pokémon? Solo un AGRESIVO alerta que te
  /// alcanza empieza un encuentro (el combate, de otro equipo); a los
  /// demás, tocarlos solo los asusta. Dispara como mucho uno.
  bool _checkContacts() {
    final p = player.position;
    for (final w in wild) {
      if (w.engaged || !w.isFree || w.hidden) continue;
      if (w.position.distanceTo(p) >= w.contactRadius) continue;
      if (w.temperament == Temperament.aggressive && w.isAlert) {
        w.engaged = true;
        onWildContact?.call(w);
        return true;
      }
      if (!w.isAlert) behavior.startle(w);
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
