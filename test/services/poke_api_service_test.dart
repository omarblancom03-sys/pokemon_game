import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokemon_game/models/pokemon_type.dart';
import 'package:pokemon_game/services/poke_api_exception.dart';
import 'package:pokemon_game/services/poke_api_service.dart';

import '../fixtures/fixture_loader.dart';

void main() {
  late List<http.Request> requests;

  PokeApiService serviceReturning(
    int statusCode,
    String body, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    requests = [];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        body,
        statusCode,
        headers: {'content-type': 'application/json'},
      );
    });
    return PokeApiService(client: client, timeout: timeout);
  }

  PokeApiService serviceWith(MockClientHandler handler) =>
      PokeApiService(client: MockClient(handler));

  group('fetchPokemon', () {
    test('GETs /pokemon/{id} and returns the parsed model', () async {
      final service = serviceReturning(200, fixtureText('bulbasaur.json'));

      final pokemon = await service.fetchPokemon(1);

      expect(requests.single.method, 'GET');
      expect(
        requests.single.url.toString(),
        'https://pokeapi.co/api/v2/pokemon/1',
      );
      expect(pokemon.name, 'bulbasaur');
      expect(pokemon.types.first, PokemonType.grass);
    });

    test('throws NotFound on 404', () {
      final service = serviceReturning(404, 'Not Found');

      expect(
        service.fetchPokemon(99999),
        throwsA(isA<PokeApiNotFoundException>()),
      );
    });

    test('throws Server with the status code on 5xx', () {
      final service = serviceReturning(503, 'down');

      expect(
        service.fetchPokemon(1),
        throwsA(
          isA<PokeApiServerException>().having(
            (e) => e.statusCode,
            'statusCode',
            503,
          ),
        ),
      );
    });

    test('throws Parse on invalid JSON', () {
      final service = serviceReturning(200, '<html>oops</html>');

      expect(service.fetchPokemon(1), throwsA(isA<PokeApiParseException>()));
    });

    test('throws Parse when JSON is not an object', () {
      final service = serviceReturning(200, '[1, 2]');

      expect(service.fetchPokemon(1), throwsA(isA<PokeApiParseException>()));
    });

    test('throws Parse when the object has the wrong shape', () {
      final service = serviceReturning(200, '{"id": 1}');

      expect(service.fetchPokemon(1), throwsA(isA<PokeApiParseException>()));
    });

    test('throws Network when the client fails', () {
      final service = serviceWith(
        (_) async => throw http.ClientException('offline'),
      );

      expect(service.fetchPokemon(1), throwsA(isA<PokeApiNetworkException>()));
    });

    test('throws Network on timeout', () {
      requests = [];
      final service = PokeApiService(
        client: MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 10),
      );

      expect(service.fetchPokemon(1), throwsA(isA<PokeApiNetworkException>()));
    });
  });

  group('fetchPokemonPage', () {
    test('sends offset and limit and parses the page', () async {
      final service = serviceReturning(200, fixtureText('pokemon_page.json'));

      final page = await service.fetchPokemonPage(offset: 40, limit: 20);

      final url = requests.single.url;
      expect(url.path, '/api/v2/pokemon');
      expect(url.queryParameters, {'offset': '40', 'limit': '20'});
      expect(page.count, 1302);
      expect(page.items, hasLength(2));
    });
  });

  group('fetchSpeciesCount', () {
    test('reads count from /pokemon-species', () async {
      final service = serviceReturning(
        200,
        '{"count": 1025, "next": null, "previous": null, "results": []}',
      );

      final count = await service.fetchSpeciesCount();

      expect(requests.single.url.path, '/api/v2/pokemon-species');
      expect(count, 1025);
    });

    test('throws Parse when count is missing', () {
      final service = serviceReturning(200, '{"results": []}');

      expect(
        service.fetchSpeciesCount(),
        throwsA(isA<PokeApiParseException>()),
      );
    });
  });
}
