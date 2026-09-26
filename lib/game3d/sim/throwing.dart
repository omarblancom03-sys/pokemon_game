import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../../controllers/capture/capture_calculator.dart';
import '../../game/map/map_layout.dart';
import '../../models/poke_ball.dart';
import 'wild_pokemon.dart';
import 'world3d_events.dart';

/// Gravedad del mundo (m/s²). Algo más fuerte que la real: los
/// lanzamientos se sienten más rápidos y "de videojuego".
const gravity = 14.0;

/// Rapidez con la que sale la bola de la mano (m/s).
const throwSpeed = 15.0;

/// Radio de la Poké Ball (m).
const ballRadius = 0.12;

/// Velocidad inicial para que un objeto lanzado desde [from] a [speed]
/// pase por [to] (tiro parabólico, trayectoria BAJA de las dos posibles).
/// Devuelve null si está fuera de alcance.
Vector3? ballisticVelocity(
  Vector3 from,
  Vector3 to, {
  double speed = throwSpeed,
  double g = gravity,
}) {
  final flat = Vector3(to.x - from.x, 0, to.z - from.z);
  final dx = flat.length;
  final dy = to.y - from.y;
  if (dx < 1e-6) return Vector3(0, dy >= 0 ? speed : -speed, 0);
  final v2 = speed * speed;
  final disc = v2 * v2 - g * (g * dx * dx + 2 * dy * v2);
  if (disc < 0) return null;
  final angle = math.atan((v2 - math.sqrt(disc)) / (g * dx));
  flat.normalize();
  return flat * (speed * math.cos(angle)) +
      Vector3(0, speed * math.sin(angle), 0);
}

/// Altura (m) de lo que hay en una casilla, para los choques de las bolas:
/// una bola alta pasa por encima de una valla pero no de un árbol. Fuera
/// del mapa está el bosque.
double obstacleHeight(TileKind? kind) => switch (kind) {
  null => 8,
  TileKind.pine => 6,
  TileKind.tree || TileKind.autumnTree => 4.5,
  TileKind.house => 5,
  TileKind.sign => 1.5,
  TileKind.bush => 1.1,
  TileKind.fence => 1,
  _ => 0,
};

/// Fases de una Poké Ball lanzada.
enum BallPhase {
  /// Volando hacia su destino (solo ahora puede golpear a un Pokémon).
  flying,

  /// Golpeó a un Pokémon: rebota hacia arriba y lo absorbe.
  absorbing,

  /// Cae al suelo con el Pokémon dentro.
  falling,

  /// En el suelo, sacudiéndose.
  shaking,

  /// ¡Capturado! (breve celebración antes de desaparecer).
  caught,

  /// El Pokémon se escapó: la bola se abre y desaparece.
  escaped,

  /// No dio a nadie: rebota y rueda hasta pararse (y queda para recogerla).
  missed,
}

/// Una Poké Ball en el aire (o en el suelo con un Pokémon dentro).
class ThrownBall {
  ThrownBall({
    required this.id,
    required this.ball,
    required Vector3 position,
    required Vector3 velocity,
    this.quality = ThrowQuality.none,
  }) : position = position.clone(),
       velocity = velocity.clone();

  final String id;
  final PokeBallType ball;

  /// Calidad del tiro (el aro al lanzar): si le da, multiplica la
  /// probabilidad y se enseña ("¡Excelente! ×2").
  final ThrowQuality quality;
  Vector3 position;
  Vector3 velocity;

  BallPhase phase = BallPhase.flying;

  /// Segundos en la fase actual (marca las animaciones).
  double phaseTime = 0;

  /// Segundos desde el lanzamiento.
  double age = 0;

  /// Giro de la bola (rad), solo visual.
  double spin = 0;

  /// Pokémon golpeado (dentro de la bola) y el resultado ya decidido.
  WildPokemon? target;
  CaptureResult? result;

