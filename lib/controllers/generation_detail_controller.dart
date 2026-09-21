import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/generation.dart';
import '../models/pokemon.dart';
import '../services/poke_api_exception.dart';
import '../services/pokemon_repository.dart';

/// State and pagination for one generation's Pokémon gallery.
///
/// First loads the generation (which yields its species ids, already sorted by
/// Pokédex number), then walks those ids in pages, fetching each page's
/// details in parallel — the same shape as [PokedexController], but bounded to
/// the generation instead of the whole national dex.
class GenerationDetailController extends ChangeNotifier {
  GenerationDetailController({
    required this._repository,
    required this.generationId,
    this.pageSize = 30,
  }) : assert(pageSize > 0, 'pageSize must be positive');

  final PokemonRepository _repository;

  /// Generation number being shown.
  final int generationId;

  final int pageSize;

  final List<Pokemon> _items = [];
  Generation? _generation;
  bool _isLoading = false;
  PokeApiException? _error;
  bool _disposed = false;

  UnmodifiableListView<Pokemon> get items => UnmodifiableListView(_items);

  /// The generation, known after the first successful load.
  Generation? get generation => _generation;

  /// How many Pokémon this generation has, or null before the first load.
  int? get total => _generation?.speciesIds.length;

  bool get isLoading => _isLoading;

  /// Error from the last load attempt; cleared when a new attempt starts.
  PokeApiException? get error => _error;

  bool get hasMore {
    final generation = _generation;
    return generation == null || _items.length < generation.speciesIds.length;
  }

  /// Nothing to show yet and a load is in progress: views render skeletons.
  bool get isInitialLoading => _isLoading && _items.isEmpty;

  /// Nothing to show and the load failed: views render a full-screen error.
  bool get hasInitialError => _error != null && _items.isEmpty;

  /// Loads the first page. No-op if data is already present or loading.
  Future<void> loadInitial() async {
    if (_items.isNotEmpty) return;
    await _loadNextPage();
  }

  /// Loads the next page when scrolling. Does not auto-retry after an error,
  /// so a failing network cannot cause a request loop; use [retry].
  Future<void> loadMore() async {
    if (_error != null) return;
    await _loadNextPage();
  }

  /// Retries the page that failed.
  Future<void> retry() => _loadNextPage();

  Future<void> _loadNextPage() async {
    if (_isLoading || !hasMore) return;

    _isLoading = true;
    _error = null;
    _notify();

    try {
      final generation =
          _generation ??= await _repository.getGeneration(generationId);
      final ids = generation.speciesIds;
      final first = _items.length;
      final last = min(first + pageSize, ids.length);
      final page = await Future.wait([
        for (var i = first; i < last; i++) _repository.getPokemon(ids[i]),
      ]);
      _items.addAll(page);
    } on PokeApiException catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
