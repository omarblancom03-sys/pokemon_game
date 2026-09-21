import 'dart:math';

import '../models/pokemon.dart';
import 'poke_api_exception.dart';
import 'pokemon_repository.dart';

/// Picks a uniformly random Pokémon among all species.
///
/// Uses the species count (contiguous ids `1..count`) rather than the
/// `/pokemon` count, which includes alternate forms with ids ≥ 10001.
class RandomPokemonPicker {
  RandomPokemonPicker({required this._repository, Random? random})
    : _random = random ?? Random();

  final PokemonRepository _repository;
  final Random _random;

  /// Resolves the real species count, draws an id and fetches that Pokémon.
  /// Throws `PokeApiException` on failure.
  Future<Pokemon> pick() async {
    final count = await _repository.getSpeciesCount();
    return _repository.getPokemon(pickId(count));
  }

  /// Uniform id in `[1, count]`.
  int pickId(int count) {
    if (count < 1) {
      throw PokeApiParseException('Species count must be ≥ 1, got $count');
    }
    return _random.nextInt(count) + 1;
  }
}
