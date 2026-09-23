/// MODELO: los tipos de Poké Ball que se pueden encontrar y lanzar.
///
/// [multiplier] es el bonus de captura de cada una, como en los juegos:
/// la Super Ball atrapa 1,5 veces mejor y la Ultra Ball el doble.
enum PokeBallType {
  poke('Poké Ball', 1),
  great('Super Ball', 1.5),
  ultra('Ultra Ball', 2);

  const PokeBallType(this.label, this.multiplier);

  /// Nombre en español para la interfaz.
  final String label;
  final double multiplier;
}
