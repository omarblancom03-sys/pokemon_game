import 'dart:async';
import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../../controllers/capture/capture_calculator.dart';
import '../../game/input/movement_input.dart';
import '../../game/map/map_layout.dart';
import '../../models/poke_ball.dart';
import '../../models/pokemon.dart';
import 'aiming.dart';
import 'berries.dart';
import 'birds.dart';
import 'butterflies.dart';
import 'clouds.dart';
import 'camera_input.dart';
import 'dust.dart';
import 'field_items.dart';
import 'footprints.dart';
import 'grass_blades.dart';
import 'grass_field.dart';
import 'grass_trampling.dart';
import 'orbit_camera.dart';
import 'player_body.dart';
import 'reach.dart';
import 'signs.dart';
import 'throw_ring.dart';
import 'throwing.dart';
import 'trainer_pose.dart';
import 'wild_behavior.dart';
import 'wild_pokemon.dart';
import 'world3d_config.dart';
import 'world3d_events.dart';

export 'berries.dart' show BerryBush, BerrySystem, LooseBerry;
export 'dust.dart' show DustPuff;
export 'field_items.dart' show GroundItem;
export 'footprints.dart' show Footprint, FootprintTrail;
export 'grass_blades.dart' show GrassBlade;
export 'grass_trampling.dart' show GrassTrampling;
export 'signs.dart' show MapCell;
export 'throw_ring.dart' show ThrowRing;
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

  /// Rastro de hierba tumbada que dejan los Pokémon que pasan corriendo.
  late final GrassTrampling trampled = GrassTrampling(
    grass,
    tileSize: config.tileSize,
  );

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

  /// Huellas del entrenador en la tierra del camino (decorado).
  final FootprintTrail footprints = FootprintTrail();

  /// Mariposas sobre los macizos de flores (decorado, con su propio azar).
  late final ButterflySwarm butterflies = ButterflySwarm.fromLayout(
    layout,
    config.tileSize,
    random: math.Random(11),
  );

  /// Bandadas de pájaros que se posan en el campo y salen volando al
  /// acercarte. Decorado con su propio azar.
  late final BirdSystem birds = BirdSystem.fromLayout(
    layout,
    config.tileSize,
    player: player.position,
    random: math.Random(23),
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

  /// Arbustos con bayas (se sacuden) y las bayas sueltas por el suelo. Con
  /// su propio azar: dónde caen las bayas no cambia el del juego.
  late final BerrySystem berries = BerrySystem.fromLayout(
    layout,
    config.tileSize,
    random: math.Random(29),
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

  /// El aro que se encoge al apuntar a [lockedTarget]: lanzar cuando es
  /// pequeño da un tiro mejor (ver ThrowQuality).
  final ThrowRing throwRing = ThrowRing();

  /// Bola elegida en la bolsa (la pone la pantalla); null = bolsa vacía.
  PokeBallType? readyBall = PokeBallType.poke;

  /// En la mano va una baya en vez de una bola (la pone la pantalla): al
  /// lanzar sale una baya, que cae cerca del Pokémon fijado para
  /// distraerlo.
  bool berryReady = false;

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

  // Lanzamiento en curso: tiempo desde que empezó, bola (null si es una
  // baya) y objetivo.
  double? _throwTime;
  PokeBallType? _throwBall;
  ThrowQuality _throwQuality = ThrowQuality.none;
  bool _throwingBerry = false;
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

  /// Probabilidad de que un Pokémon aparezca VARIOCOLOR (como en los
  /// juegos modernos con suerte: 1 de cada 100). Se puede cambiar (tests y
  /// vista previa).
  static const defaultShinyChance = 0.01;
  double shinyChance = defaultShinyChance;
  final math.Random _shinyRandom = math.Random(19);

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

  /// ¿Es tierra de camino? (ahí quedan las huellas; en las losas, no).
  bool isDirtPath(Vector3 p) {
    final cell = cellAt(p);
    return layout.tileAt(cell.col, cell.row) == TileKind.path;
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

  /// Lo que el jugador tiene a mano delante: un cartel o un arbusto (si
  /// hay los dos, el más cercano). Con el mundo congelado, nada.
  ({MapCell? sign, BerryBush? bush}) get _reachable {
    if (_paused) return (sign: null, bush: null);
    final p = player.position;
    final sign = signReader.readable(p, player.facing);
    final bush = berries.reachable(p, player.facing);
    if (sign == null || bush == null) return (sign: sign, bush: bush);
    final toSign = cellCenterOf(sign, config.tileSize).distanceTo(p);
    return toSign <= bush.center.distanceTo(p)
        ? (sign: sign, bush: null)
        : (sign: null, bush: bush);
  }

  /// Cartel que el jugador tiene delante y podría leer ahora (null si no
  /// hay ninguno o el mundo está congelado).
  MapCell? get readableSign => _reachable.sign;

  /// Cartel que se está leyendo (null = ninguno).
  MapCell? get openSign => signReader.open;

  /// Arbusto que el jugador tiene delante y podría sacudir ahora (null si
  /// no hay ninguno, está leyendo un cartel o el mundo está congelado).
  BerryBush? get shakableBush => openSign != null ? null : _reachable.bush;

  /// Vuelve a poner la cámara detrás del jugador (girando con suavidad).
  void recenterCamera() => camera.recenterBehind(player.facing);

  /// Leer el cartel de delante o cerrar el abierto. Devuelve si cambió.
  bool toggleSign() {
    if (_paused || (openSign == null && readableSign == null)) return false;
    return signReader.toggle(player.position, player.facing);
  }

  /// Sacudir un arbusto hace ruido: a esta distancia (m) los Pokémon lo
  /// oyen y se giran a mirar ("?").
  static const shakeNoiseRange = 7.0;

  /// Sacude el arbusto de delante: se balancea, se le caen unas hojas y
  /// suelta sus bayas a los pies del jugador. Hace ruido (ver
  /// [shakeNoiseRange]). Devuelve false si no hay arbusto a mano o aún se
  /// balancea de la vez anterior.
  bool shakeBush() {
    final bush = shakableBush;
    if (bush == null) return false;
    final released = berries.shake(bush, player.position);
    if (released == null) return false;
    blades.leaves(bush.center, top: config.tileSize / 2);
    _shakeNoise(bush.center);
    _emit(BushShaken(released));
    return true;
  }

  /// La tecla de acción (L / Intro): cierra el cartel abierto o usa lo que
  /// el jugador tenga delante (lee el cartel o sacude el arbusto).
  bool act() {
    if (openSign != null || readableSign != null) return toggleSign();
    return shakeBush();
  }

  /// Los Pokémon cerca de [at] oyen el arbusto: los tranquilos sospechan
  /// y se giran; los escondidos muy cerca salen asustados. Los pájaros
  /// cercanos se van volando.
  void _shakeNoise(Vector3 at) {
    final ground = Vector3(at.x, 0, at.z);
    birds.startle(ground, player.position);
    for (final w in wild) {
      if (!w.isFree) continue;
      final d = w.position.distanceTo(ground);
      if (w.hidden) {
        if (d < 4) _reveal(w, startled: true);
      } else if (d < shakeNoiseRange && !w.isAlert) {
        w
          ..awareness = math.max(w.awareness, 0.6)
          ..target = null;
      }
    }
  }

  /// 0..1 mientras dura la animación de lanzar; null si no lanza.
  double? get throwProgress =>
      _throwTime == null ? null : _throwTime! / throwDuration;

  /// ¿Se puede lanzar ahora? (una bola cada vez que termina el gesto).
  bool get canThrow => !_paused && _throwTime == null;

  /// Bola que se ve en la mano: al apuntar, la elegida; al lanzar, la
  /// lanzada hasta que sale de la mano. null si lleva una baya.
  PokeBallType? get heldBall {
    if (_throwTime != null) return _released ? null : _throwBall;
    return aiming && !berryReady ? readyBall : null;
  }

  /// ¿Se ve una baya en la mano? (al apuntar con ella o al lanzarla, hasta
  /// que sale de la mano).
  bool get heldBerry {
    if (_throwTime != null) return _throwingBerry && !_released;
    return aiming && berryReady;
  }

  /// ¿Hay algo en la mano para lanzar?
  bool get _itemReady => berryReady || readyBall != null;

  /// Probabilidad de capturar al objetivo fijado con la bola elegida
  /// (null si no hay objetivo, no quedan bolas o lleva una baya).
  double? get lockedChance {
    final target = lockedTarget;
    final ball = readyBall;
    if (target == null || ball == null || berryReady) return null;
    final toTarget = target.position - player.position
      ..y = 0;
    if (toTarget.length2 > 0) toTarget.normalize();
    return CaptureCalculator.chance(
      captureRate: target.captureRate,
      ball: ball,
      unaware: !target.isAlert,
      fromBehind: toTarget.dot(target.facingDirection) > 0.5,
      eating: target.isEating,
    );
  }

  /// Bolas en el aire o en el suelo con un Pokémon dentro.
  List<ThrownBall> get balls => ballSystem.balls;

  /// Empieza a lanzar [ball] al objetivo fijado (o hacia donde mira la
  /// cámara). La bola sale de la mano un instante después, cuando el brazo
  /// pasa por delante. Devuelve false si ahora no se puede.
  bool throwBall(PokeBallType ball) => _startThrow(ball);

  /// Empieza a lanzar una baya: con un objetivo fijado cae un poco por
  /// delante de él (ver [baitSpot]); si no, "a ojo". Devuelve false si
  /// ahora no se puede.
  bool throwBerry() => _startThrow(null);

  bool _startThrow(PokeBallType? ball) {
    if (!canThrow) return false;
    _throwTime = 0;
    _throwBall = ball;
    _throwingBerry = ball == null;
    _throwTarget = lockedTarget;
    // La calidad es la del aro al PULSAR (lo que el jugador cronometra).
    _throwQuality = ball == null ? ThrowQuality.none : throwRing.quality;
    _released = false;
    return true;
  }

  /// Distancia (m) más allá del Pokémon a la que se le lanza una baya:
  /// cerca para que la huela, sin darle.
  static const baitOffset = 1.4;

  /// Dónde se lanza una baya para [target]: en el suelo, un poco POR
  /// DETRÁS de él (del lado contrario al jugador). Así, para ir a por ella
  /// y comérsela, se da la vuelta y te da la espalda: la ocasión de
  /// lanzarle una bola sin que te vea.
  Vector3 baitSpot(WildPokemon target) {
    final away = target.position - player.position
      ..y = 0;
    final d = away.length;
    final beyond = d > 1e-6 ? away / d : Vector3(0, 0, 1);
    return target.position + beyond * baitOffset
      ..y = BerrySystem.radius;
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

  /// Una baya sale más floja que una bola (en globo): al sitio de
  /// [baitSpot] si llega; si no, "a ojo" como una bola.
  Vector3 _berryVelocity(Vector3 hand, WildPokemon? target) {
    if (target != null && target.isFree) {
      final v = ballisticVelocity(
        hand,
        baitSpot(target),
        speed: BerrySystem.throwSpeed,
      );
      if (v != null) return v;
    }
    return freeThrowVelocity(camera, speed: BerrySystem.throwSpeed);
  }

  /// Trayectoria que seguiría la bola (o la baya) si se lanzara ahora (se
  /// dibuja al apuntar). Vacía si no se está apuntando. Una baya no choca
  /// con los Pokémon: el arco acaba en el suelo o en un obstáculo.
  List<Vector3> get aimPreview {
    if (!aiming || !canThrow || !_itemReady) return const [];
    final hand = _hand;
    if (berryReady) {
      return ballSystem.predict(hand, _berryVelocity(hand, lockedTarget));
    }
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
      final ball = _throwBall;
      if (ball == null) {
        berries.throwBerry(hand, _berryVelocity(hand, _throwTarget));
      } else {
        ballSystem.launch(
          ball,
          hand,
          _releaseVelocity(hand, _throwTarget),
          quality: _throwQuality,
        );
      }
      _emit(ItemThrown(ball));
    }
    if (now >= throwDuration) {
      _throwTime = null;
      _throwTarget = null;
    }
  }

  /// Deja en el suelo una bola fallada. Si cayó sobre algo que no se
  /// pisa (una valla), se lleva a la casilla libre más cercana.
  /// (En el Reto Safari se pierde: no se deja nada.)
  void _dropBall(PokeBallType ball, Vector3 at) {
    if (safariActive) return;
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

  // --- Reto Safari ------------------------------------------------------

  /// Segundos que le quedan al Reto Safari (null = no hay reto). Solo
  /// corren con el mundo en marcha (no en pausa ni con un panel abierto).
  double? get safariTimeLeft => _safariTimeLeft;
  double? _safariTimeLeft;
  bool _safariTimeUpSent = false;

  bool get safariActive => _safariTimeLeft != null;

  /// Empieza el Reto Safari: [seconds] de tiempo, sin Poké Balls en el
  /// suelo (ni se ven ni aparecen) y las bolas falladas se pierden. Las
  /// bolas, la puntuación y el final los lleva SafariController.
  void startSafari(double seconds) {
    _safariTimeLeft = seconds;
    _safariTimeUpSent = false;
    fieldItems.enabled = false;
  }

  /// Termina el reto: todo vuelve a ser como antes (las bolas del suelo
  /// siguen donde estaban).
  void endSafari() {
    _safariTimeLeft = null;
    fieldItems.enabled = true;
  }

  void _updateSafari(double dt) {
    final left = _safariTimeLeft;
    if (left == null) return;
    _safariTimeLeft = math.max(0, left - dt);
    if (_safariTimeLeft == 0 && !_safariTimeUpSent) {
      _safariTimeUpSent = true;
      _emit(const SafariTimeUp());
    }
  }

  /// Quita un Pokémon salvaje (tras su encuentro).
  void removeWild(String id) {
    for (final w in wild) {
      if (w.id == id) _dropBait(w); // su baya queda libre
    }
    wild.removeWhere((w) => w.id == id);
  }

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
    // El aro solo corre apuntando a alguien con una bola lista.
    throwRing.update(
      dt,
      target: aiming && canThrow && readyBall != null && !berryReady
          ? lockedTarget?.id
          : null,
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
    birds.update(
      dt,
      player.position,
      stealth: stealth,
      moving: player.isMoving,
    );
    butterflies.update(
      dt,
      player.position,
      stealth: stealth,
      moving: player.isMoving,
    );
    _updateSafari(dt);
    fieldItems.update(dt, player.position, _emit);
    berries.update(dt, player.position, _emit, landed: _berryLanded);
    for (final w in wild.toList()) {
      _updateWild(w, dt);
    }
    _spotShinies();
    trampled.update(dt);
    ballSystem.update(
      dt,
      wild: wild,
      drop: _dropBall,
      remove: (w) => removeWild(w.id),
      // En el Safari, una bola fallada se pierde (y el aviso lo dice).
      emit: (event) => _emit(
        event is BallMissed && safariActive
            ? BallMissed(event.ball, lost: true)
            : event,
      ),
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
  /// En la tierra del camino, además, una huella por pisada.
  void _kickUp(double dt, Vector3 wish) {
    dust.update(dt);
    blades.update(dt);
    footprints.update(dt);
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
      if (isDirtPath(foot)) {
        footprints.step(
          foot,
          f,
          depth: FootprintTrail.depthFor(
            running: running,
            crouching: crouching,
          ),
        );
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

  /// Avisa (una vez por Pokémon) de los variocolor que se ven cerca (a
  /// [markRange] m como mucho, libres y no escondidos: uno escondido se ve
  /// al salir de la hierba).
  void _spotShinies() {
    for (final w in visibleWildNearby) {
      if (!w.shiny || w.shinySpotted) continue;
      w
        ..shinySpotted = true
        ..shinySpottedAt = time;
      _emit(ShinySpotted(w));
    }
  }

  /// Hasta qué distancia (m) la vista marca a los Pokémon que se ven (por
  /// ejemplo, con una Poké Ball si ya tienes su especie).
  static const markRange = 22.0;

  /// Pokémon que se ven ahora cerca del jugador: libres (no dentro de una
  /// bola), no escondidos y a menos de [markRange] m.
  Iterable<WildPokemon> get visibleWildNearby sync* {
    for (final w in wild) {
      if (!w.isFree || w.hidden) continue;
      final d = w.position.distanceTo(player.position);
      if (d <= markRange) yield w;
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
                // Con su propio azar: es cosmético y no debe cambiar el
                // resto de la partida.
                shiny: _shinyRandom.nextDouble() < shinyChance,
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
    bool shiny = false,
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
            shiny: shiny,
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
      _dropBait(w); // dentro de una bola ya no come
      return;
    }
    if (w.hidden) {
      _updateHidden(w, dt);
      return;
    }
    final noticed = behavior.perceive(
      w,
      player: player.position,
      stealth: stealth,
      moving: player.isMoving,
      dt: dt,
    );
    if (noticed) _emit(PokemonNoticed(w));
    // Si te descubre (o la baya ya no está), se olvida de ella.
    final bait = w.bait;
    if (bait != null && (w.isAlert || !berries.contains(bait))) _dropBait(w);
    if (w.bait == null && !w.isAlert) _lookForBait(w);

    final before = w.position;
    var fled = false;
    if (w.bait != null) {
      _feed(w, dt);
    } else {
      fled = behavior.act(w, player.position, dt);
    }
    w.velocity = dt > 0 ? (w.position - before) / dt : Vector3.zero();
    // Corriendo por la hierba alta (huyendo o cargando) la deja tumbada.
    if (w.velocity.length > trampleSpeed && isTallGrass(w.position)) {
      trampled.trample(w.position, w.velocity);
    }
    if (fled) removeWild(w.id);
  }

  /// A partir de esta rapidez (m/s) un Pokémon deja la hierba tumbada:
  /// huyendo (4,4) o cargando (3,6), no paseando (1,3) ni yendo a por una
  /// baya (2).
  static const trampleSpeed = 2.5;

  // --- Bayas para distraer -----------------------------------------------

  /// Hasta dónde (m) huele un Pokémon una baya que está en el suelo.
  static const baitRange = 10.0;

  /// Si en este tiempo (s) no llega a su baya (se atasca), se rinde.
  static const baitPatience = 15.0;

  /// Ningún Pokémon va a por una baya que está a menos de esto (m) del
  /// jugador (no se acercan tanto a una persona). Así las que caen de un
  /// arbusto a tus pies son para ti.
  static const baitShyDistance = 3.5;

  /// Una baya que cae a menos de esto (m) de un escondido lo hace asomarse
  /// (sin verte: viene a por la baya).
  static const baitRevealRange = 3.5;

  /// Un Pokémon tranquilo busca la baya libre más cercana del suelo (que
  /// no esté junto al jugador). Si la encuentra, se la queda (nadie más va
  /// a por ella) y se distrae: se le pasa la sospecha que tuviera.
  void _lookForBait(WildPokemon w) {
    LooseBerry? best;
    var bestDistance = baitRange;
    final me = player.position;
    for (final berry in berries.loose) {
      if (!berry.landed || berry.claimedBy != null) continue;
      final fromPlayer = berry.position - me
        ..y = 0;
      if (fromPlayer.length < baitShyDistance) continue;
      final to = berry.position - w.position
        ..y = 0;
      final d = to.length;
      if (d < bestDistance) {
        best = berry;
        bestDistance = d;
      }
    }
    if (best == null) return;
    best.claimedBy = w.id;
    w
      ..bait = best
      ..baitTime = 0
      ..target = null
      ..awareness = math.min(w.awareness, 0.2);
  }

  /// Va hacia su baya y se la come. Avisa al empezar a comer; al terminar,
  /// la baya desaparece y se queda un rato tranquilo.
  void _feed(WildPokemon w, double dt) {
    final wasEating = w.isEating;
    behavior.feed(w, dt);
    if (!wasEating && w.isEating) _emit(PokemonEating(w));
    if ((w.eatingFor ?? 0) >= WildPokemon.eatSeconds) {
      berries.consume(w.bait!);
      w
        ..bait = null
        ..eatingFor = null
        ..idleTime = 2;
    } else if (!w.isEating && w.baitTime > baitPatience) {
      _dropBait(w);
    }
  }

  /// Deja su baya (a medio comer, si había empezado) para quien la quiera.
  void _dropBait(WildPokemon w) {
    final bait = w.bait;
    if (bait == null) return;
    if (bait.claimedBy == w.id) bait.claimedBy = null;
    w
      ..bait = null
      ..eatingFor = null;
  }

  /// Una baya acaba de caer al suelo: los escondidos cerca se asoman a
  /// por ella, sin verte.
  void _berryLanded(LooseBerry berry) {
    for (final w in wild) {
      if (!w.hidden || !w.isFree) continue;
      final to = berry.position - w.position
        ..y = 0;
      if (to.length < baitRevealRange) _reveal(w, startled: false);
    }
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

  /// Una bola que cae cerca asusta a los Pokémon (y a los pájaros) de
  /// alrededor.
  void _startleAround(Vector3 at) {
    birds.startle(at, player.position);
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