  /// Cómo fue el golpe (sin ser visto, por la espalda, mientras comía): se
  /// le enseña al jugador sobre el Pokémon. null si aún no ha golpeado a
  /// nadie.
  ({bool unaware, bool fromBehind, bool eating})? hit;

  /// [age] en el momento del golpe.
  double? hitAge;

  /// Dónde golpeó (para la onda del impacto). null si aún no ha golpeado.
  Vector3? hitPoint;

  /// Lo que dura la onda del impacto (s).
  static const impactTime = 0.35;

  /// 0..1 mientras se ve la onda del impacto; null antes del golpe y
  /// después de [impactTime].
  double? get impactProgress {
    final s = sinceHit;
    if (s == null || s > impactTime) return null;
    return s / impactTime;
  }

  /// Segundos desde el golpe (null si no ha golpeado).
  double? get sinceHit => hitAge == null ? null : age - hitAge!;

  /// Sacudidas ya hechas en el suelo.
  int shakesDone = 0;

  /// Rebotes contra el suelo.
  int bounces = 0;

  /// Estela: últimos puntos por los que pasó volando (el más reciente al
  /// final). Al dejar de volar se va acortando hasta desaparecer.
  final List<Vector3> trail = [];

  /// Separación entre puntos de la estela (m) y cuántos como mucho.
  static const trailSpacing = 0.3;
  static const trailLength = 12;

  /// Apunta la posición actual en la estela (si está volando) o la acorta.
  void updateTrail() {
    if (phase != BallPhase.flying) {
      if (trail.isNotEmpty) trail.removeAt(0);
      return;
    }
    if (trail.isEmpty || trail.last.distanceTo(position) >= trailSpacing) {
      trail.add(position.clone());
      if (trail.length > trailLength) trail.removeAt(0);
    }
  }

  /// Duraciones de cada fase (s).
  static const absorbTime = 0.55;
  static const shakeSettle = 0.4;
  static const shakeTime = 0.85;
  static const shakePause = 0.35;
  static const caughtTime = 1.6;
  static const escapeTime = 0.6;

  /// Un ciclo de sacudida completo (sacudirse + quedarse quieta).
  static const shakeCycle = shakeTime + shakePause;

  void setPhase(BallPhase next) {
    phase = next;
    phaseTime = 0;
  }

  /// Segundos que pasa en el suelo antes de saberse el final.
  double get shakingDuration =>
      shakeSettle + (result?.shakes ?? 0) * shakeCycle;

  /// Ángulo de la sacudida actual (rad) para dibujarla.
  double get wobble {
    if (phase != BallPhase.shaking) return 0;
    final t = phaseTime - shakeSettle;
    if (t < 0) return 0;
    final cycle = (t / shakeCycle).floor();
    if (cycle >= (result?.shakes ?? 0)) return 0;
    final inCycle = t - cycle * shakeCycle;
    if (inCycle > shakeTime) return 0;
    // Un vaivén que se amortigua: izquierda fuerte, derecha, y se para.
    final s = inCycle / shakeTime;
    // La crítica se sacude con más fuerza: todo se decide en esa sacudida.
    final strength = (result?.critical ?? false) ? 0.8 : 0.55;
    return math.sin(s * 3 * math.pi) * strength * (1 - s);
  }

  /// Luz roja del botón (0..1): se enciende con cada sacudida y se apaga
  /// en la pausa entre una y otra, como en los juegos.
  double get buttonGlow {
    if (phase != BallPhase.shaking) return 0;
    final t = phaseTime - shakeSettle;
    if (t < 0) return 0;
    final cycle = (t / shakeCycle).floor();
    if (cycle >= (result?.shakes ?? 0)) return 0;
    final inCycle = t - cycle * shakeCycle;
    if (inCycle > shakeTime) return 0;
    return math.sin(inCycle / shakeTime * math.pi);
  }

  /// "¡Clic!" al capturar: destello blanco del botón (1 → 0 en [clickTime]).
  double get clickFlash =>
      phase == BallPhase.caught ? math.max(0, 1 - phaseTime / clickTime) : 0;

  static const clickTime = 0.35;

