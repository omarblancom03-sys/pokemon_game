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
import 'capture_camera.dart';
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
    math.Random? fleeRandom,
    math.Random? dodgeRandom,
  }) : input = input ?? MovementInput(),
       cameraInput = cameraInput ?? CameraInput(),
       camera = camera ?? OrbitCamera(),
       _random = random ?? math.Random(),
       _fleeRandom = fleeRandom ?? math.Random(),
       _dodgeRandom = dodgeRandom ?? math.Random() {
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

  /// El jugador quiere apuntar (botón derecho / tecla): la cámara se pone
  /// al hombro, el cuerpo mira adonde apunta la cámara y no se corre. Lo
  /// que cuenta es [isAiming] (la cámara de captura lo deja en suspenso).
  bool aiming = false;
  bool _aimWas = false;

  /// ¿Está apuntando de verdad? No mientras la cámara de captura enseña
  /// una bola: si se sigue manteniendo, al terminar se vuelve a apuntar;
  /// volver a pulsar apuntar suelta la cámara.
  bool get isAiming => aiming && !captureCam.engaged && !isRolling;

  /// La cámara que encuadra la bola al golpear (ver CaptureCamera).
  final CaptureCamera captureCam = CaptureCamera();

  /// MICRO-PAUSA al golpear (hit-stop): el mundo se congela un instante
  /// para que el golpe "pese" (más en una captura crítica). La cámara y el
  /// jugador siguen: no parece que se cuelgue. Segundos que quedan.
  double get hitStop => _hitStop;
  double _hitStop = 0;
  static const hitStopSeconds = 0.07;
  static const criticalHitStopSeconds = 0.14;

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

  /// Sin semilla: con una fija, cada partida repetiría qué Pokémon salen
  /// variocolor.
  final math.Random _shinyRandom = math.Random();

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

  // --- Voltereta ----------------------------------------------------------

  /// Lo que dura una voltereta (s), cuánto avanza (m) y la espera hasta
  /// poder dar otra.
  static const rollTime = 0.5;
  static const rollDistance = 3.2;
  static const rollCooldown = 0.35;

  /// Un Pokémon que te embiste a menos de esto (m) cuando ruedas se pasa
  /// de largo: sigue recto hasta [overshootPast] m más allá de donde
  /// estabas y queda aturdido.
  static const rollDodgeRange = 3.5;
  static const overshootPast = 2.0;

  double? _rollTime;
  final Vector3 _rollDir = Vector3(0, 0, 1);
  double _rollWait = 0;

  bool get isRolling => _rollTime != null;

  /// 0..1 mientras rueda (para la postura); null si no.
  double? get rollProgress =>
      _rollTime == null ? null : math.min(1, _rollTime! / rollTime);

  /// Rapidez al empezar: frena hasta la mitad al final, y así recorre
  /// [rollDistance] en [rollTime].
  static double get _rollSpeed => rollDistance / (rollTime * 0.75);

  /// VOLTERETA (tecla X o botón): un impulso rápido hacia donde te mueves
  /// (o hacia donde miras, si estás quieto). Te levanta si ibas agachado y
  /// hace ruido. Un Pokémon que te embiste y está cerca se pasa de largo y
  /// queda aturdido; mientras ruedas, ninguno te alcanza. Devuelve false
  /// si ahora no se puede (en pausa, lanzando, rodando o recién rodado).
  bool roll() {
    if (_paused || isRolling || _rollWait > 0 || _throwTime != null) {
      return false;
    }
    final dir = input.direction;
    final wish = camera.right * dir.x + camera.forward * -dir.y;
    if (wish.length2 > 0.01) {
      _rollDir.setFrom(wish..normalize());
    } else {
      final f = player.facing;
      _rollDir.setValues(math.sin(f), 0, math.cos(f));
    }
    _rollTime = 0;
    crouching = false;
    captureCam.release();
    // Los que te embisten de cerca van a por donde ESTABAS.
    final here = player.position;
    for (final w in wild) {
      if (!w.isFree || w.hidden || !w.isAlert || w.engaged) continue;
      if (w.temperament != Temperament.aggressive) continue;
      if (w.isDazed || w.overshootTo != null) continue;
      final to = here - w.position
        ..y = 0;
      final d = to.length;
      if (d > rollDodgeRange || d < 1e-3) continue;
      w
        ..overshootTo = w.position + to.normalized() * (d + overshootPast)
        ..target = null;
    }
    // Al tirarse al suelo levanta polvo (o briznas en la hierba alta).
    final feet = player.position;
    if (isTallGrass(feet)) {
      blades.footstep(feet, _rollDir * _rollSpeed, running: true);
    } else {
      dust.burst(feet, strength: 0.45);
    }
    _emit(const PlayerRolled());
    return true;
  }

  /// Avanza la voltereta (en vez de andar).
  void _updateRoll(double dt) {
    final t = _rollTime! + dt;
    final s = math.min(1.0, t / rollTime);
    player.dash(dt, _rollDir, _rollSpeed * (1 - 0.5 * s));
    if (t >= rollTime) {
      _rollTime = null;
      _rollWait = rollCooldown;
    } else {
      _rollTime = t;
    }
  }

  /// Se pasó de largo: corre recto hasta [WildPokemon.overshootTo] (sin
  /// alcanzar a nadie) y, al llegar, queda aturdido.
  void _overshoot(WildPokemon w, double dt) {
    final before = w.position;
    final done = behavior.dashTo(
      w,
      w.overshootTo!,
      WildPokemon.overshootSpeed,
      dt,
    );
    w.velocity = dt > 0 ? (w.position - before) / dt : Vector3.zero();
    if (w.velocity.length > trampleSpeed && isTallGrass(w.position)) {
      trampled.trample(w.position, w.velocity);
    }
    if (done) _startDaze(w);
  }

  /// Aturdido: quieto, sin enterarse de nada (cuenta como que no te ha
  /// visto) durante [WildPokemon.dazeSeconds]. Al volver en sí sigue
  /// mosqueado: si te ve, te descubre enseguida.
  void _startDaze(WildPokemon w) {
    w
      ..overshootTo = null
      ..dazedFor = 0
      ..alertTime = 0
      ..awareness = 0
      ..target = null
      ..velocity = Vector3.zero();
    _dropBait(w);
    _emit(PokemonDazed(w));
  }

  void _daze(WildPokemon w, double dt) {
    final t = w.dazedFor! + dt;
    if (t < WildPokemon.dazeSeconds) {
      w.dazedFor = t;
      return;
    }
    w
      ..dazedFor = null
      ..awareness = 0.9;
  }

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
  bool get canThrow => !_paused && _throwTime == null && !isRolling;

  /// Bola que se ve en la mano: al apuntar, la elegida; al lanzar, la
  /// lanzada hasta que sale de la mano. null si lleva una baya.
  PokeBallType? get heldBall {
    if (_throwTime != null) return _released ? null : _throwBall;
    return isAiming && !berryReady ? readyBall : null;
  }

  /// ¿Se ve una baya en la mano? (al apuntar con ella o al lanzarla, hasta
  /// que sale de la mano).
  bool get heldBerry {
    if (_throwTime != null) return _throwingBerry && !_released;
    return isAiming && berryReady;
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

  /// Dónde está la mochila del entrenador (a ella vuelven las bolas que
  /// capturan): a la espalda, a la altura de la cintura; más baja agachado.
  Vector3 get backpackPosition {
    final f = player.facing;
    return player.position +
        Vector3(0, 1.1 - 0.3 * crouchAmount, 0) -
        Vector3(math.sin(f), 0, math.cos(f)) * 0.26;
  }

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
    captureCam.release(); // lanzar otra cosa: manda el jugador
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
    if (!isAiming || !canThrow || !_itemReady) return const [];
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

  /// Probabilidad de que, en el Reto Safari, un Pokémon que se escapa de
  /// la bola HUYA para siempre: más si es raro. 10 % los más fáciles
  /// (ratio 255), ~43 % uno normal (45) y 50 % un legendario (3). Si le
  /// diste mientras comía una baya, la mitad: la baya lo entretiene (como
  /// el cebo de la Zona Safari de los juegos).
  static double safariFleeChance(int captureRate, {bool eating = false}) {
    final rarity = 1 - captureRate.clamp(1, 255) / 255;
    final chance = 0.1 + 0.4 * rarity;
    return eating ? chance / 2 : chance;
  }

  /// Dado de la huida, con su propio azar (como el variocolor): no cambia
  /// dónde aparecen ni cómo se comportan los demás. Sin semilla (cada
  /// partida, distinto); los tests inyectan el suyo.
  final math.Random _fleeRandom;

  /// Si en este tiempo (s) no se ha alejado lo bastante (acorralado), el
  /// que huye desaparece igual, en una nubecilla.
  static const leaveSeconds = 6.0;

  // --- Esquivar -----------------------------------------------------------

  /// Con cuánta antelación (s) ve venir la bola un Pokémon: si le va a
  /// llegar antes, decide si se aparta.
  static const dodgeWarning = 0.4;

  /// Dado de la esquiva, con su propio azar y sin semilla (inyectable en
  /// los tests).
  final math.Random _dodgeRandom;

  /// Un Pokémon que te tiene vigilado (alerta "!" o con sospecha "?") y ve
  /// venir una bola hacia él (la mira de frente y le llegará en menos de
  /// [dodgeWarning] s) puede apartarse de un salto (ver
  /// WildBehavior.dodgeChance). Se decide una vez por bola. Los que huyen
  /// van de espaldas: no la ven.
  void _checkDodges() {
    for (final b in ballSystem.balls) {
      if (b.phase != BallPhase.flying) continue;
      final dir = Vector3(b.velocity.x, 0, b.velocity.z);
      final speed = dir.length;
      if (speed < 1) continue;
      dir.scale(1 / speed);
      for (final w in wild) {
        if (!w.isFree || w.hidden || w.isEating) continue;
        if (!w.isAlert && !w.isSuspicious) continue;
        if (w.isDodging || w.isLeaving || w.dodgeCheckedBall == b.id) continue;
        final to = w.position - b.position
          ..y = 0;
        final along = to.dot(dir);
        if (along <= 0 || along / speed > dodgeWarning) continue;
        // ¿Va hacia él? (el lado del camino de la bola en que queda)
        final aside = to - dir * along;
        if (aside.length > w.hitRadius + ballRadius + 0.3) continue;
        // ¿La ve venir? Tiene que estar mirando hacia la bola.
        if (w.facingDirection.dot(-dir) < 0.34) continue;
        w.dodgeCheckedBall = b.id;
        final chance = WildBehavior.dodgeChance(w.temperament, b.quality);
        if (chance <= 0 || _dodgeRandom.nextDouble() >= chance) continue;
        _startDodge(w, dir, aside);
      }
    }
  }

  /// Salta de lado, lejos del camino de la bola (al otro lado si ese no se
  /// puede pisar). Si no cabe por ningún lado, se queda.
  void _startDodge(WildPokemon w, Vector3 dir, Vector3 aside) {
    final side = Vector3(-dir.z, 0, dir.x);
    // Hacia el lado en que ya está (así se aleja del camino de la bola).
    final first = aside.dot(side) >= 0 ? 1.0 : -1.0;
    for (final sign in [first, -first]) {
      final to = w.position + side * (sign * WildPokemon.dodgeDistance);
      final c = cellAt(to);
      if (!layout.isWalkable(c.col, c.row)) continue;
      w
        ..dodgeFrom = w.position
        ..dodgeTo = to
        ..dodgingFor = 0
        ..target = null
        ..alertTime = math.max(w.alertTime, WildBehavior.alertSeconds);
      _dropBait(w);
      _emit(PokemonDodged(w));
      return;
    }
  }

  /// El salto de la esquiva: rápido al principio (se aparta ya) y suave al
  /// caer. Mientras, no hace nada más.
  void _dodge(WildPokemon w, double dt) {
    final t = w.dodgingFor! + dt;
    final s = math.min(1.0, t / WildPokemon.dodgeTime);
    final ease = 1 - (1 - s) * (1 - s);
    final before = w.position;
    w.position = w.dodgeFrom + (w.dodgeTo - w.dodgeFrom) * ease;
    w.velocity = dt > 0 ? (w.position - before) / dt : Vector3.zero();
    w.dodgingFor = t >= WildPokemon.dodgeTime ? null : t;
  }

  /// Una bola golpea: empieza la micro-pausa (más larga si la captura va
  /// a ser crítica: el resultado ya está decidido en el golpe).
  BallHit _startHitStop(BallHit event) {
    final critical = ballSystem.balls.any(
      (b) => b.target == event.wild && (b.result?.critical ?? false),
    );
    _hitStop = critical ? criticalHitStopSeconds : hitStopSeconds;
    return event;
  }

  /// En el Safari, el que se escapa de la bola puede huir: el aviso lo
  /// dice ([PokemonBrokeFree.fled]) y empieza a irse.
  PokemonBrokeFree _maybeFlee(PokemonBrokeFree event) {
    final w = event.wild;
    if (!safariActive || w.isLeaving) return event;
    final chance = safariFleeChance(
      w.captureRate,
      eating: event.hit?.eating ?? false,
    );
    if (_fleeRandom.nextDouble() >= chance) return event;
    w
      ..leavingFor = 0
      ..alertTime = math.max(w.alertTime, leaveSeconds);
    return PokemonBrokeFree(
      w,
      event.ball,
      event.result,
      hit: event.hit,
      fled: true,
    );
  }

  /// Se va para siempre: tras el "pop" de la bola corre lejos de ti
  /// (tumbando la hierba alta) y desaparece al alejarse o, si se atasca, a
  /// los [leaveSeconds] en una nubecilla. No se para a comer ni a mirar.
  void _leave(WildPokemon w, double dt) {
    final t = w.leavingFor! + dt;
    w.leavingFor = t;
    final before = w.position;
    var far = false;
    if (w.releasedFor == null) far = behavior.runAway(w, player.position, dt);
    w.velocity = dt > 0 ? (w.position - before) / dt : Vector3.zero();
    if (w.velocity.length > trampleSpeed && isTallGrass(w.position)) {
      trampled.trample(w.position, w.velocity);
    }
    if (far || t > leaveSeconds) {
      if (!far) dust.burst(w.position, strength: 0.6);
      removeWild(w.id);
    }
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
    final turned = _updateCamera(dt);
    final freshAim = aiming && !_aimWas;
    _aimWas = aiming;
    captureCam.update(
      dt,
      balls: ballSystem.balls,
      player: player.position,
      interrupted: turned || freshAim || input.direction.length2 > 0.01,
    );
    camera
      ..focus = captureCam.focus
      ..focusPoint = captureCam.point
      // Si se sigue apuntando, la cámara no se aleja del hombro mientras
      // enseña la bola (iría hacia atrás y luego hacia delante).
      ..updateAim(dt, aiming: aiming);
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
      target: isAiming && canThrow && readyBall != null && !berryReady
          ? lockedTarget?.id
          : null,
    );
    _updateThrow(dt);

    // Jugador: la dirección pulsada es RELATIVA A LA CÁMARA
    // (arriba = alejarse de la cámara), como en GTA. Al apuntar o lanzar,
    // el cuerpo mira al objetivo aunque camine de lado.
    final dir = input.direction; // x: derecha, y: abajo (convención 2D)
    final wish = camera.right * dir.x + camera.forward * -dir.y;
    final running = cameraInput.running && input.enabled && !isAiming;
    if (running && wish.length2 > 0.01) crouching = false;
    _rollWait = math.max(0, _rollWait - dt);
    if (isRolling) {
      _updateRoll(dt);
    } else {
      player.update(
        dt,
        wish,
        running: running,
        crouching: crouching,
        face: isAiming || _throwTime != null ? _aimDirection : null,
      );
    }
    crouchAmount += ((crouching ? 1 : 0) - crouchAmount) * math.min(1, dt * 10);
    // La cámara "respira" con la postura: corriendo se aleja, agachado se
    // acerca y baja (despacio, para que no maree).
    final stanceGoal = isRolling
        ? camera.stance
        : crouching
        ? -1.0
        : player.speed > config.walkSpeed * 1.15
        ? 1.0
        : 0.0;
    camera.stance += (stanceGoal - camera.stance) * math.min(1, dt * 2.5);
    camera.avoidObstacles(player.position, ballSystem.heightAt, dt);
    signReader.update(player.position);

    final moved = player.distanceWalked - _lastDistance;
    _lastDistance = player.distanceWalked;
    if (_paused) return;
    if (_hitStop > 0) {
      _hitStop = math.max(0, _hitStop - dt);
      return;
    }

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
    _checkDodges();
    ballSystem.update(
      dt,
      wild: wild,
      drop: _dropBall,
      remove: (w) => removeWild(w.id),
      // Un golpe congela el mundo un instante. En el Safari, una bola
      // fallada se pierde y el que se escapa puede huir (el aviso lo dice).
      emit: (event) => _emit(switch (event) {
        BallHit() => _startHitStop(event),
        BallMissed(:final ball) when safariActive => BallMissed(
          ball,
          lost: true,
        ),
        PokemonBrokeFree() => _maybeFlee(event),
        _ => event,
      }),
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

  /// Gira y acerca la cámara según la entrada. Devuelve true si el
  /// jugador la giró (arrastrando o con Q/E).
  bool _updateCamera(double dt) {
    final (dragX, dragY) = cameraInput.takeDrag();
    camera
      ..rotate(
        -dragX * dragSensitivity + cameraInput.turnAxis * keyTurnSpeed * dt,
        dragY * dragSensitivity,
      )
      ..zoom(cameraInput.takeZoom())
      ..updateRecenter(dt);
    return dragX != 0 || dragY != 0 || cameraInput.turnAxis != 0;
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

  /// Todos los que apartan la hierba: jugador, Pokémon (los que están
  /// dentro de una bola, no; ni los escondidos: esos la agitan) y la bola
  /// que se sacude en el suelo (así se ve entre la hierba alta).
  Iterable<Vector3> get grassPushers sync* {
    yield player.position;
    for (final w in wild) {
      if (w.isFree && !w.hidden) yield w.position;
    }
    for (final b in ballSystem.balls) {
      if (b.pressesGrass) yield b.position;
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
    if (isRolling) return PlayerStealth.noisy;
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
    if (w.isDodging) {
      _dodge(w, dt);
      return;
    }
    if (w.overshootTo != null) {
      _overshoot(w, dt);
      return;
    }
    if (w.isDazed) {
      _daze(w, dt);
      return;
    }
    if (w.isLeaving) {
      _leave(w, dt);
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
      if (w.engaged || !w.isFree || w.hidden || w.isLeaving) continue;
      if (w.isDazed || w.overshootTo != null) continue;
      if (w.position.distanceTo(p) >= w.contactRadius) continue;
      if (w.temperament == Temperament.aggressive && w.isAlert) {
        // Rodando no te alcanza: se pasa de largo y queda aturdido.
        if (isRolling) {
          _startDaze(w);
          continue;
        }
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
