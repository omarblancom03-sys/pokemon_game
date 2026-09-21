# Pokémon Game (Flutter + Flame, MVC)

App tipo Pokémon: menú principal, escena de juego top-down con encuentros aleatorios
desde [PokeAPI](https://pokeapi.co/) y una Pokédex en forma de galería de cartas.

## Ejecutar

```bash
flutter pub get
flutter run -d chrome        # o windows / android
flutter analyze && flutter test
```

Vista web estática: `flutter build web && node tool/serve_web.mjs` → http://localhost:5500

## Arquitectura (MVC)

```
lib/
  app/          app.dart (rutas), dependencies.dart (composition root)
  models/       Pokemon, PokemonType, NamedResource, PagedResult, LoadState (inmutables, fromJson/toJson)
  services/     PokeApiService (solo HTTP), PokemonRepository (caché), RandomPokemonPicker, excepciones tipadas
  controllers/  PokedexController, GameController, encounter/ (EncounterHandler, EncounterState)
  views/        main_menu/, pokedex/, game/ (GameScreen, D-pad, overlays, StubEncounterHandler)
  game/         PokeGame (Flame), components/ (Ash, Smoke, Map), visuals/ (placeholders), input/, config/
```

- **Views** solo pintan y despachan acciones. **Controllers** no importan widgets ni `http`.
- **Services** devuelven models o lanzan `PokeApiException` (Network / NotFound / Server / Parse).
- **Game** no conoce HTTP ni providers: avisa `onSmokeReached(id)` y obedece `setPaused` / `removeSmoke`.
- **Arte final**: `AshComponent` recibe un `AshVisual` y `SmokeComponent` un `visual`. Cambiar placeholders
  por sprites no toca lógica, controllers ni services.

### Pokémon aleatorio
`GET /pokemon-species?limit=1` → `count` (cacheado) → id uniforme en `[1, count]` → `GET /pokemon/{id}`.
Se usa el count de *species* porque sus ids son contiguos; el de `/pokemon` incluye formas con ids ≥ 10001
que darían 404.

## Contrato de encuentro (enganche para la captura)

> La animación de lanzar la Pokébola / capturar **no es parte de esta entrega**. Se conecta aquí.

```dart
// lib/controllers/encounter/encounter_handler.dart
enum EncounterOutcome { caught, fled }

abstract interface class EncounterHandler {
  Future<EncounterOutcome> handleEncounter(Pokemon pokemon);
}
```

**Flujo**

1. Ash toca un humo → `GameController.onSmokeReached(smokeId)`.
2. Estado `EncounterResolving`: juego en pausa + overlay "¡Algo se mueve entre el humo…!".
3. `RandomPokemonPicker.pick()` resuelve el Pokémon.
   - Si falla → `EncounterFailed` con overlay **Reintentar / Cancelar** (cancelar deja el humo).
4. Estado `EncounterActive(smokeId, pokemon)`; se emite en `GameController.encounters` (`Stream<Pokemon>`).
5. **Se llama `handleEncounter(pokemon)` y se espera su Future** (el juego sigue en pausa).
6. Al completar: se guarda `lastOutcome`, el humo desaparece (reaparece en otro lugar a los 4 s)
   y el juego se reanuda.

**Cómo conectar la captura real**

1. Implementa `EncounterHandler` (p. ej. navega a una pantalla/overlay de captura y completa con su resultado).
2. En `lib/app/dependencies.dart` reemplaza `StubEncounterHandler(...)` por tu clase
   (o pásala como `AppDependencies.create(encounterHandler: ...)`). Nada más cambia.

Notas:
- `navigatorKey` está disponible en `AppDependencies` para mostrar rutas/diálogos sin `BuildContext`.
- Si tu handler lanza una excepción, se reporta con `FlutterError.reportError` y se trata como `fled`,
  para que el juego nunca quede congelado.
- Para escuchar encuentros sin controlar el flujo (analytics, contador), suscríbete a `encounters`.

**Stub actual**: `lib/views/game/stub_encounter_handler.dart` muestra un diálogo con imagen, número, nombre y
tipos, y botones *Huir* / *Atrapar*. Existe solo para probar el flujo end to end.
