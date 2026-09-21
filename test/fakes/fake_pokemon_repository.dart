import 'dart:async';

import 'package:pokemon_game/models/named_resource.dart';
import 'package:pokemon_game/models/paged_result.dart';
import 'package:pokemon_game/models/pokemon.dart';
import 'package:pokemon_game/models/pokemon_type.dart';
import 'package:pokemon_game/services/pokemon_repository.dart';

Pokemon fakePokemon(int id) => Pokemon(
  id: id,
  name: 'poke-$id',
  types: const [PokemonType.fire],
  imageUrl: null,
  height: 1,
  weight: 1,
);

/// In-memory repository with controllable failures and optional gating.
class FakePokemonRepository implements PokemonRepository {
  FakePokemonRepository({this.speciesCount = 100});

  int speciesCount;

  /// Next `getSpeciesCount` / `getPokemon` calls throw this, once.
  Object? failNext;

  /// When set, `getPokemon` waits for it before answering.
  Completer<void>? gate;

  final requestedIds = <int>[];
  int speciesCountCalls = 0;

  Future<void> _maybeFail() async {
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
  }

  @override
  Future<int> getSpeciesCount() async {
    speciesCountCalls++;
    await _maybeFail();
    return speciesCount;
  }

  @override
  Future<Pokemon> getPokemon(int id) async {
    requestedIds.add(id);
    await _maybeFail();
    if (gate != null) await gate!.future;
    return fakePokemon(id);
  }

  @override
  Future<PagedResult<NamedResource>> getPokemonPage({
    required int offset,
    required int limit,
  }) => throw UnimplementedError();
}
