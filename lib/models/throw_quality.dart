/// CALIDAD DEL LANZAMIENTO: al apuntar a un Pokémon, un aro se encoge
/// dentro de la mira (como en Pokémon GO); cuanto más pequeño está al
/// lanzar, mejor es el tiro y más fácil la captura. Solo cuenta si la bola
/// le da.
enum ThrowQuality {
  /// El aro aún era grande: sin bonus.
  none(1),

  /// "¡Bien!"
  nice(1.2),

  /// "¡Genial!"
  great(1.5),

  /// "¡Excelente!"
  excellent(2);

  const ThrowQuality(this.bonus);

  /// Multiplica la probabilidad de captura.
  final double bonus;
}