  /// 0..1 mientras absorbe al Pokémon (para encogerlo hacia la bola).
  double get absorbProgress => switch (phase) {
    BallPhase.absorbing => (phaseTime / absorbTime).clamp(0.0, 1.0),
    BallPhase.flying || BallPhase.missed => 0,
    _ => 1,
  };

  /// ¿Está quieta en el suelo?
  bool get isResting =>
      phase == BallPhase.shaking ||
      phase == BallPhase.caught ||
      phase == BallPhase.escaped;
}

/// LAS BOLAS LANZADAS: vuelo parabólico, choques (Pokémon, árboles, casas,
/// suelo) y toda la secuencia de captura:
///
///   volar → golpear → absorber → caer → sacudidas → ¡capturado! / se escapa
///   volar → no dar a nadie → rebotar y rodar → queda en el suelo
///
/// Es Dart puro: el resultado de la captura se decide con
/// [CaptureCalculator] en el momento del golpe, y lo demás es tiempo.
class BallSystem {
  BallSystem({
    required this.layout,
    required this.tileSize,
    required this.calculator,
  });

  final MapLayout layout;
  final double tileSize;
  final CaptureCalculator calculator;

  /// Probabilidad de captura crítica de cada golpe (la experiencia del
  /// entrenador; ver CaptureCalculator.criticalChanceFor).
  double criticalChance = 0;

  final List<ThrownBall> _balls = [];
  int _count = 0;
  void Function(Vector3 at)? _impact;
  void Function(Vector3 at, double speed)? _bounce;

  List<ThrownBall> get balls => List.unmodifiable(_balls);

  /// Paso máximo de la física (s): a 15 m/s son 12 cm, menos que el
  /// radio de cualquier Pokémon, así ninguna bola lo "atraviesa".
  static const maxStep = 1 / 120;

  /// Rebote contra el suelo (0 = nada, 1 = perfecto) y rozamiento al rodar.
  static const restitution = 0.45;
  static const rollFriction = 5.0;

  /// Tras escaparse, el Pokémon queda alerta estos segundos.
  static const escapeAlertSeconds = 4.0;

  /// Lanza una bola desde [from] con velocidad [velocity] y la
  /// calidad del tiro [quality].
  ThrownBall launch(
    PokeBallType ball,
    Vector3 from,
    Vector3 velocity, {
    ThrowQuality quality = ThrowQuality.none,
  }) {
    final thrown = ThrownBall(
      id: 'ball-${_count++}',
      ball: ball,
      position: from,
      velocity: velocity,
      quality: quality,
    );
    _balls.add(thrown);
    return thrown;
  }

  /// Altura del obstáculo que hay bajo el punto [p].
  double heightAt(double x, double z) => obstacleHeight(
    layout.tileAt((x / tileSize).floor(), (z / tileSize).floor()),
  );

  /// Avanza [dt] segundos. [wild] son los Pokémon a los que se puede
  /// golpear; [drop] deja en el suelo una bola fallada; [remove] saca del
  /// mundo al Pokémon capturado; [impact] avisa del primer golpe de una
  /// bola fallada contra el suelo u otra cosa (el ruido asusta). [bounce]
  /// avisa de cada bote contra el suelo, con la velocidad de caída (polvo).
  void update(
    double dt, {
    required List<WildPokemon> wild,
    required void Function(PokeBallType ball, Vector3 at) drop,
    required void Function(WildPokemon wild) remove,
    required void Function(World3DEvent event) emit,
    void Function(Vector3 at)? impact,
    void Function(Vector3 at, double speed)? bounce,
  }) {
    _impact = impact;
    _bounce = bounce;
    for (final ball in _balls.toList()) {
      ball
        ..age += dt
        ..phaseTime += dt;
      ball.updateTrail();
      switch (ball.phase) {
        case BallPhase.flying || BallPhase.missed:
          final wasFlying = ball.phase == BallPhase.flying;
          _fly(ball, dt, wild);
          if (wasFlying && ball.phase == BallPhase.absorbing) {
            emit(BallHit(ball.target!, ball.quality));
          }
          if (ball.phase == BallPhase.missed && _stopped(ball)) {
            _balls.remove(ball);
            drop(ball.ball, ball.position);
            emit(BallMissed(ball.ball));
          }
        case BallPhase.absorbing:
          _fly(ball, dt, const []);
          if (ball.phaseTime >= ThrownBall.absorbTime) {
            ball.setPhase(BallPhase.falling);
          }
        case BallPhase.falling:
          _fly(ball, dt, const []);
          if (_stopped(ball)) ball.setPhase(BallPhase.shaking);
        case BallPhase.shaking:
          _shake(ball, remove, emit);
        case BallPhase.caught:
          if (ball.phaseTime >= ThrownBall.caughtTime) _balls.remove(ball);
        case BallPhase.escaped:
          if (ball.phaseTime >= ThrownBall.escapeTime) _balls.remove(ball);
      }
    }
  }

