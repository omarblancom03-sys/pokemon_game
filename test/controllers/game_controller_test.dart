// PRUEBAS del controlador del juego: el flujo feliz del encuentro, que
// ignora humos mientras hay uno en marcha (doble disparo), el fallo de red
// con reintento y cancelación, y que un handler que lanza excepción nunca
// deja el juego congelado.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/game_controller.dart';
import 'package:pokemon_game/models/pokemon.dart';
import 'package:pokemon_game/services/poke_api_exception.dart';
import 'package:pokemon_game/services/random_pokemon_picker.dart';

import '../fakes/fake_pokemon_repository.dart';

/// Completes only when the test decides, to observe the paused state.
class _ControlledHandler implements EncounterHandler {
  final received = <Pokemon>[];
  Completer<EncounterOutcome> completer = Completer();
  Object? throwError;

  @override
  Future<EncounterOutcome> handleEncounter(Pokemon pokemon) async {
    received.add(pokemon);
    if (throwError != null) throw throwError!;
    return completer.future;
  }
}

void main() {
  late FakePokemonRepository repository;
  late _ControlledHandler handler;
  late GameController controller;
  late List<String> consumed;

  setUp(() {
    repository = FakePokemonRepository(speciesCount: 151);
    handler = _ControlledHandler();
    controller = GameController(
      picker: RandomPokemonPicker(repository: repository, random: Random(1)),
      encounterHandler: handler,
    );
    consumed = [];
    controller.smokeConsumed.listen(consumed.add);
  });

  tearDown(() => controller.dispose());

  test('starts free roaming', () {
    expect(controller.state, isA<EncounterNone>());
    expect(controller.isPaused, isFalse);
  });

  test('happy path: resolving → active → handler → resume', () async {
    final emitted = <Pokemon>[];
    controller.encounters.listen(emitted.add);

    final flow = controller.onSmokeReached('smoke-a');
    expect(controller.state, isA<EncounterResolving>());
    expect(controller.isPaused, isTrue);

    await pumpEventQueue();
    final active = controller.state as EncounterActive;
    expect(active.smokeId, 'smoke-a');
    expect(active.pokemon.id, inInclusiveRange(1, 151));
    expect(handler.received, [active.pokemon]);
    expect(emitted, [active.pokemon]);
    expect(controller.isPaused, isTrue, reason: 'paused while handler runs');
    expect(consumed, isEmpty);

    handler.completer.complete(EncounterOutcome.caught);
    await flow;
    await pumpEventQueue();

    expect(controller.state, isA<EncounterNone>());
    expect(controller.lastOutcome, EncounterOutcome.caught);
    expect(consumed, ['smoke-a']);
  });

  test('ignores smokes reached while an encounter is running', () async {
    unawaited(controller.onSmokeReached('smoke-a'));
    await controller.onSmokeReached('smoke-b');
    await pumpEventQueue();

    expect(handler.received, hasLength(1));
    expect((controller.state as EncounterActive).smokeId, 'smoke-a');

    handler.completer.complete(EncounterOutcome.fled);
  });

  test('fetch failure exposes EncounterFailed and keeps the smoke', () async {
    repository.failNext = const PokeApiNetworkException('offline');

    await controller.onSmokeReached('smoke-a');

    final failed = controller.state as EncounterFailed;
    expect(failed.smokeId, 'smoke-a');
    expect(failed.error, isA<PokeApiNetworkException>());
    expect(controller.isPaused, isTrue);
    expect(handler.received, isEmpty);
    expect(consumed, isEmpty);
  });

  test('retry after failure continues the same encounter', () async {
    repository.failNext = const PokeApiNetworkException('offline');
    await controller.onSmokeReached('smoke-a');

    handler.completer.complete(EncounterOutcome.fled);
    await controller.retry();
    await pumpEventQueue();

    expect(handler.received, hasLength(1));
    expect(consumed, ['smoke-a']);
    expect(controller.state, isA<EncounterNone>());
  });

  test('cancel after failure resumes without consuming the smoke', () async {
    repository.failNext = const PokeApiNetworkException('offline');
    await controller.onSmokeReached('smoke-a');

    controller.cancel();
    await pumpEventQueue();

    expect(controller.state, isA<EncounterNone>());
    expect(consumed, isEmpty);
  });

  test('a throwing handler never leaves the game frozen', () async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    handler.throwError = StateError('boom');

    await controller.onSmokeReached('smoke-a');
    await pumpEventQueue();

    expect(reported, hasLength(1));
    expect(controller.state, isA<EncounterNone>());
    expect(controller.lastOutcome, EncounterOutcome.fled);
    expect(consumed, ['smoke-a']);
  });
}
