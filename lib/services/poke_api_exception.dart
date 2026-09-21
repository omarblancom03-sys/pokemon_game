/// Todos los fallos que puede lanzar PokeApiService.
///
/// `sealed` = la lista de casos es cerrada, así que la vista puede hacer un
/// switch completo y el compilador avisa si falta alguno.
sealed class PokeApiException implements Exception {
  const PokeApiException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Sin conexión, DNS caído, tiempo de espera agotado o petición abortada.
final class PokeApiNetworkException extends PokeApiException {
  const PokeApiNetworkException(super.message, {this.cause});

  /// Error original (de la librería http), por si hace falta depurar.
  final Object? cause;
}

/// El recurso no existe (HTTP 404).
final class PokeApiNotFoundException extends PokeApiException {
  const PokeApiNotFoundException(this.uri) : super('Not found: $uri');

  final Uri uri;
}

/// Cualquier otra respuesta que no sea 2xx (por ejemplo, un 500).
final class PokeApiServerException extends PokeApiException {
  const PokeApiServerException(this.statusCode, this.uri)
    : super('HTTP $statusCode for $uri');

  final int statusCode;
  final Uri uri;
}

/// La respuesta no tenía la forma de JSON que esperábamos.
final class PokeApiParseException extends PokeApiException {
  const PokeApiParseException(super.message, {this.cause});

  final Object? cause;
}
