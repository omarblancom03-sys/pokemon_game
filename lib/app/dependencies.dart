import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../controllers/encounter/encounter_handler.dart';
import '../controllers/generations_controller.dart';
import '../controllers/pokedex_controller.dart';
import '../services/poke_api_service.dart';
import '../services/pokemon_repository.dart';
import '../services/random_pokemon_picker.dart';
import '../views/game/stub_encounter_handler.dart';

/// Composition root: the only place where concrete services, controllers and
/// handlers are instantiated.
class AppDependencies {
  const AppDependencies._({
    required this.providers,
    required this.navigatorKey,
  });

  /// [repository] and [encounterHandler] can be overridden (tests, or the
  /// partner's capture sequence).
  factory AppDependencies.create({
    PokemonRepository? repository,
    EncounterHandler? encounterHandler,
  }) {
    final navigatorKey = GlobalKey<NavigatorState>();
    final repo =
        repository ??
        CachedPokemonRepository(service: PokeApiService(client: http.Client()));

    // ↓↓↓ CONTRATO DE ENCUENTRO: reemplazar StubEncounterHandler por la
    // implementación real de la captura (Pokébola). Ver encounter_handler.dart.
    final handler =
        encounterHandler ?? StubEncounterHandler(navigatorKey: navigatorKey);

    return AppDependencies._(
      navigatorKey: navigatorKey,
      providers: [
        Provider<PokemonRepository>.value(value: repo),
        Provider<RandomPokemonPicker>.value(
          value: RandomPokemonPicker(repository: repo),
        ),
        Provider<EncounterHandler>.value(value: handler),
        // App-wide so the loaded gallery survives leaving and re-entering.
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

  /// Lets non-widget code (the stub handler) present dialogs.
  final GlobalKey<NavigatorState> navigatorKey;
}
