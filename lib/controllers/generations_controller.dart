import 'package:flutter/foundation.dart';

import '../models/load_state.dart';
import '../models/named_resource.dart';
import '../services/poke_api_exception.dart';
import '../services/pokemon_repository.dart';

/// State for the generations list screen.
///
/// The list is small and never paginated, so the whole screen is a single
/// [LoadState].
class GenerationsController extends ChangeNotifier {
  GenerationsController({required this._repository});

  final PokemonRepository _repository;

  LoadState<List<NamedResource>> _state = const LoadIdle();
  bool _disposed = false;

  LoadState<List<NamedResource>> get state => _state;

  /// Loads the list once. No-op while a load is running or after it succeeded.
  Future<void> load() async {
    if (_state case LoadInProgress() || LoadSuccess()) return;
    await _load();
  }

  /// Retries after a failure.
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
