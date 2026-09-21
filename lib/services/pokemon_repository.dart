import 'dart:async';

import '../models/generation.dart';
import '../models/named_resource.dart';
import '../models/paged_result.dart';
import '../models/pokemon.dart';
import 'poke_api_service.dart';

/// Read access to Pokémon data. Controllers depend on this interface, never on
/// the HTTP service directly. Failures surface as `PokeApiException`.
abstract interface class PokemonRepository {
  Future<Pokemon> getPokemon(int id);

  Future<PagedResult<NamedResource>> getPokemonPage({
    required int offset,
    required int limit,
  });

  /// Number of species; ids in `[1, count]` are all valid for [getPokemon].
  Future<int> getSpeciesCount();

  /// Every generation as `{name, url}` references.
  Future<PagedResult<NamedResource>> getGenerations();

  /// One generation, including the species that belong to it.
  Future<Generation> getGeneration(int id);
}

/// In-memory cache in front of [PokeApiService].
///
/// Futures are cached (not values), so concurrent requests for the same key
/// share a single HTTP call. Failed lookups are evicted so they can be retried.
class CachedPokemonRepository implements PokemonRepository {
  CachedPokemonRepository({required this._service});

  final PokeApiService _service;
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

  /// Drops every cached entry (e.g. for a pull-to-refresh).
  void clear() {
    _pokemon.clear();
    _pages.clear();
    _speciesCount.clear();
    _generations.clear();
    _generation.clear();
  }

  Future<T> _memoize<K, T>(
    Map<K, Future<T>> cache,
    K key,
    Future<T> Function() load,
  ) {
    final cached = cache[key];
    if (cached != null) return cached;

    final future = load();
    cache[key] = future;
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(cache[key], future)) cache.remove(key);
        },
      ),
    );
    return future;
  }
}