  /// ¿Ya está parada en el suelo?
  bool _stopped(ThrownBall b) =>
      b.position.y <= ballRadius + 1e-6 &&
      b.velocity.y == 0 &&
      b.velocity.x == 0 &&
      b.velocity.z == 0;

  /// Física con pasos pequeños (ver [maxStep]).
  void _fly(ThrownBall ball, double dt, List<WildPokemon> wild) {
    final steps = math.max(1, (dt / maxStep).ceil());
    final h = dt / steps;
    for (var i = 0; i < steps; i++) {
      if (_step(ball, h, wild)) return; // golpeó a un Pokémon
    }
  }

  /// Un paso de física. Devuelve true si golpeó a un Pokémon.
  bool _step(ThrownBall ball, double h, List<WildPokemon> wild) {
    final v = ball.velocity;
    final p = ball.position;
    final onGround = p.y <= ballRadius + 1e-6 && v.y == 0;
    if (!onGround) v.y -= gravity * h;
    final next = p + v * h;

    if (ball.phase == BallPhase.flying) {
      final hit = _hitTest(next, wild);
      if (hit != null) {
        _capture(ball, hit);
        return true;
      }
    }

    // Árboles, casas, vallas... la bola rebota hacia atrás.
    if (next.y < heightAt(next.x, next.z)) {
      final blockX = next.y < heightAt(next.x, p.z);
      final blockZ = next.y < heightAt(p.x, next.z);
      if (blockX || !blockZ) v.x = -v.x * 0.4;
      if (blockZ || !blockX) v.z = -v.z * 0.4;
      next
        ..x = p.x
        ..z = p.z;
      _toMissed(ball);
    }

    // Suelo: rebota perdiendo fuerza y, al final, rueda hasta pararse.
    if (next.y <= ballRadius) {
      next.y = ballRadius;
      if (v.y < 0) {
        _bounce?.call(next, -v.y);
        ball.bounces++;
        v
          ..y = -v.y * restitution
          ..x *= 0.7
          ..z *= 0.7;
        if (v.y < 1.2) v.y = 0;
        // Con un Pokémon dentro casi no rueda: se queda donde cae.
        if (ball.phase == BallPhase.falling) {
          v
            ..x *= 0.3
            ..z *= 0.3;
        }
        _toMissed(ball);
      }
      if (v.y == 0) {
        final flat = Vector3(v.x, 0, v.z);
        final speed = flat.length;
        final slower = speed - rollFriction * h;
        if (slower <= 0.2) {
          v.setZero();
        } else {
          v
            ..x *= slower / speed
            ..z *= slower / speed;
        }
      }
    }

    final moved = (next - p).length;
    ball
      ..position = next
      ..spin += moved / ballRadius;
    return false;
  }

  /// Tras el primer choque sin golpear a nadie, ya es un fallo.
  void _toMissed(ThrownBall ball) {
    if (ball.phase != BallPhase.flying) return;
    ball.setPhase(BallPhase.missed);
    _impact?.call(ball.position);
  }

