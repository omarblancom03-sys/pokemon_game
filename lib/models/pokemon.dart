import 'json_reader.dart';
import 'pokemon_type.dart';

/// Immutable Pokémon data used across the app (Pokédex cards and encounters).
///
/// [fromJson] accepts the `GET /pokemon/{id}` payload from PokeAPI; [toJson]
/// emits the same shape (only the fields we use), so the two round-trip.
class Pokemon {
  const Pokemon({
    required this.id,
    required this.name,
    required this.types,
    required this.imageUrl,
    required this.height,
    required this.weight,
  });

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    final types = json.readObjectList('types')
      ..sort((a, b) => a.readInt('slot').compareTo(b.readInt('slot')));

    return Pokemon(
      id: json.readInt('id'),
      name: json.readString('name'),
      types: List.unmodifiable([
        for (final slot in types)
          PokemonType.fromApiName(slot.readMap('type').readString('name')),
      ]),
      imageUrl: _readImageUrl(json.readMap('sprites')),
      height: json.readInt('height'),
      weight: json.readInt('weight'),
    );
  }

  /// National Pokédex number.
  final int id;

  /// Lowercase API name, e.g. `"mr-mime"`. Display formatting is a view concern.
  final String name;

  /// Ordered by slot (primary type first). Never empty for valid API data.
  final List<PokemonType> types;

  /// Official artwork when available, otherwise the default sprite, else null.
  final String? imageUrl;

  /// In decimetres, as returned by the API.
  final int height;

  /// In hectograms, as returned by the API.
  final int weight;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'types': [
      for (var i = 0; i < types.length; i++)
        {
          'slot': i + 1,
          'type': {'name': types[i].apiName},
        },
    ],
    'sprites': {
      'front_default': null,
      'other': {
        'official-artwork': {'front_default': imageUrl},
      },
    },
    'height': height,
    'weight': weight,
  };

  static String? _readImageUrl(Map<String, dynamic> sprites) {
    final artwork = sprites
        .readMapOrNull('other')
        ?.readMapOrNull('official-artwork')
        ?.readStringOrNull('front_default');
    return artwork ?? sprites.readStringOrNull('front_default');
  }

  @override
  bool operator ==(Object other) =>
      other is Pokemon &&
      other.id == id &&
      other.name == name &&
      other.imageUrl == imageUrl &&
      other.height == height &&
      other.weight == weight &&
      _sameTypes(other.types, types);

  @override
  int get hashCode =>
      Object.hash(id, name, imageUrl, height, weight, Object.hashAll(types));

  @override
  String toString() => 'Pokemon(#$id $name ${types.map((t) => t.name)})';

  static bool _sameTypes(List<PokemonType> a, List<PokemonType> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
