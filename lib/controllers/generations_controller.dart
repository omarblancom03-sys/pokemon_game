import 'package:flutter/foundation.dart';

import '../models/load_state.dart';
import '../models/named_resource.dart';
import '../services/poke_api_exception.dart';
import '../services/pokemon_repository.dart';

/// CONTROLADOR de la pantalla de generaciones (ventana 1).
///
/// La lista es pequeña y cabe en una sola petición, así que toda la pantalla
/// se resume en un único [LoadState]: o idle, o cargando, o cargada, o error.
class GenerationsController extends ChangeNotifier {
  GenerationsController({required this._repository});

  final PokemonRepository _repository;

  LoadState<List<NamedResource>> _state = const LoadIdle();
  bool _disposed = false;

  LoadState<List<NamedResource>> get state => _state;

  /// Carga la lista una vez. Es idempotente: si ya está cargando o cargada,
  /// llamarlo otra vez no hace nada (no repite la petición).
  Future<void> load() async {
    if (_state case LoadInProgress() || LoadSuccess()) return;
    await _load();
  }

  /// Reintento tras un fallo (botón "Reintentar").
  Future<void> retry() => _load();

  Future<void> _load() async {
    _state = const LoadInProgress();
    _notify();

    try {
      final page = await _repository.getGenerations();
      _state = LoadSuccess(List.unmodifiable(page.items));
    } on PokeApiException catch (e) {
      _state = LoadFailure(e);
    }

    _notify();
  }

  // No avisar si la pantalla ya se destruyó.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
