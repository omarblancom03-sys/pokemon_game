import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/generation.dart';
import '../models/json_reader.dart';
import '../models/named_resource.dart';
import '../models/paged_result.dart';
import '../models/pokemon.dart';
import 'poke_api_exception.dart';

/// SERVICIO: la única clase de todo el proyecto que habla con internet.
///
/// Solo entrada/salida: no guarda nada ni tiene estado. Devuelve modelos o
/// lanza un [PokeApiException].
class PokeApiService {
  /// El cliente HTTP se recibe desde fuera: en los tests se pasa uno falso
  /// (MockClient) y así las pruebas no tocan la red.
  PokeApiService({
    required this._client,
    Uri? baseUri,
    this.timeout = const Duration(seconds: 15),
  }) : _baseUri = baseUri ?? defaultBaseUri;

  static final Uri defaultBaseUri = Uri.parse('https://pokeapi.co/api/v2/');

  final http.Client _client;
  final Uri _baseUri;

  /// Tiempo máximo de espera: evita quedarse colgado para siempre.
  final Duration timeout;

  /// `GET /pokemon/{id}` → un Pokémon completo.
  Future<Pokemon> fetchPokemon(int id) async {
    final json = await _getJson('pokemon/$id');
    return _parse(() => Pokemon.fromJson(json));
  }

  /// `GET /pokemon?offset=&limit=` → una página de referencias.
  Future<PagedResult<NamedResource>> fetchPokemonPage({
    required int offset,
    required int limit,
  }) async {
    final json = await _getJson(
      'pokemon',
      query: {'offset': '$offset', 'limit': '$limit'},
    );
    return _parse(() => PagedResult.fromJson(json, NamedResource.fromJson));
  }

  /// Número total de especies. Se pide limit=1 porque lo que interesa no es
  /// la especie, sino el campo `count`.
  ///
  /// Se usa este endpoint y no `/pokemon` porque los ids de especie SÍ son
  /// contiguos (1..count); los de `/pokemon` incluyen formas alternativas
  /// con ids ≥ 10001 y sortear ahí daría 404 muy a menudo.
  Future<int> fetchSpeciesCount() async {
    final json = await _getJson('pokemon-species', query: {'limit': '1'});
    return _parse(() => json.readInt('count'));
  }

  /// `GET /generation` → la lista de generaciones.
  Future<PagedResult<NamedResource>> fetchGenerations() async {
    final json = await _getJson('generation', query: {'limit': '50'});
    return _parse(() => PagedResult.fromJson(json, NamedResource.fromJson));
  }

  /// `GET /generation/{id}` → una generación con sus especies.
  Future<Generation> fetchGeneration(int id) async {
    final json = await _getJson('generation/$id');
    return _parse(() => Generation.fromJson(json));
  }

  /// Todo el trabajo sucio en un sitio: petición, control de errores y
  /// conversión del texto JSON a objetos.
  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = _baseUri.resolve(path).replace(queryParameters: query);

    final http.Response response;
    try {
      // 1) La petición, con límite de tiempo.
      response = await _client.get(uri).timeout(timeout);
    } on TimeoutException catch (e) {
      // Los errores ajenos se traducen a errores propios: las capas de
      // arriba solo conocen PokeApiException.
      throw PokeApiNetworkException('Timed out requesting $uri', cause: e);
    } on http.ClientException catch (e) {
      throw PokeApiNetworkException('Request to $uri failed', cause: e);
    }

    // 2) y 3) Códigos de respuesta: 404 = no existe, otro no-2xx = servidor.
    if (response.statusCode == 404) throw PokeApiNotFoundException(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PokeApiServerException(response.statusCode, uri);
    }

    final Object? decoded;
    try {
      // 4) Texto → objetos. utf8.decode fuerza el juego de caracteres,
      // para que los acentos no salgan rotos.
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (e) {
      throw PokeApiParseException('Invalid JSON from $uri', cause: e);
    }
    // 5) Debe ser un objeto JSON, no una lista ni un número suelto.
    if (decoded is! Map<String, dynamic>) {
      throw PokeApiParseException('Expected a JSON object from $uri');
    }
    return decoded;
  }

  /// Envuelve la construcción de modelos: convierte los FormatException del
  /// JsonReader en PokeApiParseException.
  T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on FormatException catch (e) {
      throw PokeApiParseException(e.message, cause: e);
    }
  }
}
