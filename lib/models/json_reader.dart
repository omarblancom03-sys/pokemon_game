/// Lectura segura de los mapas JSON que llegan de PokeAPI.
///
/// Es una "extension": añade métodos a un tipo que ya existe (aquí, a
/// `Map<String, dynamic>`) sin heredar de él.
///
/// Si un campo falta o tiene otro tipo, lanza FormatException diciendo QUÉ
/// campo falla; así el error salta aquí y no veinte líneas más tarde.
extension JsonReader on Map<String, dynamic> {
  // Método común: comprueba el tipo y, si no cuadra, lanza el error.
  T _require<T>(String key) {
    final value = this[key];
    if (value is T) return value;
    throw FormatException(
      'Expected "$key" to be $T but got ${value.runtimeType}',
    );
  }

  int readInt(String key) => _require<int>(key);

  String readString(String key) => _require<String>(key);

  /// Texto que puede venir vacío (null), pero no de otro tipo.
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

  /// Lee una lista cuyos elementos deben ser todos objetos JSON.
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
