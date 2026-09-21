/// Every failure raised by `PokeApiService`. Sealed so controllers and views
/// can switch exhaustively over the cases.
sealed class PokeApiException implements Exception {
  const PokeApiException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// No connection, DNS failure, timeout, or the request was aborted.
final class PokeApiNetworkException extends PokeApiException {
  const PokeApiNetworkException(super.message, {this.cause});

  final Object? cause;
}

/// The resource does not exist (HTTP 404).
final class PokeApiNotFoundException extends PokeApiException {
  const PokeApiNotFoundException(this.uri) : super('Not found: $uri');

  final Uri uri;
}

/// Any other non-2xx response.
final class PokeApiServerException extends PokeApiException {
  const PokeApiServerException(this.statusCode, this.uri)
    : super('HTTP $statusCode for $uri');

  final int statusCode;
  final Uri uri;
}

/// The response body was not the JSON shape we expect.
final class PokeApiParseException extends PokeApiException {
  const PokeApiParseException(super.message, {this.cause});

  final Object? cause;
}
