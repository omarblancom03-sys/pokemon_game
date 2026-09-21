/// MODELO: los tipos elementales tal y como los nombra PokeAPI
/// (campo `types[].type.name`).
///
/// Un enum es una lista cerrada de valores: evita textos mal escritos.
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

  /// Comodín para tipos que la app aún no conoce: si PokeAPI añade uno
  /// nuevo, la aplicación no se rompe.
  unknown;

  /// El identificador que usa la API, por ejemplo "fire".
  String get apiName => name;

  /// Texto de la API -> valor del enum. Si no lo reconoce, devuelve unknown.
  static PokemonType fromApiName(String apiName) {
    for (final type in values) {
      if (type.apiName == apiName) return type;
    }
    return PokemonType.unknown;
  }
}
