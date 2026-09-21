import 'json_reader.dart';
import 'pokemon_type.dart';

/// MODELO: un Pokémon. Es inmutable (todos los campos son final), así que
/// nadie puede modificarlo después de crearlo.
///
/// [fromJson] lo construye a partir de la respuesta de `GET /pokemon/{id}`;
/// [toJson] devuelve esa misma forma (solo los campos que usamos).
class Pokemon {
  const Pokemon({
    required this.id,
    required this.name,
    required this.types,
    required this.imageUrl,
    required this.height,
    required this.weight,
  });

  /// Constructor de fábrica: convierte el JSON crudo en un objeto limpio.
  factory Pokemon.fromJson(Map<String, dynamic> json) {
    // La API no garantiza el orden, así que se ordena por "slot":
    // el tipo principal debe quedar el primero (da el color de la carta).
    final types = json.readObjectList('types')
      ..sort((a, b) => a.readInt('slot').compareTo(b.readInt('slot')));

    return Pokemon(
      id: json.readInt('id'),
      name: json.readString('name'),
      // unmodifiable: la lista queda de solo lectura.
      types: List.unmodifiable([
        for (final slot in types)
          PokemonType.fromApiName(slot.readMap('type').readString('name')),
      ]),
      imageUrl: _readImageUrl(json.readMap('sprites')),
      height: json.readInt('height'),
      weight: json.readInt('weight'),
    );
  }

  /// Número de la Pokédex nacional.
  final int id;

  /// Nombre tal cual lo da la API, en minúsculas ("mr-mime").
  /// Darle formato bonito es tarea de la vista.
  final String name;

  /// Ordenados por slot (el principal primero).
  final List<PokemonType> types;

  /// Ilustración oficial si existe; si no, el sprite normal; si no, null.
  final String? imageUrl;

  /// En decímetros, como los devuelve la API (la vista los pasa a metros).
  final int height;

  /// En hectogramos, como los devuelve la API (la vista los pasa a kilos).
  final int weight;

  /// Objeto -> JSON (serializar). Sirve para guardar datos y para los tests.
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

  // Prioridad de imagen: ilustración oficial -> sprite normal -> nada.
  static String? _readImageUrl(Map<String, dynamic> sprites) {
    final artwork = sprites
        .readMapOrNull('other')
        ?.readMapOrNull('official-artwork')
        ?.readStringOrNull('front_default');
    return artwork ?? sprites.readStringOrNull('front_default');
  }

  // == define cuándo dos Pokémon se consideran iguales (por sus datos,
  // no por ser el mismo objeto en memoria).
  @override
  bool operator ==(Object other) =>
      other is Pokemon &&
      other.id == id &&
      other.name == name &&
      other.imageUrl == imageUrl &&
      other.height == height &&
      other.weight == weight &&
      _sameTypes(other.types, types);

  // Regla: si dos objetos son iguales, su hashCode debe coincidir.
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
