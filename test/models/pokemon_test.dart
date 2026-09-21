import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/models/pokemon.dart';
import 'package:pokemon_game/models/pokemon_type.dart';

import '../fixtures/fixture_loader.dart';

void main() {
  group('Pokemon.fromJson', () {
    test('parses the fields used by the app', () {
      final pokemon = Pokemon.fromJson(fixtureJson('bulbasaur.json'));

      expect(pokemon.id, 1);
      expect(pokemon.name, 'bulbasaur');
      expect(pokemon.height, 7);
      expect(pokemon.weight, 69);
      expect(pokemon.imageUrl, endsWith('/other/official-artwork/1.png'));
    });

    test('orders types by slot, not by array position', () {
      final pokemon = Pokemon.fromJson(fixtureJson('bulbasaur.json'));

      expect(pokemon.types, [PokemonType.grass, PokemonType.poison]);
    });

    test('falls back to the default sprite when there is no artwork', () {
      final pokemon = Pokemon.fromJson(fixtureJson('no_artwork.json'));

      expect(pokemon.imageUrl, endsWith('/sprites/pokemon/10001.png'));
    });

    test('imageUrl is null when no sprite exists', () {
      final json = fixtureJson('bulbasaur.json')
        ..['sprites'] = <String, dynamic>{'front_default': null};

      expect(Pokemon.fromJson(json).imageUrl, isNull);
    });

    test('maps unknown type names to PokemonType.unknown', () {
      final json = fixtureJson('no_artwork.json');
      ((json['types'] as List<dynamic>).first as Map<String, dynamic>)['type'] =
          {'name': 'cosmic'};

      expect(Pokemon.fromJson(json).types, [PokemonType.unknown]);
    });

    test('throws FormatException when a required field is missing', () {
      final json = fixtureJson('bulbasaur.json')..remove('id');

      expect(() => Pokemon.fromJson(json), throwsFormatException);
    });

    test('throws FormatException when a field has the wrong type', () {
      final json = fixtureJson('bulbasaur.json')..['id'] = '1';

      expect(() => Pokemon.fromJson(json), throwsFormatException);
    });
  });

  group('Pokemon.toJson', () {
    test('round-trips through fromJson', () {
      final original = Pokemon.fromJson(fixtureJson('bulbasaur.json'));

      expect(Pokemon.fromJson(original.toJson()), original);
    });

    test('equal values have equal hash codes', () {
      final a = Pokemon.fromJson(fixtureJson('bulbasaur.json'));
      final b = Pokemon.fromJson(fixtureJson('bulbasaur.json'));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
