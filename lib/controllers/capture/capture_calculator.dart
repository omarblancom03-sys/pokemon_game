import 'dart:math' as math;

import '../../models/capture_result.dart';
import '../../models/poke_ball.dart';

export '../../models/capture_result.dart';

/// LÓGICA DE CAPTURA (sin combate, estilo Leyendas Arceus): no hay PS que
/// bajar, así que la probabilidad depende de
///  - el ratio de captura REAL de la especie (PokeAPI, 3..255),
///  - el tipo de Poké Ball,
///  - el sigilo: si el Pokémon no te ha visto ×1,5, y por la espalda ×2,
///  - y si se está comiendo una baya ×1,5 (distraído; se suma al sigilo).
///
/// Las sacudidas imitan a los juegos: se hacen 4 comprobaciones, cada una
/// con probabilidad `p^(1/4)` (así las 4 juntas dan exactamente `p`). Se
/// ven tantas sacudidas como comprobaciones superadas (máximo 3) y solo se
/// captura si se superan las 4.
class CaptureCalculator {
  CaptureCalculator({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  /// Bonus por no haber sido visto y por lanzar por la espalda.
  static const unawareBonus = 1.5;
  static const backStrikeBonus = 2.0;

  /// Bonus si se está comiendo una baya (como la Baya Frambu de los juegos).
  static const eatingBonus = 1.5;

  /// Probabilidad de captura (0..1).
  static double chance({
    required int captureRate,
    required PokeBallType ball,
    required bool unaware,
    required bool fromBehind,
    bool eating = false,
  }) {
    final stealth = !unaware
        ? 1.0
        : fromBehind
        ? backStrikeBonus
        : unawareBonus;
    final food = eating ? eatingBonus : 1.0;
    final rate = captureRate.clamp(1, 255) / 255;
    return (rate * ball.multiplier * stealth * food).clamp(0.0, 1.0);
  }

  /// Probabilidad de CAPTURA CRÍTICA según cuántas especies distintas ha
  /// capturado ya el entrenador (como en los juegos, depende de la
  /// experiencia): 2 % por especie, hasta un 25 %. Con 0 especies, nunca.
  static double criticalChanceFor(int speciesCaught) =>
      math.min(maxCriticalChance, 0.02 * speciesCaught);

  static const maxCriticalChance = 0.25;

  /// Tira los dados de un lanzamiento. Con [criticalChance] > 0 puede salir
  /// una captura crítica: una sola comprobación (una sacudida) en vez de
  /// cuatro, mucho más fácil de superar.
  CaptureResult roll({
    required int captureRate,
    required PokeBallType ball,
    required bool unaware,
    required bool fromBehind,
    bool eating = false,
    double criticalChance = 0,
  }) {
    final p = chance(
      captureRate: captureRate,
      ball: ball,
      unaware: unaware,
      fromBehind: fromBehind,
      eating: eating,
    );
    final perCheck = math.pow(p, 0.25).toDouble();
    // Sin posibilidad de crítico no se tira ese dado (no gasta azar).
    if (criticalChance > 0 && _random.nextDouble() < criticalChance) {
      final ok = _random.nextDouble() < perCheck;
      return CaptureResult(
        chance: p,
        shakes: ok ? 1 : 0,
        caught: ok,
        critical: true,
      );
    }
    var passed = 0;
    while (passed < 4 && _random.nextDouble() < perCheck) {
      passed++;
    }
    return CaptureResult(
      chance: p,
      shakes: math.min(passed, 3),
      caught: passed == 4,
    );
  }
}
