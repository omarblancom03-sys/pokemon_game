// PRUEBAS del modelo Generation: que ordena las especies por número de
// Pokédex, que las referencias sin id numérico van al final y no salen en
// speciesIds, y que un JSON mal formado lanza FormatException.

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/models/generation.dart';
import 'package:pokemon_game/models/named_resource.dart';

import '../fixtures/fixture_loader.dart';

void main() {
  group('Generation.fromJson', () {
    test('reads id, name and main region', () {
      final generation = Generation.fromJson(fixtureJson('generation.json'));

      expect(generation.id, 1);
      expect(generation.name, 'generation-i');
      expect(generation.mainRegion, 'kanto');
    });

    test('sorts species by Pokédex number', () {
      final generation = Generation.fromJson(fixtureJson('generation.json'));

      // The fixture lists charmander (4) first, on purpose.
      expect(generation.species.map((s) => s.name), [
        'bulbasaur',
        'ivysaur',
        'charmander',
      ]);
      expect(generation.speciesIds, [1, 2, 4]);
    });

    test('puts species without a numeric id last and skips them in ids', () {
      final generation = Generation.fromJson({
        'id': 1,
        'name': 'generation-i',
        'main_region': {'name': 'kanto'},
        'pokemon_species': [
          {
            'name': 'broken',
            'url': 'https://pokeapi.co/api/v2/pokemon-species/',
          },
          {
            'name': 'bulbasaur',
            'url': 'https://pokeapi.co/api/v2/pokemon-species/1/',
          },
        ],
      });

      expect(generation.species.last.name, 'broken');
      expect(generation.speciesIds, [1]);
    });

    test('throws FormatException when main_region is missing', () {
      expect(
        () => Generation.fromJson({
          'id': 1,
          'name': 'generation-i',
          'pokemon_species': <Map<String, dynamic>>[],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when pokemon_species is not a list', () {
      expect(
        () => Generation.fromJson({
          'id': 1,
          'name': 'generation-i',
          'main_region': {'name': 'kanto'},
          'pokemon_species': 'nope',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('toJson round-trips', () {
    final generation = Generation.fromJson(fixtureJson('generation.json'));

    expect(Generation.fromJson(generation.toJson()), generation);
  });

  group('equality', () {
    Generation build({String name = 'generation-i'}) => Generation(
      id: 1,
      name: name,
      mainRegion: 'kanto',
      species: const [
        NamedResource(
          name: 'bulbasaur',
          url: 'https://pokeapi.co/api/v2/pokemon-species/1/',
        ),
      ],
    );

    test('same values are equal and share a hash code', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('a different name is not equal', () {
      expect(build(), isNot(build(name: 'generation-ii')));
    });

    test('a different species list is not equal', () {
      const other = Generation(
        id: 1,
        name: 'generation-i',
        mainRegion: 'kanto',
        species: [],
      );

      expect(build(), isNot(other));
    });
  });
}
