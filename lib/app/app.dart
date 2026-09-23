import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/game_controller.dart';
import '../services/random_pokemon_picker.dart';
import '../views/game/game_screen.dart';
import '../views/game3d/game3d_screen.dart';
import '../views/generations/generations_screen.dart';
import '../views/main_menu/main_menu_screen.dart';
import '../views/pokedex/pokedex_screen.dart';
import 'dependencies.dart';

/// Nombres de las rutas (la "dirección" de cada pantalla).
/// Están en constantes para no escribir el texto a mano en cada sitio.
abstract final class AppRoutes {
  static const mainMenu = '/';
  static const game = '/game';
  static const game3d = '/game3d';
  static const pokedex = '/pokedex';
  static const generations = '/generations';
}

/// Widget raíz: monta los providers, el tema y la tabla de rutas.
class PokemonGameApp extends StatelessWidget {
  const PokemonGameApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    // MultiProvider deja los servicios y controladores al alcance
    // de cualquier pantalla que haya debajo.
    return MultiProvider(
      providers: dependencies.providers,
      child: MaterialApp(
        title: 'Pokémon Game',
        // Llave del navegador: permite abrir diálogos desde código
        // que no es un widget (la usa StubEncounterHandler).
        navigatorKey: dependencies.navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          // Material 3 genera toda la paleta a partir de un color.
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
          useMaterial3: true,
        ),
        initialRoute: AppRoutes.mainMenu,
        // Mapa "nombre de ruta -> función que construye la pantalla".
        routes: {
          AppRoutes.mainMenu: (_) => const MainMenuScreen(),
          // El GameController se crea aquí, por partida: así cada sesión
          // de juego empieza limpia y al salir se cierran sus streams.
          AppRoutes.game: (_) => ChangeNotifierProvider(
            create: (context) => GameController(
              picker: context.read<RandomPokemonPicker>(),
              encounterHandler: context.read(),
            ),
            child: const GameScreen(),
          ),
          AppRoutes.game3d: (_) => const Game3DScreen(),
          AppRoutes.pokedex: (_) => const PokedexScreen(),
          AppRoutes.generations: (_) => const GenerationsScreen(),
        },
      ),
    );
  }
}
