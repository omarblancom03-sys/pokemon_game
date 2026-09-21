import 'json_reader.dart';

/// MODELO: una referencia `{name, url}`, que es lo que devuelven las listas
/// de PokeAPI (no traen los datos completos, solo el nombre y el enlace).
class NamedResource {
  const NamedResource({required this.name, required this.url});

  factory NamedResource.fromJson(Map<String, dynamic> json) =>
      NamedResource(name: json.readString('name'), url: json.readString('url'));

  final String name;
  final String url;

  /// Getter (propiedad calculada): saca el id del final de la URL
  /// (`.../pokemon/25/` → 25). Devuelve null si la URL no acaba en número.
  int? get id {
    final segments = Uri.tryParse(url)?.pathSegments
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments == null || segments.isEmpty) return null;
    return int.tryParse(segments.last);
  }

  Map<String, dynamic> toJson() => {'name': name, 'url': url};

  // Igualdad por contenido (mismo nombre y misma url).
  @override
  bool operator ==(Object other) =>
      other is NamedResource && other.name == name && other.url == url;

  @override
  int get hashCode => Object.hash(name, url);

  @override
  String toString() => 'NamedResource($name, $url)';
}
