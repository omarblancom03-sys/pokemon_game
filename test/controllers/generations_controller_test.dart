import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/generations_controller.dart';
import 'package:pokemon_game/models/load_state.dart';
import 'package:pokemon_game/models/named_resource.dart';
import 'package:pokemon_game/services/poke_api_exception.dart';

import '../fakes/fake_pokemon_repository.dart';

void main() {
  late FakePokemonRepository repository;
  late GenerationsController controller;

  setUp(() {
    repository = FakePokemonRepository();
    controller = GenerationsController(repository: repository);
  });

  tearDown(() => controller.dispose());

  test('starts idle', () {
    expect(controller.state, isA<LoadIdle<List<NamedResource>>>());
  });

  test('load() publishes the generations', () async {
    await controller.load();

    final state = controller.state;
    expect(state, isA<LoadSuccess<List<NamedResource>>>());
    expect(
      (state as LoadSuccess<List<NamedResource>>).data.map((g) => g.name),
      ['generation-i', 'generation-ii'],
    );
    expect(repository.generationsCalls, 1);
  });

  test('load() is a no-op once the list is loaded', () async {
    await controller.load();
    await controller.load();

    expect(repository.generationsCalls, 1);
  });

  test('notifies listeners while loading and when done', () async {
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.load();

    // One for LoadInProgress, one for the result.
    expect(notifications, 2);
  });

  test('a failure becomes LoadFailure carrying the error', () async {
    repository.failNext = const PokeApiNetworkException('offline');

    await controller.load();

    final state = controller.state;
    expect(state, isA<LoadFailure<List<NamedResource>>>());
    expect(
      (state as LoadFailure<List<NamedResource>>).error,
      isA<PokeApiNetworkException>(),
    );
  });

  test('retry() loads again after a failure', () async {
    repository.failNext = const PokeApiNetworkException('offline');
    await controller.load();

    await controller.retry();

    expect(controller.state, isA<LoadSuccess<List<NamedResource>>>());
    expect(repository.generationsCalls, 2);
  });

  test('does not notify after dispose', () async {
    final disposed = GenerationsController(repository: repository)..dispose();

    // Would throw if the controller notified listeners after disposal.
    await disposed.load();
  });
}
