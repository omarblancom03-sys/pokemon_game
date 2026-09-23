import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../controllers/encounter/encounter_handler.dart';
import '../controllers/generations_controller.dart';
import '../controllers/pokedex_controller.dart';
import '../game3d/render/scene_renderer.dart';
import '../services/image_bytes_service.dart';
import '../services/poke_api_service.dart';
import '../services/pokemon_repository.dart';
import '../services/random_pokemon_picker.dart';
import '../views/game/stub_encounter_handler.dart';

/// Raíz de composición: el ÚNICO sitio donde se crean los servicios,
/// controladores y handlers concretos. El resto del código los recibe ya
/// construidos (esto es la "inyección de dependencias").
class AppDependencies {
  const AppDependencies._({
    required this.providers,
    required this.navigatorKey,
  });

  /// [repository] y [encounterHandler] se pueden sustituir: en los tests se
  /// pasan versiones falsas, y aquí se enchufará la captura real (Pokébola).
  factory AppDependencies.create({
    PokemonRepository? repository,
    EncounterHandler? encounterHandler,
    SceneRenderer? sceneRenderer,
  }) {
    final navigatorKey = GlobalKey<NavigatorState>();
    // Cadena de capas: cliente HTTP -> servicio -> caché (patrón decorador).
    // Si no se pasa nada, se usa la implementación real.
    final client = http.Client();
    final repo =
        repository ??
        CachedPokemonRepository(service: PokeApiService(client: client));

    // ↓↓↓ CONTRATO DE ENCUENTRO: reemplazar StubEncounterHandler por la
    // implementación real de la captura (Pokébola). Ver encounter_handler.dart.
    final handler =
        encounterHandler ?? StubEncounterHandler(navigatorKey: navigatorKey);

    return AppDependencies._(
      navigatorKey: navigatorKey,
      // Todo lo que las pantallas pueden pedir con context.read/watch.
      providers: [
        Provider<PokemonRepository>.value(value: repo),
        Provider<RandomPokemonPicker>.value(
          value: RandomPokemonPicker(repository: repo),
        ),
        Provider<EncounterHandler>.value(value: handler),
        // Motor 3D. En los tests se pasa uno falso (allí no hay GPU).
        Provider<SceneRenderer>.value(
          value:
              sceneRenderer ??
              FlutterSceneRenderer(
                loadImage: ImageBytesService(client: client).fetch,
              ),
        ),
        // A nivel de app: lo ya descargado sobrevive al salir y volver a entrar.
        ChangeNotifierProvider(
          create: (_) => PokedexController(repository: repo),
        ),
        ChangeNotifierProvider(
          create: (_) => GenerationsController(repository: repo),
        ),
      ],
    );
  }

  final List<SingleChildWidget> providers;

  /// Permite mostrar diálogos desde código que no es un widget.
  final GlobalKey<NavigatorState> navigatorKey;
}
