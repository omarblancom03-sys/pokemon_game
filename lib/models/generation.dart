import 'json_reader.dart';
import 'named_resource.dart';

/// MODELO: una generación de Pokémon, tal y como la devuelve
/// `GET /generation/{id}`.
///
/// [species] son las especies de esa generación ORDENADAS por número de
/// Pokédex (la API las devuelve desordenadas; si no se ordenaran, la
/// galería de Kanto empezaría por Abra).
class Generation {
  const Generation({
    required this.id,
    required this.name,
    required this.mainRegion,
    required this.species,
  });

  factory Generation.fromJson(Map<String, dynamic> json) {
    final species = [
      for (final item in json.readObjectList('pokemon_species'))
        NamedResource.fromJson(item),
    ]..sort(_byDexNumber); // ..sort = operador cascada: ordena y devuelve la lista

    return Generation(
      id: json.readInt('id'),
      name: json.readString('name'),
      mainRegion: json.readMap('main_region').readString('name'),
      species: List.unmodifiable(species),
    );
  }

  /// Número de generación: 1 para "generation-i".
  final int id;

  /// Nombre de la API en minúsculas ("generation-i"). Formatearlo es cosa
  /// de la vista (generationLabel → "Generación I").
  final String name;

  /// Región principal en minúsculas ("kanto").
  final String mainRegion;

  /// Referencias a las especies, ya ordenadas.
  final List<NamedResource> species;

  /// Solo los números de Pokédex, saltándose las referencias sin id.
  /// Son los ids con los que los controladores piden `/pokemon/{id}`.
  List<int> get speciesIds => [
    for (final resource in species)
      // "if (x case final int id)": si es un entero, úsalo; si no, sáltalo.
      if (resource.id case final int id) id,
  ];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'main_region': {'name': mainRegion},
    'pokemon_species': [for (final resource in species) resource.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is Generation &&
      other.id == id &&
      other.name == name &&
      other.mainRegion == mainRegion &&
      _sameSpecies(other.species, species);

  @override
  int get hashCode =>
      Object.hash(id, name, mainRegion, Object.hashAll(species));

  @override
  String toString() => 'Generation(#$id $name, ${species.length} species)';

  /// Ordena por número de Pokédex; las que no tienen id se van al final.
  static int _byDexNumber(NamedResource a, NamedResource b) {
    final idA = a.id;
    final idB = b.id;
    if (idA == null) return idB == null ? 0 : 1;
    if (idB == null) return -1;
    return idA.compareTo(idB);
  }

  static bool _sameSpecies(List<NamedResource> a, List<NamedResource> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
