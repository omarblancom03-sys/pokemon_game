import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../../models/capture_result.dart';
import '../../models/poke_ball.dart';
import 'wild_pokemon.dart';

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

/// Fases de una Poké Ball lanzada.
enum BallPhase {
  /// Volando hacia su destino.
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

  /// No dio a nadie: rebota por el suelo y se queda allí para recogerla.
  missed,
}

/// Una Poké Ball en el aire (o en el suelo con un Pokémon dentro).
class ThrownBall {
  ThrownBall({
    required this.id,
    required this.ball,
    required Vector3 position,
    required Vector3 velocity,
  }) : position = position.clone(),
       velocity = velocity.clone();

  final String id;
  final PokeBallType ball;
  Vector3 position;
  Vector3 velocity;

  BallPhase phase = BallPhase.flying;

  /// Segundos en la fase actual (marca las animaciones).
  double phaseTime = 0;

  /// Giro de la bola en vuelo (rad), solo visual.
  double spin = 0;

  /// Pokémon golpeado (dentro de la bola) y el resultado ya decidido.
  WildPokemon? target;
  CaptureResult? result;

  /// Sacudidas ya hechas en el suelo.
  int shakesDone = 0;

  /// Rebotes contra el suelo cuando falla.
  int bounces = 0;

  /// Duraciones de cada fase (s).
  static const absorbTime = 0.55;
  static const shakeTime = 0.85;
  static const shakePause = 0.35;
  static const caughtTime = 1.4;
  static const escapeTime = 0.6;

  void setPhase(BallPhase next) {
    phase = next;
    phaseTime = 0;
  }

  /// Ángulo de la sacudida actual (rad) para dibujarla.
  double get wobble {
    if (phase != BallPhase.shaking) return 0;
    final cycle = shakeTime + shakePause;
    final t = phaseTime % cycle;
    if (t > shakeTime) return 0;
    return math.sin(t / shakeTime * 2 * math.pi) * 0.5;
  }
}
