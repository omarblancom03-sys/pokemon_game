/// MODELO: estado de una carga, genérico, que los controladores exponen y
/// las vistas dibujan.
///
/// `sealed` = los hijos están todos aquí y no se pueden añadir más desde
/// fuera; por eso el compilador avisa si un switch olvida un caso.
/// Ventaja frente a varios booleanos: es imposible estar "cargando y con
/// error" a la vez.
sealed class LoadState<T> {
  const LoadState();
}

/// Todavía no se ha pedido nada.
final class LoadIdle<T> extends LoadState<T> {
  const LoadIdle();
}

/// Petición en marcha: la vista pinta una rueda de carga.
final class LoadInProgress<T> extends LoadState<T> {
  const LoadInProgress();
}

/// Cargado: lleva los datos dentro.
final class LoadSuccess<T> extends LoadState<T> {
  const LoadSuccess(this.data);

  final T data;
}

/// Falló: lleva el error dentro (normalmente un PokeApiException),
/// y la vista lo traduce a un mensaje en español.
final class LoadFailure<T> extends LoadState<T> {
  const LoadFailure(this.error);

  final Object error;
}
