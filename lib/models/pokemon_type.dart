/// Elemental types as exposed by PokeAPI (`types[].type.name`).
enum PokemonType {
  normal,
  fire,
  water,
  electric,
  grass,
  ice,
  fighting,
  poison,
  ground,
  flying,
  psychic,
  bug,
  rock,
  ghost,
  dragon,
  dark,
  steel,
  fairy,
  stellar,

  /// Fallback for type names this app does not know yet, so new API data
  /// never breaks parsing.
  unknown;

  /// The identifier used by PokeAPI, e.g. `"fire"`.
  String get apiName => name;

  static PokemonType fromApiName(String apiName) {
    for (final type in values) {
      if (type.apiName == apiName) return type;
    }
    return PokemonType.unknown;
  }
}
