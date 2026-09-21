import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/pokemon.dart';
import '../services/poke_api_exception.dart';
import '../services/pokemon_repository.dart';

/// CONTROLADOR de la Pokédex: estado y paginación de la galería.
///
/// Es un ChangeNotifier: cuando algo cambia llama a notifyListeners() y la
/// pantalla se redibuja. No conoce ningún widget.
///
/// Las páginas se forman con ids contiguos (1..total de especies) y se piden
/// en paralelo; así se saltan las formas alternativas (ids ≥ 10001).
class PokedexController extends ChangeNotifier {
  PokedexController({required this._repository, this.pageSize = 30})
    : assert(pageSize > 0);

  // Depende de la INTERFAZ, no del servicio HTTP: por eso es testeable.
  final PokemonRepository _repository;
  final int pageSize;

  // Estado interno (privado: el guion bajo significa "solo en este archivo").
  final List<Pokemon> _items = [];
  int? _total;
  bool _isLoading = false;
  PokeApiException? _error;
  bool _disposed = false;

  /// Lista de solo lectura: la vista no puede añadir ni quitar elementos.
  UnmodifiableListView<Pokemon> get items => UnmodifiableListView(_items);

  /// Total de especies; se sabe tras la primera carga correcta.
  int? get total => _total;

  bool get isLoading => _isLoading;

  /// Error del último intento; se limpia al empezar uno nuevo.
  PokeApiException? get error => _error;

  bool get hasMore => _total == null || _items.length < _total!;

  /// No hay nada que mostrar y está cargando → la vista pinta esqueletos.
  bool get isInitialLoading => _isLoading && _items.isEmpty;

  /// No hay nada y falló → la vista pinta el error a pantalla completa.
  bool get hasInitialError => _error != null && _items.isEmpty;

  /// Primera página. No hace nada si ya hay datos (así volver a entrar en la
  /// pantalla no recarga todo).
  Future<void> loadInitial() async {
    if (_items.isNotEmpty) return;
    await _loadNextPage();
  }

  /// Página siguiente al hacer scroll. Tras un error NO reintenta solo: si
  /// no, con la red caída el scroll pediría sin parar. Para eso está retry().
  Future<void> loadMore() async {
    if (_error != null) return;
    await _loadNextPage();
  }

  /// Reintento explícito del usuario (botón "Reintentar").
  Future<void> retry() => _loadNextPage();

  Future<void> _loadNextPage() async {
    // Guardas: ni dos cargas a la vez, ni pedir más allá del total.
    if (_isLoading || !hasMore) return;

    _isLoading = true;
    _error = null;
    _notify(); // la vista pinta la rueda de carga

    try {
      // ??= pide el total solo la primera vez y luego lo reutiliza.
      final total = _total ??= await _repository.getSpeciesCount();
      final firstId = _items.length + 1;
      final lastId = min(firstId + pageSize - 1, total); // recorta la última
      // Future.wait: las 30 peticiones van EN PARALELO (una sola espera).
      final page = await Future.wait([
        for (var id = firstId; id <= lastId; id++) _repository.getPokemon(id),
      ]);
      _items.addAll(page);
    } on PokeApiException catch (e) {
      _error = e;
    } finally {
      // finally = pase lo que pase: la rueda nunca se queda girando.
      _isLoading = false;
      _notify();
    }
  }

  // Si la respuesta llega después de salir de la pantalla, avisar lanzaría
  // un error de Flutter; esta bandera lo evita.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
