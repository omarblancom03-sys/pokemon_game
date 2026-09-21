// PRUEBAS de la caché: que solo se hace una petición por id, que dos
// peticiones simultáneas comparten la misma llamada, que los errores NO se
// cachean y que clear() obliga a pedir de nuevo. Cuenta las peticiones
// reales interceptando el cliente HTTP.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokemon_game/services/poke_api_exception.dart';
import 'package:pokemon_game/services/poke_api_service.dart';
import 'package:pokemon_game/services/pokemon_repository.dart';

import '../fixtures/fixture_loader.dart';

void main() {
  late List<Uri> requested;
  late int failuresLeft;
  late CachedPokemonRepository repository;

  setUp(() {
    requested = [];
    failuresLeft = 0;
    final client = MockClient((request) async {
      requested.add(request.url);
      if (failuresLeft > 0) {
        failuresLeft--;
        return http.Response('boom', 500);
      }
      final path = request.url.path;
      final body = switch (path) {
        '/api/v2/pokemon-species' => '{"count": 1025}',
        '/api/v2/pokemon' => fixtureText('pokemon_page.json'),
        _ => fixtureText('bulbasaur.json'),
      };
      return http.Response(body, 200);
    });
    repository = CachedPokemonRepository(
      service: PokeApiService(client: client),
    );
  });

  test('getPokemon hits the network once per id', () async {
    final first = await repository.getPokemon(1);
    final second = await repository.getPokemon(1);

    expect(second, first);
    expect(requested, hasLength(1));
  });

  test('concurrent requests for the same id share one call', () async {
    await Future.wait([repository.getPokemon(1), repository.getPokemon(1)]);

    expect(requested, hasLength(1));
  });

  test('different ids are fetched separately', () async {
    await repository.getPokemon(1);
    await repository.getPokemon(2);

    expect(requested, hasLength(2));
  });

  test('pages are cached by (offset, limit)', () async {
    await repository.getPokemonPage(offset: 0, limit: 20);
    await repository.getPokemonPage(offset: 0, limit: 20);
    await repository.getPokemonPage(offset: 20, limit: 20);

    expect(requested, hasLength(2));
  });

  test('species count is requested only once', () async {
    expect(await repository.getSpeciesCount(), 1025);
    expect(await repository.getSpeciesCount(), 1025);

    expect(requested, hasLength(1));
  });

  test('failures propagate and are not cached', () async {
    failuresLeft = 1;

    await expectLater(
      repository.getPokemon(1),
      throwsA(isA<PokeApiServerException>()),
    );
    final retry = await repository.getPokemon(1);

    expect(retry.id, 1);
    expect(requested, hasLength(2));
  });

  test('clear forces a new request', () async {
    await repository.getSpeciesCount();
    repository.clear();
    await repository.getSpeciesCount();

    expect(requested, hasLength(2));
  });
}
