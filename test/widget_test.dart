import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/app/app.dart';
import 'package:pokemon_game/app/dependencies.dart';
import 'package:pokemon_game/game/poke_game.dart';
import 'package:pokemon_game/services/poke_api_exception.dart';

import 'fakes/fake_pokemon_repository.dart';

void main() {
  late FakePokemonRepository repository;

  setUp(() => repository = FakePokemonRepository(speciesCount: 40));

  Widget buildApp() => PokemonGameApp(
    dependencies: AppDependencies.create(repository: repository),
  );

  testWidgets('main menu shows Jugar and Pokédex entries', (tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.byKey(const Key('menu_play')), findsOneWidget);
    expect(find.byKey(const Key('menu_pokedex')), findsOneWidget);
  });

  testWidgets('Jugar navigates to the game screen', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byKey(const Key('menu_play')));
    // The game loop ticks forever, so pumpAndSettle would never return.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(GameWidget<PokeGame>), findsOneWidget);
    expect(find.byKey(const Key('game_dpad')), findsOneWidget);
  });

  testWidgets('Pokédex shows a gallery of cards', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byKey(const Key('menu_pokedex')));
    await tester.pumpAndSettle();

    expect(find.text('Poke 1'), findsOneWidget);
    expect(find.text('#001'), findsOneWidget);
    expect(find.text('Fire'), findsWidgets);
  });

  testWidgets('Pokédex shows an error with retry', (tester) async {
    repository.failNext = const PokeApiNetworkException('offline');
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byKey(const Key('menu_pokedex')));
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión. Revisa tu internet.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pokedex_retry')));
    await tester.pumpAndSettle();

    expect(find.text('Poke 1'), findsOneWidget);
  });
}
