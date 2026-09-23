// PRUEBAS del servicio de imágenes: devuelve los bytes, cachea la descarga,
// traduce los errores HTTP/red a PokeApiException y no cachea los fallos.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokemon_game/services/image_bytes_service.dart';
import 'package:pokemon_game/services/poke_api_exception.dart';

void main() {
  const url = 'https://img.test/25.png';
  final png = Uint8List.fromList([137, 80, 78, 71]);

  test('returns the bytes and caches repeated requests', () async {
    var calls = 0;
    final service = ImageBytesService(
      client: MockClient((request) async {
        calls++;
        return http.Response.bytes(png, 200);
      }),
    );

    expect(await service.fetch(url), png);
    expect(await service.fetch(url), png);
    expect(calls, 1);
  });

  test('maps 404, 500 and network errors', () async {
    ImageBytesService serviceReturning(int code) => ImageBytesService(
      client: MockClient((_) async => http.Response('', code)),
    );

    await expectLater(
      serviceReturning(404).fetch(url),
      throwsA(isA<PokeApiNotFoundException>()),
    );
    await expectLater(
      serviceReturning(500).fetch(url),
      throwsA(isA<PokeApiServerException>()),
    );
    await expectLater(
      ImageBytesService(
        client: MockClient((_) => throw http.ClientException('offline')),
      ).fetch(url),
      throwsA(isA<PokeApiNetworkException>()),
    );
  });

  test('an empty body is a parse error', () async {
    final service = ImageBytesService(
      client: MockClient((_) async => http.Response.bytes(const [], 200)),
    );
    await expectLater(
      service.fetch(url),
      throwsA(isA<PokeApiParseException>()),
    );
  });

  test('failures are not cached: the next call retries', () async {
    var calls = 0;
    final service = ImageBytesService(
      client: MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('', 500)
            : http.Response.bytes(png, 200);
      }),
    );

    await expectLater(service.fetch(url), throwsA(isA<PokeApiException>()));
    expect(await service.fetch(url), png);
    expect(calls, 2);
  });
}
