import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/generation.dart';
import '../models/json_reader.dart';
import '../models/named_resource.dart';
import '../models/paged_result.dart';
import '../models/pokemon.dart';
import 'poke_api_exception.dart';

/// Thin HTTP client for PokeAPI. Network I/O only: no caching, no state.
///
/// Returns models or throws a [PokeApiException].
class PokeApiService {
  PokeApiService({
    required this._client,
    Uri? baseUri,
    this.timeout = const Duration(seconds: 15),
  }) : _baseUri = baseUri ?? defaultBaseUri;

  static final Uri defaultBaseUri = Uri.parse('https://pokeapi.co/api/v2/');

  final http.Client _client;
  final Uri _baseUri;
  final Duration timeout;

  /// `GET /pokemon/{id}`.
  Future<Pokemon> fetchPokemon(int id) async {
    final json = await _getJson('pokemon/$id');
    return _parse(() => Pokemon.fromJson(json));
  }

  /// `GET /pokemon?offset=&limit=`.
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

  /// Number of species. Species ids are contiguous in `[1, count]` and each
  /// maps to `/pokemon/{id}`, unlike `/pokemon`'s count which includes
  /// alternate forms with ids ≥ 10001.
  Future<int> fetchSpeciesCount() async {
    final json = await _getJson('pokemon-species', query: {'limit': '1'});
    return _parse(() => json.readInt('count'));
  }

  /// `GET /generation`.
  Future<PagedResult<NamedResource>> fetchGenerations() async {
    final json = await _getJson('generation', query: {'limit': '50'});
    return _parse(() => PagedResult.fromJson(json, NamedResource.fromJson));
  }

  /// `GET /generation/{id}`.
  Future<Generation> fetchGeneration(int id) async {
    final json = await _getJson('generation/$id');
    return _parse(() => Generation.fromJson(json));
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = _baseUri.resolve(path).replace(queryParameters: query);

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

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (e) {
      throw PokeApiParseException('Invalid JSON from $uri', cause: e);
    }
    if (decoded is! Map<String, dynamic>) {
      throw PokeApiParseException('Expected a JSON object from $uri');
    }
    return decoded;
  }

  T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on FormatException catch (e) {
      throw PokeApiParseException(e.message, cause: e);
    }
  }
}
