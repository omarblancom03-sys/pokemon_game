import 'json_reader.dart';

/// A `{name, url}` reference as returned by PokeAPI list endpoints.
class NamedResource {
  const NamedResource({required this.name, required this.url});

  factory NamedResource.fromJson(Map<String, dynamic> json) =>
      NamedResource(name: json.readString('name'), url: json.readString('url'));

  final String name;
  final String url;

  /// Resource id taken from the URL's last path segment
  /// (`.../pokemon/25/` → 25), or null if the URL has no numeric id.
  int? get id {
    final segments = Uri.tryParse(url)?.pathSegments
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments == null || segments.isEmpty) return null;
    return int.tryParse(segments.last);
  }

  Map<String, dynamic> toJson() => {'name': name, 'url': url};

  @override
  bool operator ==(Object other) =>
      other is NamedResource && other.name == name && other.url == url;

  @override
  int get hashCode => Object.hash(name, url);

  @override
  String toString() => 'NamedResource($name, $url)';
}
