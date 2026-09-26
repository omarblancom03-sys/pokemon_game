// PRUEBAS DE PANTALLA (widget tests): que el menú muestra sus
// botones, que "Jugar 2D/3D" navegan al juego, que la Pokédex pinta cartas y
// muestra "Reintentar" si falla, y que desde Generaciones se abre una
// galería y luego el detalle de un Pokémon. Usan un repositorio falso.

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/app/app.dart';
import 'package:pokemon_game/app/dependencies.dart';
import 'package:pokemon_game/game/poke_game.dart';
import 'package:pokemon_game/services/poke_api_exception.dart';
import 'package:pokemon_game/services/sound/sound_service.dart';
import 'package:pokemon_game/views/game3d/game3d_screen.dart';
import 'package:pokemon_game/views/game3d/widgets/field_hud.dart';

import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/models/capture_result.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:pokemon_game/views/pokedex/widgets/pokemon_card.dart';

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
    expect(find.byKey(const Key('game3d_minimap')), findsOneWidget);
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

  testWidgets('3D: a capture shows its card; "Mis capturas" lists it', (
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
    final wild = WildPokemon(
      id: 'w',
      pokemon: fakePokemon(25),
      position: Vector3.zero(),
    );
    const result = CaptureResult(chance: 0.5, shakes: 3, caught: true);
    sim.onEvent!(PokemonCaught(wild, PokeBallType.great, result));
    await tester.pump();
    expect(find.byKey(const Key('capture_card')), findsOneWidget);
    expect(find.text('Poke 25'), findsOneWidget);
    expect(find.text('#025'), findsOneWidget);
    expect(find.text('¡Capturado!'), findsOneWidget);
    expect(find.byKey(const Key('capture_card_new')), findsOneWidget);

    // La misma especie otra vez (y crítica): ya no es nueva.
    const critical = CaptureResult(
      chance: 0.5,
      shakes: 1,
      caught: true,
      critical: true,
    );
    sim.onEvent!(PokemonCaught(wild, PokeBallType.poke, critical));
    await tester.pump();
    expect(find.byKey(const Key('capture_card')), findsNWidgets(2));
    expect(find.byKey(const Key('capture_card_new')), findsOneWidget);
    expect(find.text('¡Captura crítica!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.byKey(const Key('capture_card')), findsNothing);

    // Tocar "Capturados" abre el panel y congela el mundo.
    await tester.tap(find.byKey(const Key('bag_captured')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('captures_panel')), findsOneWidget);
    expect(find.text('Mis capturas (2)'), findsOneWidget);
    expect(find.byType(PokemonCard), findsNWidgets(2));
    expect(sim.isPaused, isTrue);

    await tester.tap(find.byKey(const Key('captures_close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('captures_panel')), findsNothing);
    expect(sim.isPaused, isFalse);
  });

  testWidgets('3D: "Mis capturas" with nothing caught explains how', (
    tester,
  ) async {
    await tester.pumpWidget(
      PokemonGameApp(
        dependencies: AppDependencies.create(
          repository: repository,
          sceneRenderer: FakeSceneRenderer(),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('menu_play_3d')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const Key('bag_captured')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mis capturas (0)'), findsOneWidget);
    expect(find.textContaining('Aún no has capturado'), findsOneWidget);
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

    // Botón de cámara: vuelve detrás del jugador.
    sim.camera.yaw = 1;
    await tester.tap(find.byKey(const Key('game3d_recenter')));
    await tester.pump();
    expect(sim.camera.recenterGoal, isNotNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('3D: a sign in front can be read (tap or L) and closes', (
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
    expect(find.byKey(const Key('sign_prompt')), findsNothing);

    // Delante del cartel del pueblo (7,7), mirando hacia él (al sur).
    final sim = renderer.lastSim!;
    sim.player
      ..teleport(sim.cellCenter(7, 6))
      ..facing = 0;
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('sign_prompt')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sign_prompt')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('sign_panel')), findsOneWidget);
    expect(find.text('Pueblo Paleta'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('sign_panel')), findsNothing);
    expect(find.byKey(const Key('sign_prompt')), findsOneWidget);

    // Abierto otra vez: alejarse lo cierra.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('sign_panel')), findsOneWidget);
    sim.player.teleport(sim.cellCenter(7, 3));
    sim.update(1 / 60);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('sign_panel')), findsNothing);
    expect(find.byKey(const Key('sign_prompt')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('3D: shake a bush (L), berries fill the bag and can be thrown', (
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
    expect(find.byKey(const Key('bush_prompt')), findsNothing);
    Finder berriesInBag(String text) => find.descendant(
      of: find.byKey(const Key('bag_berry')),
      matching: find.text(text),
    );
    expect(berriesInBag('×0'), findsOneWidget);

    // Debajo del arbusto del pueblo (2,10), mirándolo (al norte).
    final sim = renderer.lastSim!;
    sim.player
      ..teleport(sim.cellCenter(2, 11))
      ..facing = 3.14159;
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('bush_prompt')), findsOneWidget);
    expect(find.text('Sacudir el arbusto'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    for (var i = 0; i < 90; i++) {
      sim.update(1 / 60);
    }
    await tester.pump(const Duration(milliseconds: 50));
    expect(berriesInBag('×3'), findsOneWidget);
    expect(find.text('+3 Bayas Frambu'), findsOneWidget);
    expect(find.text('sin bayas'), findsOneWidget);

    // Sacudirlo vacío avisa (tocando el aviso, como en una pantalla táctil).
    await tester.tap(find.byKey(const Key('bush_prompt')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('no tiene bayas'), findsOneWidget);

    // Con la baya en la mano (tecla 4), el botón de lanzar la lanza.
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('game3d_throw')),
        matching: find.byType(BerryIcon),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('game3d_throw')));
    await tester.pump();
    sim.update(World3DSim.releaseTime + 0.01);
    expect(sim.berries.loose.where((b) => b.thrown), hasLength(1));
    expect(berriesInBag('×2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('3D: M (or tapping the minimap) opens the map and freezes the '
      'world', (tester) async {
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

    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('big_map')), findsOneWidget);
    expect(find.text('Arbustos con bayas'), findsOneWidget);
    expect(sim.isPaused, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('big_map')), findsNothing);
    expect(sim.isPaused, isFalse);

    await tester.tap(find.byKey(const Key('game3d_minimap')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('big_map')), findsOneWidget);
    await tester.tap(find.byKey(const Key('big_map_close')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('big_map')), findsNothing);
    expect(sim.isPaused, isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('3D: the controls help folds itself away; H and tapping '
      'toggle it', (tester) async {
    await tester.pumpWidget(
      PokemonGameApp(
        dependencies: AppDependencies.create(
          repository: repository,
          sceneRenderer: FakeSceneRenderer(),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('menu_play_3d')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final help = find.byKey(const Key('game3d_help'));
    final tab = find.byKey(const Key('game3d_help_tab'));
    expect(help, findsOneWidget);
    expect(tab, findsNothing);

    // Al rato se pliega sola.
    await tester.pump(const Duration(seconds: 21));
    await tester.pump(const Duration(milliseconds: 300));
    expect(help, findsNothing);
    expect(tab, findsOneWidget);

    await tester.tap(tab);
    await tester.pump(const Duration(milliseconds: 300));
    expect(help, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump(const Duration(milliseconds: 300));
    expect(help, findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump(const Duration(milliseconds: 300));
    expect(help, findsOneWidget);
    await tester.tap(find.byKey(const Key('game3d_help_close')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tab, findsOneWidget);
  });

  testWidgets('3D: the speaker button (or N) mutes and unmutes', (
    tester,
  ) async {
    final sound = SilentSoundService();
    await tester.pumpWidget(
      PokemonGameApp(
        dependencies: AppDependencies.create(
          repository: repository,
          sceneRenderer: FakeSceneRenderer(),
          soundService: sound,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('menu_play_3d')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(Icons.volume_up), findsOneWidget);

    await tester.tap(find.byKey(const Key('game3d_sound')));
    await tester.pump();
    expect(sound.muted, isTrue);
    expect(find.byIcon(Icons.volume_off), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pump();
    expect(sound.muted, isFalse);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
  });

  testWidgets('3D: once you toggle the help, it no longer folds by '
      'itself', (tester) async {
    await tester.pumpWidget(
      PokemonGameApp(
        dependencies: AppDependencies.create(
          repository: repository,
          sceneRenderer: FakeSceneRenderer(),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('menu_play_3d')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump(const Duration(seconds: 25));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('game3d_help')), findsOneWidget);
  });

  testWidgets('3D: aiming at a species you have (or not) paints fine', (
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
    // Uno ya capturado y otro nuevo, delante del jugador.
    const caught = CaptureResult(chance: 0.5, shakes: 3, caught: true);
    sim.onEvent!(
      PokemonCaught(
        WildPokemon(id: 'c', pokemon: fakePokemon(4), position: Vector3.zero()),
        PokeBallType.poke,
        caught,
      ),
    );
    final ahead = sim.player.position + sim.camera.forward * 6;
    for (final (id, species, side) in [('a', 4, -1.0), ('b', 7, 1.0)]) {
      sim.wild.add(
        WildPokemon(
          id: id,
          pokemon: fakePokemon(species),
          position: ahead + sim.camera.right * side,
        ),
      );
    }
    sim
      ..aiming = true
      ..update(0.5);
    expect(sim.lockedTarget, isNotNull);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 4));
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
