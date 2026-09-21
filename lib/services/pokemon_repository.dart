import 'dart:async';

import '../models/generation.dart';
import '../models/named_resource.dart';
import '../models/paged_result.dart';
import '../models/pokemon.dart';
import 'poke_api_service.dart';

/// CONTRATO de acceso a los datos. Los controladores dependen de esta
/// interfaz, NUNCA del servicio HTTP directamente: por eso en los tests se
/// les puede pasar un repositorio falso y probarlos sin internet.
abstract interface class PokemonRepository {
  Future<Pokemon> getPokemon(int id);

  Future<PagedResult<NamedResource>> getPokemonPage({
    required int offset,
    required int limit,
  });

  /// Número de especies; los ids de 1 a count son todos válidos.
  Future<int> getSpeciesCount();

  /// Todas las generaciones, como referencias `{name, url}`.
  Future<PagedResult<NamedResource>> getGenerations();

  /// Una generación concreta, con las especies que le pertenecen.
  Future<Generation> getGeneration(int id);
}

/// Caché en memoria por delante del servicio (patrón DECORADOR: cumple la
/// misma interfaz y añade comportamiento).
///
/// Clave: se guardan los Future (las promesas), no los valores. Así, si dos
/// partes de la app piden el mismo Pokémon a la vez, se hace UNA sola
/// petición HTTP y ambas esperan la misma respuesta.
class CachedPokemonRepository implements PokemonRepository {
  CachedPokemonRepository({required this._service});

  final PokeApiService _service;

  // Una caché por tipo de dato.
  final _pokemon = <int, Future<Pokemon>>{};
  final _pages = <(int, int), Future<PagedResult<NamedResource>>>{};
  final _speciesCount = <void, Future<int>>{};
  final _generations = <void, Future<PagedResult<NamedResource>>>{};
  final _generation = <int, Future<Generation>>{};

  @override
  Future<Pokemon> getPokemon(int id) =>
      _memoize(_pokemon, id, () => _service.fetchPokemon(id));

  @override
  Future<PagedResult<NamedResource>> getPokemonPage({
    required int offset,
    required int limit,
  }) {
    // La clave de la caché es la pareja (offset, limit).
    final key = (offset, limit);
    return _memoize(
      _pages,
      key,
      () => _service.fetchPokemonPage(offset: offset, limit: limit),
    );
  }

  @override
  Future<int> getSpeciesCount() =>
      _memoize(_speciesCount, null, _service.fetchSpeciesCount);

  @override
  Future<PagedResult<NamedResource>> getGenerations() =>
      _memoize(_generations, null, _service.fetchGenerations);

  @override
  Future<Generation> getGeneration(int id) =>
      _memoize(_generation, id, () => _service.fetchGeneration(id));

  /// Vacía la caché entera (pensado para un "deslizar para refrescar").
  void clear() {
    _pokemon.clear();
    _pages.clear();
    _speciesCount.clear();
    _generations.clear();
    _generation.clear();
  }

  /// Memoizar = "si ya lo pedí, reutiliza; si no, pídelo y guárdalo".
  Future<T> _memoize<K, T>(
    Map<K, Future<T>> cache,
    K key,
    Future<T> Function() load,
  ) {
    final cached = cache[key];
    if (cached != null) return cached; // ya está (o está en camino)

    final future = load();
    cache[key] = future;
    // Si la petición falla, se saca de la caché para poder reintentarla;
    // si no, un fallo momentáneo de red quedaría guardado para siempre.
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _) {
          // identical: solo borra si sigue siendo ESTA misma promesa.
          if (identical(cache[key], future)) cache.remove(key);
        },
      ),
    );
    return future;
  }
}
