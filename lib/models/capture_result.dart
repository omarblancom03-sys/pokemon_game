/// MODELO: resultado de lanzar una Poké Ball a un Pokémon.
class CaptureResult {
  const CaptureResult({
    required this.chance,
    required this.shakes,
    required this.caught,
  });

  /// Probabilidad que tenía el lanzamiento (0..1), para mostrarla.
  final double chance;

  /// Cuántas veces se sacude la bola en el suelo antes del final (0..3).
  final int shakes;

  final bool caught;
}
