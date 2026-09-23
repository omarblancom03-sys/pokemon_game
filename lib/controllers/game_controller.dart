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
///
/// El mundo 3D usa el MISMO flujo con otras fuentes de encuentro: un
/// Pokémon visible ([onWildEncounter]) o un paso por la hierba alta
/// ([onGrassEncounter]). En todos los casos el "smokeId" es simplemente el
/// id de la fuente que disparó el encuentro.
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
  int _grassCount = 0;

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

  /// Lo llama el mundo 3D al tocar un Pokémon VISIBLE: ya se sabe cuál es,
  /// así que no hay nada que descargar y se pasa directo al encuentro.
  Future<void> onWildEncounter(String sourceId, Pokemon pokemon) async {
    if (isPaused) return; // misma guarda contra doble disparo
    await _run(sourceId, pokemon);
  }

  /// Encuentro al azar en la hierba alta: igual que un humo, pero con un
  /// id nuevo cada vez (no hay nada que borrar del mapa después).
  Future<void> onGrassEncounter() => onSmokeReached('grass-${_grassCount++}');

  /// Un Pokémon al azar para que aparezca en el mapa. Si falla la red
  /// devuelve null (el mundo lo reintentará) y NO cambia el estado.
  Future<Pokemon?> pickWildPokemon() async {
    try {
      return await _picker.pick();
    } on PokeApiException {
      return null;
    }
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
    await _run(smokeId, pokemon);
  }

  /// Del Pokémon ya conocido en adelante: encuentro, captura y reanudar.
  Future<void> _run(String smokeId, Pokemon pokemon) async {
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
