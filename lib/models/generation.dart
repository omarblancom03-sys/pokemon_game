import 'json_reader.dart';
import 'named_resource.dart';

/// One Pokémon generation as returned by `GET /generation/{id}`.
///
/// [species] are the generation's Pokémon species references, sorted by
/// national Pokédex number (the API returns them unordered).
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
    ]..sort(_byDexNumber);

    return Generation(
      id: json.readInt('id'),
      name: json.readString('name'),
      mainRegion: json.readMap('main_region').readString('name'),
      species: List.unmodifiable(species),
    );
  }

  /// Generation number, e.g. 1 for `generation-i`.
  final int id;

  /// Lowercase API name, e.g. `"generation-i"`. Formatting is a view concern.
  final String name;

  /// Lowercase region name, e.g. `"kanto"`.
  final String mainRegion;

  /// Species references ordered by Pokédex number.
  final List<NamedResource> species;

  /// Pokédex numbers of [species], skipping any reference without a numeric id.
  ///
  /// A species id maps to `/pokemon/{id}` for every national dex entry, so
  /// these are the ids controllers fetch details with.
  List<int> get speciesIds => [
    for (final resource in species)
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

  /// Sorts by dex number; references without an id go last.
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
