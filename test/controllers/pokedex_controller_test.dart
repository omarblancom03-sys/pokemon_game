import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/pokedex_controller.dart';
import 'package:pokemon_game/services/poke_api_exception.dart';

import '../fakes/fake_pokemon_repository.dart';

void main() {
  late FakePokemonRepository repository;
  late PokedexController controller;
  late int notifications;

  setUp(() {
    repository = FakePokemonRepository(speciesCount: 25);
    controller = PokedexController(repository: repository, pageSize: 10);
    notifications = 0;
    controller.addListener(() => notifications++);
  });

  tearDown(() => controller.dispose());

  test('starts empty and not loading', () {
    expect(controller.items, isEmpty);
    expect(controller.isLoading, isFalse);
    expect(controller.hasMore, isTrue);
    expect(controller.total, isNull);
  });

  test('loadInitial exposes loading, then the first page', () async {
    final future = controller.loadInitial();
    expect(controller.isInitialLoading, isTrue);

    await future;

    expect(controller.isLoading, isFalse);
    expect(controller.total, 25);
    expect(controller.items.map((p) => p.id), List.generate(10, (i) => i + 1));
    expect(notifications, 2);
  });

  test('loadInitial is a no-op once data is loaded', () async {
    await controller.loadInitial();
    await controller.loadInitial();

    expect(repository.requestedIds, hasLength(10));
  });

  test('loadMore appends pages and stops at the species count', () async {
    await controller.loadInitial();
    await controller.loadMore();
    await controller.loadMore();

    expect(controller.items, hasLength(25));
    expect(controller.items.last.id, 25);
    expect(controller.hasMore, isFalse);

    await controller.loadMore();
    expect(repository.requestedIds, hasLength(25));
    expect(repository.speciesCountCalls, 1);
  });

  test('concurrent loadMore calls fetch a page only once', () async {
    await controller.loadInitial();
    repository.gate = Completer<void>();

    final first = controller.loadMore();
    final second = controller.loadMore();
    repository.gate!.complete();
    await Future.wait([first, second]);

    expect(controller.items, hasLength(20));
    expect(repository.requestedIds, hasLength(20));
  });

  test('initial failure exposes the error with no items', () async {
    repository.failNext = const PokeApiNetworkException('offline');

    await controller.loadInitial();

    expect(controller.hasInitialError, isTrue);
    expect(controller.error, isA<PokeApiNetworkException>());
    expect(controller.isLoading, isFalse);
  });

  test('retry after an initial failure loads the first page', () async {
    repository.failNext = const PokeApiNetworkException('offline');
    await controller.loadInitial();

    await controller.retry();

    expect(controller.error, isNull);
    expect(controller.items, hasLength(10));
  });

  test('loadMore failure keeps items and blocks auto-loading', () async {
    await controller.loadInitial();
    repository.failNext = PokeApiServerException(500, Uri.parse('x'));

    await controller.loadMore();
    expect(controller.items, hasLength(10));
    expect(controller.error, isA<PokeApiServerException>());
    expect(controller.hasInitialError, isFalse);

    final requestsBefore = repository.requestedIds.length;
    await controller.loadMore();
    expect(repository.requestedIds, hasLength(requestsBefore));

    await controller.retry();
    expect(controller.error, isNull);
    expect(controller.items, hasLength(20));
  });

  test('does not notify after dispose', () async {
    repository.gate = Completer<void>();
    final future = controller.loadInitial();
    await Future<void>.delayed(Duration.zero);

    controller.dispose();
    repository.gate!.complete();

    await expectLater(future, completes);
    // Recreate so tearDown can dispose safely.
    controller = PokedexController(repository: repository);
  });
}
