// DOBLE DE PRUEBA: repositorio falso que devuelve Pokémon inventados al
// instante, sin internet. failNext fuerza un error en la siguiente llamada
// y el "gate" permite dejar una petición en el aire para comprobar qué se
// pinta MIENTRAS carga.

import 'dart:async';

import 'package:pokemon_game/models/generation.dart';
import 'package:pokemon_game/models/named_resource.dart';
import 'package:pokemon_game/models/paged_result.dart';
import 'package:pokemon_game/models/pokemon.dart';
import 'package:pokemon_game/models/pokemon_type.dart';
import 'package:pokemon_game/services/poke_api_exception.dart';
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

  /// Entries answered by [getGenerations].
  List<NamedResource> generations = const [
    NamedResource(
      name: 'generation-i',
      url: 'https://pokeapi.co/api/v2/generation/1/',
    ),
    NamedResource(
      name: 'generation-ii',
      url: 'https://pokeapi.co/api/v2/generation/2/',
    ),
  ];

  /// How many species each fake generation contains.
  int generationSize = 10;

  final requestedGenerationIds = <int>[];
  int generationsCalls = 0;

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

  /// Ratio de captura que devolverá getCaptureRate.
  int captureRate = 45;

  /// Si es true, getCaptureRate falla siempre (el resto funciona).
  bool failCaptureRate = false;

  @override
  Future<int> getCaptureRate(int id) async {
    await _maybeFail();
    if (failCaptureRate) throw PokeApiServerException(500, Uri());
    return captureRate;
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

  @override
  Future<PagedResult<NamedResource>> getGenerations() async {
    generationsCalls++;
    await _maybeFail();
    return PagedResult(
      count: generations.length,
      next: null,
      items: generations,
    );
  }

  @override
  Future<Generation> getGeneration(int id) async {
    requestedGenerationIds.add(id);
    await _maybeFail();
    return Generation(
      id: id,
      name: 'generation-$id',
      mainRegion: 'region-$id',
      species: [
        for (var i = 1; i <= generationSize; i++)
          NamedResource(
            name: 'poke-$i',
            url: 'https://pokeapi.co/api/v2/pokemon-species/$i/',
          ),
      ],
    );
  }
}
