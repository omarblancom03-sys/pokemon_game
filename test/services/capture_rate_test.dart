// PRUEBAS del ratio de captura: el servicio pide /pokemon-species/{id} y
// lee capture_rate; un JSON sin ese campo es un error de parseo; y el
// repositorio lo pide una sola vez por especie.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokemon_game/services/poke_api_exception.dart';
import 'package:pokemon_game/services/poke_api_service.dart';
import 'package:pokemon_game/services/pokemon_repository.dart';

void main() {
  test('fetchCaptureRate reads capture_rate from the species', () async {
    final paths = <String>[];
    final service = PokeApiService(
      client: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(jsonEncode({'id': 25, 'capture_rate': 190}), 200);
      }),
    );

    expect(await service.fetchCaptureRate(25), 190);
    expect(paths.single, endsWith('/pokemon-species/25'));
  });

  test('a species without capture_rate is a parse error', () async {
    final service = PokeApiService(
      client: MockClient((_) async => http.Response('{"id": 1}', 200)),
    );
    await expectLater(
      service.fetchCaptureRate(1),
      throwsA(isA<PokeApiParseException>()),
    );
  });

  test('the repository asks once per species', () async {
    var calls = 0;
    final repo = CachedPokemonRepository(
      service: PokeApiService(
        client: MockClient((_) async {
          calls++;
          return http.Response('{"capture_rate": 3}', 200);
        }),
      ),
    );

    expect(await repo.getCaptureRate(150), 3);
    expect(await repo.getCaptureRate(150), 3);
    expect(calls, 1);
  });
}
