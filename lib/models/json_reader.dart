/// Typed accessors for decoded JSON maps.
///
/// Every failure is reported as a [FormatException] naming the offending key,
/// so callers only need to handle a single exception type for malformed data.
extension JsonReader on Map<String, dynamic> {
  T _require<T>(String key) {
    final value = this[key];
    if (value is T) return value;
    throw FormatException(
      'Expected "$key" to be $T but got ${value.runtimeType}',
    );
  }

  int readInt(String key) => _require<int>(key);

  String readString(String key) => _require<String>(key);

  String? readStringOrNull(String key) {
    final value = this[key];
    if (value == null || value is String) return value as String?;
    throw FormatException(
      'Expected "$key" to be String? but got ${value.runtimeType}',
    );
  }

  Map<String, dynamic> readMap(String key) =>
      _require<Map<String, dynamic>>(key);

  Map<String, dynamic>? readMapOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    return readMap(key);
  }

  /// Reads a list whose elements are all JSON objects.
  List<Map<String, dynamic>> readObjectList(String key) {
    final list = _require<List<dynamic>>(key);
    return [
      for (final item in list)
        if (item is Map<String, dynamic>)
          item
        else
          throw FormatException('Expected "$key" to contain only objects'),
    ];
  }
}
