// PRUEBAS DE PANTALLA (widget tests): que el menú muestra sus
// botones, que "Jugar 2D/3D" navegan al juego, que la Pokédex pinta cartas y
// muestra "Reintentar" si falla, y que desde Generaciones se abre una
// galería y luego el detalle de un Pokémon. Usan un repositorio falso.

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/app/app.dart';
import 'package:pokemon_game/app/dependencies.dart';
import 'package:pokemon_game/game/poke_game.dart';
import 'package:pokemon_game/services/poke_api_exception.dart';
import 'package:pokemon_game/views/game3d/game3d_screen.dart';

import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/poke_ball.dart';

import 'fakes/fake_pokemon_repository.dart';
import 'fakes/fake_scene_renderer.dart';

void main() {
  late FakePokemonRepository repository;

  setUp(() => repository = FakePokemonRepository(speciesCount: 40));

  Widget buildApp() => PokemonGameApp(
    dependencies: AppDependencies.create(
      repository: repository,
      sceneRenderer: FakeSceneRenderer(),
    ),
  );

  testWidgets('main menu shows every entry', (tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.byKey(const Key('menu_play')), findsOneWidget);
    expect(find.byKey(const Key('menu_play_3d')), findsOneWidget);
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

  testWidgets('Jugar 3D navigates to the 3D screen', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byKey(const Key('menu_play_3d')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Game3DScreen), findsOneWidget);
    expect(find.byKey(const Key('fake_scene')), findsOneWidget);
    expect(find.byKey(const Key('game3d_dpad')), findsOneWidget);
  });

  testWidgets('3D HUD: picking up balls fills the bag and shows a notice', (
    tester,
  ) async {
    final renderer = FakeSceneRenderer();
    await tester.pumpWidget(
      PokemonGameApp(
        dependencies: AppDependencies.create(
          repository: repository,
          sceneRenderer: renderer,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('menu_play_3d')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.descendant(
        of: find.byKey(const Key('bag_poke')),
        matching: find.text('×5'),
      ),
      findsOneWidget,
    );
    renderer.lastSim!.onEvent!(const BallsPickedUp(PokeBallType.ultra, 1));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('bag_ultra')),
        matching: find.text('×1'),
      ),
      findsOneWidget,
    );
    expect(find.text('+1 Ultra Ball'), findsOneWidget);

    // El aviso se va solo.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('+1 Ultra Ball'), findsNothing);
  });

  testWidgets('3D: the throw button spends a ball; an empty bag warns', (
    tester,
  ) async {
    final renderer = FakeSceneRenderer();
    await tester.pumpWidget(
      PokemonGameApp(
        dependencies: AppDependencies.create(
          repository: repository,
          sceneRenderer: renderer,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('menu_play_3d')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final sim = renderer.lastSim!;
    await tester.tap(find.byKey(const Key('game3d_throw')));
    await tester.pump();
    expect(sim.throwProgress, isNotNull);
    expect(
      find.descendant(
        of: find.byKey(const Key('bag_poke')),
        matching: find.text('×4'),
      ),
      findsOneWidget,
    );

    // Gastar el resto (la simulación no avanza sola: se hace a mano).
    for (var i = 0; i < 4; i++) {
      sim.update(World3DSim.throwDuration + 0.01);
      await tester.tap(find.byKey(const Key('game3d_throw')));
      await tester.pump();
    }
    sim.update(World3DSim.throwDuration + 0.01);
    await tester.tap(find.byKey(const Key('game3d_throw')));
    await tester.pump();
    expect(find.textContaining('No te quedan'), findsOneWidget);
    expect(sim.readyBall, isNull);

    // Botón de apuntar: se queda activo.
    await tester.tap(find.byKey(const Key('game3d_aim')));
    await tester.pump();
    expect(sim.aiming, isTrue);

    // Botón de agacharse (sigilo).
    await tester.tap(find.byKey(const Key('game3d_crouch')));
    await tester.pump();
    expect(sim.crouching, isTrue);
    await tester.pump(const Duration(seconds: 3));
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
