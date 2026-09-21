import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/generation.dart';
import '../models/pokemon.dart';
import '../services/poke_api_exception.dart';
import '../services/pokemon_repository.dart';

/// CONTROLADOR de la galería de UNA generación (ventana 2).
///
/// Funciona igual que PokedexController, pero en vez de recorrer toda la
/// Pokédex recorre los ids de esa generación: primero descarga la
/// generación (que ya trae sus especies ordenadas por número) y luego pide
/// esos ids de 30 en 30, en paralelo.
class GenerationDetailController extends ChangeNotifier {
  GenerationDetailController({
    required this._repository,
    required this.generationId,
    this.pageSize = 30,
  }) : assert(pageSize > 0, 'pageSize must be positive');

  final PokemonRepository _repository;

  /// Número de generación que se está mostrando.
  final int generationId;

  final int pageSize;

  final List<Pokemon> _items = [];
  Generation? _generation;
  bool _isLoading = false;
  PokeApiException? _error;
  bool _disposed = false;

  /// Lista de solo lectura para la vista.
  UnmodifiableListView<Pokemon> get items => UnmodifiableListView(_items);

  /// La generación, conocida tras la primera carga correcta.
  Generation? get generation => _generation;

  /// Cuántos Pokémon tiene esta generación (null antes de cargar).
  int? get total => _generation?.speciesIds.length;

  bool get isLoading => _isLoading;

  /// Error del último intento; se limpia al empezar uno nuevo.
  PokeApiException? get error => _error;

  bool get hasMore {
    final generation = _generation;
    return generation == null || _items.length < generation.speciesIds.length;
  }

  /// Nada que mostrar y cargando → esqueletos.
  bool get isInitialLoading => _isLoading && _items.isEmpty;

  /// Nada que mostrar y con error → error a pantalla completa.
  bool get hasInitialError => _error != null && _items.isEmpty;

  /// Primera página. No hace nada si ya hay datos o si ya está cargando.
  Future<void> loadInitial() async {
    if (_items.isNotEmpty) return;
    await _loadNextPage();
  }

  /// Página siguiente al hacer scroll. Tras un error no reintenta solo,
  /// para no entrar en un bucle de peticiones; para eso está retry().
  Future<void> loadMore() async {
    if (_error != null) return;
    await _loadNextPage();
  }

  /// Reintenta la página que falló.
  Future<void> retry() => _loadNextPage();

  Future<void> _loadNextPage() async {
    if (_isLoading || !hasMore) return;

    _isLoading = true;
    _error = null;
    _notify();

    try {
      // ??= la generación se descarga UNA sola vez, aunque haya 5 páginas.
      final generation =
          _generation ??= await _repository.getGeneration(generationId);
      final ids = generation.speciesIds; // ya ordenados por nº de Pokédex
      final first = _items.length;
      final last = min(first + pageSize, ids.length);
      // Los 30 de la página, en paralelo.
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
