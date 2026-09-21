import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/models/named_resource.dart';
import 'package:pokemon_game/models/paged_result.dart';

import '../fixtures/fixture_loader.dart';

void main() {
  group('NamedResource', () {
    test('extracts the id from the url', () {
      const resource = NamedResource(
        name: 'pikachu',
        url: 'https://pokeapi.co/api/v2/pokemon/25/',
      );

      expect(resource.id, 25);
    });

    test('id is null when the url has no numeric segment', () {
      const resource = NamedResource(name: 'x', url: 'https://pokeapi.co/');

      expect(resource.id, isNull);
    });

    test('round-trips through json', () {
      const resource = NamedResource(name: 'a', url: 'https://x/pokemon/1/');

      expect(NamedResource.fromJson(resource.toJson()), resource);
    });
  });

  group('PagedResult', () {
    test('parses count, next and items', () {
      final page = PagedResult.fromJson(
        fixtureJson('pokemon_page.json'),
        NamedResource.fromJson,
      );

      expect(page.count, 1302);
      expect(page.hasNext, isTrue);
      expect(page.items.map((r) => r.name), ['bulbasaur', 'ivysaur']);
      expect(page.items.map((r) => r.id), [1, 2]);
    });

    test('hasNext is false on the last page', () {
      final json = fixtureJson('pokemon_page.json')..['next'] = null;

      expect(
        PagedResult.fromJson(json, NamedResource.fromJson).hasNext,
        isFalse,
      );
    });
  });
}
