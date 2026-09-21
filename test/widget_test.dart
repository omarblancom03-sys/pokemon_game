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

  testWidgets('main menu shows every entry', (tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.byKey(const Key('menu_play')), findsOneWidget);
    expect(find.byKey(const Key('menu_pokedex')), findsOneWidget);
    expect(find.byKey(const Key('menu_generations')), findsOneWidget);
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

  testWidgets('Generaciones lists the generations', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byKey(const Key('menu_generations')));
    await tester.pumpAndSettle();

    expect(find.text('Generación I'), findsOneWidget);
    expect(find.text('Generación II'), findsOneWidget);
  });

  testWidgets('a generation opens its gallery and then a detail', (
    tester,
  ) async {
    repository.generationSize = 3;
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byKey(const Key('menu_generations')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generación I'));
    await tester.pumpAndSettle();

    expect(find.text('Poke 1'), findsOneWidget);
    expect(find.text('¡Generación completa!'), findsOneWidget);

    await tester.tap(find.text('Poke 1'));
    await tester.pumpAndSettle();

    expect(find.text('Altura'), findsOneWidget);
    expect(find.text('0.1 m'), findsOneWidget);
  });

  testWidgets('Generaciones shows an error with retry', (tester) async {
    repository.failNext = const PokeApiNetworkException('offline');
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byKey(const Key('menu_generations')));
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión. Revisa tu internet.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('generations_retry')));
    await tester.pumpAndSettle();

    expect(find.text('Generación I'), findsOneWidget);
  });
}
