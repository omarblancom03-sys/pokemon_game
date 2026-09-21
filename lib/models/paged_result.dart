import 'json_reader.dart';

/// MODELO genérico: una página de una lista de PokeAPI
/// (campos `count`, `next` y `results`).
///
/// La `<T>` es un hueco de tipo: sirve igual para páginas de Pokémon
/// que de generaciones.
class PagedResult<T> {
  const PagedResult({
    required this.count,
    required this.next,
    required this.items,
  });

  /// Recibe además una función que sabe convertir cada elemento de la lista.
  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) parseItem,
  ) => PagedResult(
    count: json.readInt('count'),
    next: json.readStringOrNull('next'),
    items: List.unmodifiable(json.readObjectList('results').map(parseItem)),
  );

  /// Total de recursos en el servidor (NO cuántos vienen en esta página).
  final int count;

  /// URL de la página siguiente, o null si esta es la última.
  final String? next;

  final List<T> items;

  bool get hasNext => next != null;
}
