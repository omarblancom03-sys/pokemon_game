import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/pokemon.dart';
import '../services/poke_api_exception.dart';
import '../services/pokemon_repository.dart';

/// State and pagination for the Pokédex gallery.
///
/// Pages are built from contiguous species ids (`1..speciesCount`), fetching
/// each page's details in parallel. This skips alternate forms (ids ≥ 10001)
/// that `/pokemon` lists after the national dex.
class PokedexController extends ChangeNotifier {
  PokedexController({required this._repository, this.pageSize = 30})
    : assert(pageSize > 0);

  final PokemonRepository _repository;
  final int pageSize;

  final List<Pokemon> _items = [];
  int? _total;
  bool _isLoading = false;
  PokeApiException? _error;
  bool _disposed = false;

  UnmodifiableListView<Pokemon> get items => UnmodifiableListView(_items);

  /// Total species, known after the first successful load.
  int? get total => _total;

  bool get isLoading => _isLoading;

  /// Error from the last load attempt; cleared when a new attempt starts.
  PokeApiException? get error => _error;

  bool get hasMore => _total == null || _items.length < _total!;

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
      final total = _total ??= await _repository.getSpeciesCount();
      final firstId = _items.length + 1;
      final lastId = min(firstId + pageSize - 1, total);
      final page = await Future.wait([
        for (var id = firstId; id <= lastId; id++) _repository.getPokemon(id),
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