  /// El primer Pokémon libre cuyo "cilindro" contiene el punto [p].
  WildPokemon? _hitTest(Vector3 p, List<WildPokemon> wild) {
    for (final w in wild) {
      if (!w.isFree) continue;
      final dx = p.x - w.position.x;
      final dz = p.z - w.position.z;
      final r = w.hitRadius + ballRadius;
      if (dx * dx + dz * dz < r * r &&
          p.y > -ballRadius &&
          p.y < w.displayHeight + ballRadius) {
        return w;
      }
    }
    return null;
  }

  /// ¡Golpe! Se decide ya el resultado (sacudidas y si se captura) y la
  /// bola rebota hacia arriba para absorberlo.
  void _capture(ThrownBall ball, WildPokemon w) {
    final flat = Vector3(ball.velocity.x, 0, ball.velocity.z);
    if (flat.length2 > 0) flat.normalize();
    // "Por la espalda": la bola viaja en el mismo sentido en que mira él.
    final fromBehind = flat.dot(w.facingDirection) > 0.5;
    final unaware = !w.isAlert;
    final eating = w.isEating;
    ball
      ..target = w
      ..hit = (unaware: unaware, fromBehind: fromBehind, eating: eating)
      ..hitAge = ball.age
      ..hitPoint = ball.position.clone()
      ..result = calculator.roll(
        captureRate: w.captureRate,
        ball: ball.ball,
        unaware: unaware,
        fromBehind: fromBehind,
        eating: eating,
        quality: ball.quality,
        criticalChance: criticalChance,
      )
      ..velocity = flat * -1.2 + Vector3(0, 4.2, 0)
      ..setPhase(BallPhase.absorbing);
    w
      ..capturedBy = ball.id
      ..hidden =
          false // si estaba escondido, ¡sorpresa!
      ..target = null;
  }

  /// En el suelo: sacudidas y, al final, el resultado.
  void _shake(
    ThrownBall ball,
    void Function(WildPokemon wild) remove,
    void Function(World3DEvent event) emit,
  ) {
    final result = ball.result!;
    final t = ball.phaseTime - ThrownBall.shakeSettle;
    final before = ball.shakesDone;
    ball.shakesDone = t < 0
        ? 0
        : math.min(result.shakes, (t / ThrownBall.shakeCycle).floor());
    if (ball.shakesDone > before) {
      emit(BallShook(ball.shakesDone, critical: result.critical));
    }
    if (ball.phaseTime < ball.shakingDuration) return;

    final w = ball.target!;
    if (result.caught) {
      ball.setPhase(BallPhase.caught);
      remove(w);
      emit(
        PokemonCaught(
          w,
          ball.ball,
          result,
          hit: ball.hit,
          quality: ball.quality,
        ),
      );
    } else {
      ball.setPhase(BallPhase.escaped);
      w
        ..capturedBy = null
        ..releasedFor = 0
        ..awareness = 1
        ..alertTime = escapeAlertSeconds;
      emit(PokemonBrokeFree(w, ball.ball, result, hit: ball.hit));
    }
  }

  /// Puntos por los que pasaría una bola lanzada desde [from] a [velocity]
  /// hasta tocar el suelo, un obstáculo o un Pokémon de [wild] (para
  /// dibujar la trayectoria al apuntar). El último punto es el impacto.
  List<Vector3> predict(
    Vector3 from,
    Vector3 velocity, {
    List<WildPokemon> wild = const [],
    double step = 1 / 30,
    double maxTime = 2.5,
  }) {
    final points = [from.clone()];
    final p = from.clone();
    final v = velocity.clone();
    for (var t = 0.0; t < maxTime; t += step) {
      v.y -= gravity * step;
      p.add(v * step);
      if (p.y <= ballRadius ||
          p.y < heightAt(p.x, p.z) ||
          _hitTest(p, wild) != null) {
        points.add(p..y = math.max(p.y, ballRadius));
        break;
      }
      points.add(p.clone());
    }
    return points;
  }
}
