import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/generation_detail_controller.dart';
import 'package:pokemon_game/services/poke_api_exception.dart';

import '../fakes/fake_pokemon_repository.dart';

void main() {
  late FakePokemonRepository repository;
  late GenerationDetailController controller;

  setUp(() {
    repository = FakePokemonRepository()..generationSize = 10;
    controller = GenerationDetailController(
      repository: repository,
      generationId: 1,
      pageSize: 4,
    );
  });

  tearDown(() => controller.dispose());

  test('loadInitial fetches the generation and its first page', () async {
    await controller.loadInitial();

    expect(repository.requestedGenerationIds, [1]);
    expect(repository.requestedIds, [1, 2, 3, 4]);
    expect(controller.items.map((p) => p.id), [1, 2, 3, 4]);
    expect(controller.generation?.name, 'generation-1');
    expect(controller.total, 10);
    expect(controller.hasMore, isTrue);
  });

  test('loadInitial is a no-op once items are loaded', () async {
    await controller.loadInitial();
    await controller.loadInitial();

    expect(repository.requestedIds, [1, 2, 3, 4]);
  });

  test('loadMore appends the next page without duplicates', () async {
    await controller.loadInitial();
    await controller.loadMore();

    expect(controller.items.map((p) => p.id), [1, 2, 3, 4, 5, 6, 7, 8]);
  });

  test('stops when the generation is exhausted', () async {
    await controller.loadInitial();
    await controller.loadMore();
    await controller.loadMore();

    expect(controller.items, hasLength(10));
    expect(controller.hasMore, isFalse);

    // Nothing left to ask for.
    await controller.loadMore();
    expect(repository.requestedIds, hasLength(10));
  });

  test('fetches the generation only once across pages', () async {
    await controller.loadInitial();
    await controller.loadMore();

    expect(repository.requestedGenerationIds, [1]);
  });

  test('isInitialLoading is true while the first page is in flight', () async {
    final gate = Completer<void>();
    repository.gate = gate;

    final pending = controller.loadInitial();
    await Future<void>.delayed(Duration.zero);

    expect(controller.isInitialLoading, isTrue);
    expect(controller.items, isEmpty);

    gate.complete();
    await pending;

    expect(controller.isInitialLoading, isFalse);
    expect(controller.items, hasLength(4));
  });

  group('errors', () {
    test('a failed first load shows a full-screen error', () async {
      repository.failNext = const PokeApiNetworkException('offline');

      await controller.loadInitial();

      expect(controller.hasInitialError, isTrue);
      expect(controller.error, isA<PokeApiNetworkException>());
      expect(controller.items, isEmpty);
    });

    test('retry recovers after a failed first load', () async {
      repository.failNext = const PokeApiNetworkException('offline');
      await controller.loadInitial();

      await controller.retry();

      expect(controller.error, isNull);
      expect(controller.items.map((p) => p.id), [1, 2, 3, 4]);
    });

    test('loadMore does not auto-retry after a failure', () async {
      await controller.loadInitial();
      repository.failNext = const PokeApiNetworkException('offline');
      await controller.loadMore();

      final requestsAfterFailure = repository.requestedIds.length;
      await controller.loadMore();

      expect(controller.error, isA<PokeApiNetworkException>());
      expect(repository.requestedIds, hasLength(requestsAfterFailure));
    });
  });

  test('does not notify after dispose', () async {
    final disposed = GenerationDetailController(
      repository: repository,
      generationId: 1,
    )..dispose();

    // Would throw if the controller notified listeners after disposal.
    await disposed.loadInitial();
  });
}
