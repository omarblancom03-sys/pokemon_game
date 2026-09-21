import 'dart:math';

import '../models/pokemon.dart';
import 'poke_api_exception.dart';
import 'pokemon_repository.dart';

/// SERVICIO: elige un Pokémon al azar entre todas las especies.
///
/// Usa el total de especies (ids contiguos 1..count) y no el de `/pokemon`,
/// que incluye formas alternativas con ids ≥ 10001 y daría 404.
class RandomPokemonPicker {
  /// El generador aleatorio se puede inyectar: en los tests se pasa uno
  /// controlado y así el resultado es comprobable.
  RandomPokemonPicker({required this._repository, Random? random})
    : _random = random ?? Random();

  final PokemonRepository _repository;
  final Random _random;

  /// Pide el total de especies, sortea un id y trae ese Pokémon.
  /// Lanza PokeApiException si algo falla.
  Future<Pokemon> pick() async {
    final count = await _repository.getSpeciesCount();
    return _repository.getPokemon(pickId(count));
  }

  /// Número al azar en el rango [1, count].
  /// nextInt(count) da de 0 a count-1, por eso el +1 (no existe el nº 0).
  int pickId(int count) {
    if (count < 1) {
      throw PokeApiParseException('Species count must be ≥ 1, got $count');
    }
    return _random.nextInt(count) + 1;
  }
}
