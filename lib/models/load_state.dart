/// Generic async state exposed by controllers and rendered by views.
sealed class LoadState<T> {
  const LoadState();
}

final class LoadIdle<T> extends LoadState<T> {
  const LoadIdle();
}

final class LoadInProgress<T> extends LoadState<T> {
  const LoadInProgress();
}

final class LoadSuccess<T> extends LoadState<T> {
  const LoadSuccess(this.data);

  final T data;
}

final class LoadFailure<T> extends LoadState<T> {
  const LoadFailure(this.error);

  /// Typed error (usually a `PokeApiException`); views map it to a message.
  final Object error;
}
