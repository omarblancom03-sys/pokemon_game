// PRUEBAS del sorteo: que el id siempre cae entre 1 y count (probado con
// muchas semillas), que se alcanzan los extremos, que un count inválido
// lanza excepción y que los errores del repositorio se propagan.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/models/generation.dart';
import 'package:pokemon_game/models/named_resource.dart';
import 'package:pokemon_game/models/paged_result.dart';
import 'package:pokemon_game/models/pokemon.dart';
import 'package:pokemon_game/models/pokemon_type.dart';
import 'package:pokemon_game/services/poke_api_exception.dart';
import 'package:pokemon_game/services/pokemon_repository.dart';
import 'package:pokemon_game/services/random_pokemon_picker.dart';

class _FakeRepository implements PokemonRepository {
  _FakeRepository({this.count = 1025, this.countError});

  final int count;
  final Object? countError;
  final requestedIds = <int>[];

  @override
  Future<int> getSpeciesCount() async {
    if (countError != null) throw countError!;
    return count;
  }

  @override
  Future<int> getCaptureRate(int id) => throw UnimplementedError();

  @override
  Future<Pokemon> getPokemon(int id) async {
    requestedIds.add(id);
    return Pokemon(
      id: id,
      name: 'p$id',
      types: const [PokemonType.normal],
      imageUrl: null,
      height: 1,
      weight: 1,
    );
  }

  @override
  Future<PagedResult<NamedResource>> getPokemonPage({
    required int offset,
    required int limit,
  }) => throw UnimplementedError();

  @override
  Future<PagedResult<NamedResource>> getGenerations() =>
      throw UnimplementedError();

  @override
  Future<Generation> getGeneration(int id) => throw UnimplementedError();
}

/// Returns a fixed value so the id mapping can be asserted exactly.
class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final int value;
  int? lastMax;

  @override
  int nextInt(int max) {
    lastMax = max;
    return value;
  }

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

void main() {
  test('draws from [0, count) and maps to id = value + 1', () async {
    final repository = _FakeRepository(count: 1025);
    final random = _FixedRandom(24);
    final picker = RandomPokemonPicker(repository: repository, random: random);

    final pokemon = await picker.pick();

    expect(random.lastMax, 1025);
    expect(pokemon.id, 25);
    expect(repository.requestedIds, [25]);
  });

  test('lowest and highest draws map to 1 and count', () {
    final repository = _FakeRepository();

    expect(
      RandomPokemonPicker(
        repository: repository,
        random: _FixedRandom(0),
      ).pickId(1025),
      1,
    );
    expect(
      RandomPokemonPicker(
        repository: repository,
        random: _FixedRandom(1024),
      ).pickId(1025),
      1025,
    );
  });

  test('ids always fall within [1, count] across many seeds', () {
    for (var seed = 0; seed < 200; seed++) {
      final picker = RandomPokemonPicker(
        repository: _FakeRepository(),
        random: Random(seed),
      );
      for (var i = 0; i < 50; i++) {
        expect(picker.pickId(10), inInclusiveRange(1, 10));
      }
    }
  });

  test('covers the whole range (all ids reachable)', () {
    final picker = RandomPokemonPicker(
      repository: _FakeRepository(),
      random: Random(42),
    );
    final seen = {for (var i = 0; i < 2000; i++) picker.pickId(10)};

    expect(seen, {for (var id = 1; id <= 10; id++) id});
  });

  test('rejects a non-positive count', () {
    final picker = RandomPokemonPicker(repository: _FakeRepository());

    expect(() => picker.pickId(0), throwsA(isA<PokeApiParseException>()));
  });

  test('propagates repository errors without fetching a Pokémon', () async {
    final repository = _FakeRepository(
      countError: const PokeApiNetworkException('offline'),
    );
    final picker = RandomPokemonPicker(repository: repository);

    await expectLater(picker.pick(), throwsA(isA<PokeApiNetworkException>()));
    expect(repository.requestedIds, isEmpty);
  });
}
