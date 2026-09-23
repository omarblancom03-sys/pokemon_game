/// MODELO: resultado de lanzar una Poké Ball a un Pokémon.
class CaptureResult {
  const CaptureResult({
    required this.chance,
    required this.shakes,
    required this.caught,
    this.critical = false,
  });

  /// Probabilidad que tenía el lanzamiento (0..1), para mostrarla.
  final double chance;

  /// Cuántas veces se sacude la bola en el suelo antes del final (0..3).
  final int shakes;

  final bool caught;

  /// Captura crítica: una sola comprobación (una sacudida) en vez de
  /// cuatro, así que es mucho más fácil que salga bien.
  final bool critical;
}
