import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/pokemon.dart';
import '../services/poke_api_exception.dart';
import '../services/random_pokemon_picker.dart';
import 'encounter/encounter_handler.dart';
import 'encounter/encounter_state.dart';

export 'encounter/encounter_handler.dart';
export 'encounter/encounter_state.dart';

/// Orchestrates encounters: smoke reached → random Pokémon → handler → resume.
///
/// Independent of Flame and widgets: the game reports [onSmokeReached] and
/// reacts to [isPaused] and [smokeConsumed].
class GameController extends ChangeNotifier {
  GameController({required this._picker, required this._encounterHandler});

  final RandomPokemonPicker _picker;
  final EncounterHandler _encounterHandler;

  final _encounters = StreamController<Pokemon>.broadcast();
  final _smokeConsumed = StreamController<String>.broadcast();

  EncounterState _state = const EncounterNone();
  EncounterOutcome? _lastOutcome;
  bool _disposed = false;

  EncounterState get state => _state;

  /// True while any encounter is in progress; the game must freeze input.
  bool get isPaused => _state is! EncounterNone;

  /// Result of the most recently finished encounter.
  EncounterOutcome? get lastOutcome => _lastOutcome;

  /// Emits each resolved Pokémon right before the handler is invoked.
  /// For passive listeners; the capture flow itself uses [EncounterHandler].
  Stream<Pokemon> get encounters => _encounters.stream;

  /// Emits the id of a smoke whose encounter finished; the game removes it.
  Stream<String> get smokeConsumed => _smokeConsumed.stream;

  /// Called by the game when Ash touches a smoke. Ignored while another
  /// encounter is in progress (prevents double triggers).
  Future<void> onSmokeReached(String smokeId) async {
    if (isPaused) return;
    await _resolve(smokeId);
  }

  /// Retries fetching the Pokémon after [EncounterFailed].
  Future<void> retry() async {
    final current = _state;
    if (current is EncounterFailed) await _resolve(current.smokeId);
  }

  /// Abandons a failed encounter; the smoke stays on the map.
  void cancel() {
    if (_state is EncounterFailed) _setState(const EncounterNone());
  }

  Future<void> _resolve(String smokeId) async {
    _setState(EncounterResolving(smokeId));

    final Pokemon pokemon;
    try {
      pokemon = await _picker.pick();
    } on PokeApiException catch (e) {
      _setState(EncounterFailed(smokeId, e));
      return;
    }
    if (_disposed) return;

    _setState(EncounterActive(smokeId, pokemon));
    _encounters.add(pokemon);

    EncounterOutcome outcome;
    try {
      outcome = await _encounterHandler.handleEncounter(pokemon);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'GameController',
          context: ErrorDescription('while running the EncounterHandler'),
        ),
      );
      outcome = EncounterOutcome.fled;
    }
    if (_disposed) return;

    _lastOutcome = outcome;
    _smokeConsumed.add(smokeId);
    _setState(const EncounterNone());
  }

  void _setState(EncounterState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_encounters.close());
    unawaited(_smokeConsumed.close());
    super.dispose();
  }
}
