import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/pokemon.dart';
import '../services/poke_api_exception.dart';
import '../services/random_pokemon_picker.dart';
import 'encounter/encounter_handler.dart';
import 'encounter/encounter_state.dart';

// export: quien importe este archivo obtiene también los estados y el
// contrato, sin tener que importarlos por separado.
export 'encounter/encounter_handler.dart';
export 'encounter/encounter_state.dart';

/// CONTROLADOR del juego: orquesta el encuentro completo
/// (humo tocado → Pokémon al azar → captura → reanudar).
///
/// No sabe nada de Flame ni de widgets: el juego le avisa con
/// [onSmokeReached] y reacciona a [isPaused] y al stream [smokeConsumed].
class GameController extends ChangeNotifier {
  GameController({required this._picker, required this._encounterHandler});

  final RandomPokemonPicker _picker;
  final EncounterHandler _encounterHandler;

  // Streams "broadcast": admiten varios oyentes a la vez.
  final _encounters = StreamController<Pokemon>.broadcast();
  final _smokeConsumed = StreamController<String>.broadcast();

  EncounterState _state = const EncounterNone();
  EncounterOutcome? _lastOutcome;
  bool _disposed = false;

  EncounterState get state => _state;

  /// True mientras haya un encuentro en marcha: el juego debe congelar la
  /// entrada del jugador.
  bool get isPaused => _state is! EncounterNone;

  /// Resultado del último encuentro terminado (capturado o huido).
  EncounterOutcome? get lastOutcome => _lastOutcome;

  /// Emite cada Pokémon justo antes de lanzar el handler (para oyentes
  /// pasivos; la captura en sí usa el EncounterHandler).
  Stream<Pokemon> get encounters => _encounters.stream;

  /// Emite el id del humo ya consumido; el juego lo borra del mapa.
  Stream<String> get smokeConsumed => _smokeConsumed.stream;

  /// Lo llama el juego cuando Ash toca un humo.
  Future<void> onSmokeReached(String smokeId) async {
    // GUARDA CONTRA DOBLE DISPARO: si ya hay un encuentro, se ignora.
    if (isPaused) return;
    await _resolve(smokeId);
  }

  /// Vuelve a intentar la descarga tras un EncounterFailed (mismo humo).
  Future<void> retry() async {
    final current = _state;
    if (current is EncounterFailed) await _resolve(current.smokeId);
  }

  /// Abandona un encuentro fallido: el juego se reanuda y el humo se queda.
  void cancel() {
    if (_state is EncounterFailed) _setState(const EncounterNone());
  }

  /// El flujo completo del encuentro, paso a paso.
  Future<void> _resolve(String smokeId) async {
    // 1) Pausa + overlay de "cargando".
    _setState(EncounterResolving(smokeId));

    final Pokemon pokemon;
    try {
      // 2) Pokémon al azar (esto es lo que tarda: va a PokeAPI).
      pokemon = await _picker.pick();
    } on PokeApiException catch (e) {
      // Si falla: overlay con Reintentar / Cancelar. El humo NO se consume.
      _setState(EncounterFailed(smokeId, e));
      return;
    }
    if (_disposed) return; // el usuario salió mientras se descargaba

    // 3) Ya sabemos quién aparece.
    _setState(EncounterActive(smokeId, pokemon));
    _encounters.add(pokemon);

    EncounterOutcome outcome;
    try {
      // 4) La captura (la implementa otra persona). El juego sigue pausado
      // hasta que este await termine.
      outcome = await _encounterHandler.handleEncounter(pokemon);
    } catch (error, stack) {
      // Si esa implementación revienta, se registra y se da por huido:
      // el juego nunca se queda congelado.
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

    // 5) y 6) El humo se consume y el juego se reanuda.
    _lastOutcome = outcome;
    _smokeConsumed.add(smokeId);
    _setState(const EncounterNone());
  }

  // Cambia el estado y avisa a la pantalla (si sigue viva).
  void _setState(EncounterState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    // Cerrar los streams al salir evita fugas de memoria.
    _disposed = true;
    unawaited(_encounters.close());
    unawaited(_smokeConsumed.close());
    super.dispose();
  }
}
