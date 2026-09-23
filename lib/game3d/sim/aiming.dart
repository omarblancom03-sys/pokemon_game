import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'orbit_camera.dart';
import 'throwing.dart';
import 'wild_pokemon.dart';

/// AYUDAS PARA APUNTAR (funciones puras): a quién se fija la mira, desde
/// dónde sale la bola y con qué velocidad.

/// Distancia máxima (m) a la que se fija un objetivo. Coincide más o menos
/// con el alcance real del tiro (v²/g ≈ 16 m en llano).
const maxLockDistance = 17.0;

/// Ángulo (rad) a cada lado del centro de la cámara dentro del cual se
/// fija un objetivo (≈ 20°): no hace falta una puntería perfecta.
const lockCone = 0.35;

/// El Pokémon libre más centrado delante de la cámara, o null.
WildPokemon? findLockTarget({
  required Vector3 player,
  required Vector3 forward,
  required Iterable<WildPokemon> wild,
}) {
  WildPokemon? best;
  var bestScore = double.infinity;
  final minCos = math.cos(lockCone);
  for (final w in wild) {
    if (!w.isFree) continue;
    final to = w.position - player
      ..y = 0;
    final d = to.length;
    if (d < 0.5 || d > maxLockDistance) continue;
    final cos = to.dot(forward) / d;
    if (cos < minCos) continue;
    // Manda estar centrado; a igualdad, el más cercano.
    final score = math.acos(cos.clamp(-1.0, 1.0)) + d * 0.01;
    if (score < bestScore) {
      bestScore = score;
      best = w;
    }
  }
  return best;
}

/// Mano derecha del entrenador (de donde sale la bola) para alguien en
/// [feet] que mira hacia [facing].
Vector3 handPosition(Vector3 feet, double facing) {
  final forward = Vector3(math.sin(facing), 0, math.cos(facing));
  final right = Vector3(-math.cos(facing), 0, math.sin(facing));
  return feet + Vector3(0, 1.55, 0) + right * 0.3 + forward * 0.2;
}

/// Tiro "a ojo" hacia donde mira la cámara: la inclinación de la cámara
/// decide la altura del arco (cámara baja = tiro más alto y largo).
Vector3 freeThrowVelocity(OrbitCamera camera) {
  final elevation = (0.62 - camera.pitch * 0.9).clamp(-0.15, 0.85);
  return camera.forward * (throwSpeed * math.cos(elevation)) +
      Vector3(0, throwSpeed * math.sin(elevation), 0);
}

/// Tiro a un objetivo fijado: parábola hasta el centro de su cuerpo,
/// adelantándose a donde estará cuando llegue la bola. null si no llega.
Vector3? lockedThrowVelocity(Vector3 hand, WildPokemon target) {
  final chest = Vector3(0, target.displayHeight * 0.45, 0);
  var aim = target.position + chest;
  for (var i = 0; i < 2; i++) {
    final flat = Vector3(aim.x - hand.x, 0, aim.z - hand.z).length;
    final flight = flat / (throwSpeed * 0.9);
    aim = target.position + target.velocity * flight + chest;
  }
  return ballisticVelocity(hand, aim);
}
