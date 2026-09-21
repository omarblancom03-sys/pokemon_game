import 'json_reader.dart';

/// One page of a PokeAPI list endpoint (`count`, `next`, `results`).
class PagedResult<T> {
  const PagedResult({
    required this.count,
    required this.next,
    required this.items,
  });

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) parseItem,
  ) => PagedResult(
    count: json.readInt('count'),
    next: json.readStringOrNull('next'),
    items: List.unmodifiable(json.readObjectList('results').map(parseItem)),
  );

  /// Total number of resources on the server (not the size of this page).
  final int count;

  /// URL of the next page, or null on the last page.
  final String? next;

  final List<T> items;

  bool get hasNext => next != null;
}
