import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'poke_api_exception.dart';

/// SERVICIO: descarga los bytes de una imagen (los dibujos de PokeAPI que
/// el mundo 3D pega sobre carteles). Solo hace I/O: no decodifica ni sabe
/// del motor.
///
/// Guarda en memoria la descarga de cada URL (la misma Future): pedir dos
/// veces el mismo dibujo no repite la petición. Si falla, se olvida para
/// poder reintentar.
class ImageBytesService {
  ImageBytesService({
    required this._client,
    this.timeout = const Duration(seconds: 20),
  });

  final http.Client _client;
  final Duration timeout;
  final Map<String, Future<Uint8List>> _cache = {};

  Future<Uint8List> fetch(String url) {
    final cached = _cache[url];
    if (cached != null) return cached;
    final future = _download(Uri.parse(url));
    _cache[url] = future;
    // Un error no se queda en caché.
    future.catchError((Object _) {
      _cache.remove(url);
      return Uint8List(0);
    }).ignore();
    return future;
  }

  Future<Uint8List> _download(Uri uri) async {
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } on TimeoutException catch (e) {
      throw PokeApiNetworkException('Timed out requesting $uri', cause: e);
    } on http.ClientException catch (e) {
      throw PokeApiNetworkException('Request to $uri failed', cause: e);
    }
    if (response.statusCode == 404) throw PokeApiNotFoundException(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PokeApiServerException(response.statusCode, uri);
    }
    if (response.bodyBytes.isEmpty) {
      throw PokeApiParseException('Empty image from $uri');
    }
    return response.bodyBytes;
  }
}
