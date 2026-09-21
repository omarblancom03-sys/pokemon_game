import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/game_controller.dart';
import '../services/random_pokemon_picker.dart';
import '../views/game/game_screen.dart';
import '../views/generations/generations_screen.dart';
import '../views/main_menu/main_menu_screen.dart';
import '../views/pokedex/pokedex_screen.dart';
import 'dependencies.dart';

abstract final class AppRoutes {
  static const mainMenu = '/';
  static const game = '/game';
  static const pokedex = '/pokedex';
  static const generations = '/generations';
}

class PokemonGameApp extends StatelessWidget {
  const PokemonGameApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: dependencies.providers,
      child: MaterialApp(
        title: 'Pokémon Game',
        navigatorKey: dependencies.navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
          useMaterial3: true,
        ),
        initialRoute: AppRoutes.mainMenu,
        routes: {
          AppRoutes.mainMenu: (_) => const MainMenuScreen(),
          // A fresh GameController per play session, disposed on exit.
          AppRoutes.game: (_) => ChangeNotifierProvider(
            create: (context) => GameController(
              picker: context.read<RandomPokemonPicker>(),
              encounterHandler: context.read(),
            ),
            child: const GameScreen(),
          ),
          AppRoutes.pokedex: (_) => const PokedexScreen(),
          AppRoutes.generations: (_) => const GenerationsScreen(),
        },
      ),
    );
  }
}
