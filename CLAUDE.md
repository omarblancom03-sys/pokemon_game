# CLAUDE.md — Juego tipo Pokémon (Flutter + Flame, MVC)

> LEER PRIMERO. Este archivo es la memoria del proyecto: plan aprobado + progreso.
> Actualizar la sección "Progreso" al terminar cada paso. El usuario tiene tokens
> limitados: trabajar en pasos pequeños, sin re-explorar lo ya hecho.

## Reglas de trabajo (del usuario)
- Ingeniería real, nada de vibecoding. Incremental y verificable.
- MVC estricto: Views sin lógica/HTTP; Controllers sin widgets; Services solo I/O.
- Tests unitarios de models, services, controllers.
- Cada fase termina con `flutter analyze` = 0 issues y `flutter test` en verde.
- Idioma de conversación: español. Código/identificadores en inglés.
- **Comentarios en español** (2026-09-20, pedido del usuario): todo `lib/` y las cabeceras de `test/`
  están comentados en español para que el usuario pueda defender el proyecto. Mantener ese idioma
  al añadir código nuevo; los identificadores siguen en inglés.

## Trabajo por turnos (2026-09-28): Omar + un amigo, cada uno con su Claude Code
Repo: https://github.com/omarblancom03-sys/pokemon_game (rama `master`). Los dos se turnan
(uno de noche, otro de día) corriendo `bucle.ps1`. La continuidad entre turnos vive en
TODO.md, DECISIONES.md, PROGRESO.md y este archivo: mantenerlos al día.

**Reglas (también para Claude):**
- NUNCA correr dos bucles a la vez (en dos computadoras) → conflictos en TODO.md/PROGRESO.md.
- Antes de empezar a trabajar: `git pull --rebase origin master`.
- Tras cada commit: `git push origin master`. Si falla: `git pull --rebase`, resolver, reintentar.
- Al terminar un turno no debe quedar nada sin subir (`git status` = "up to date", sin cambios).
- Si Claude encuentra conflictos que no puede resolver con seguridad, se detiene y lo anota en PROGRESO.md.

**Comandos (PowerShell, en la carpeta del proyecto):**
```powershell
# Primera vez en una computadora nueva
git clone https://github.com/omarblancom03-sys/pokemon_game.git
cd pokemon_game
flutter pub get

# 1) Al empezar tu turno: traer lo del otro
git pull --rebase origin master
flutter pub get

# 2) Correr el bucle (Claude trabaja solo; Ctrl+C para detenerlo)
powershell -ExecutionPolicy Bypass -File .\bucle.ps1

# 3) Al terminar tu turno (tras Ctrl+C): subir lo pendiente y comprobar
git add -A; git commit -m "Cierre de turno"   # solo si quedó algo sin commit
git push origin master
git status        # debe decir "up to date" y "nothing to commit"
# 4) Avisarle al otro: "ya te toca"
```
Ver lo que se hizo: `git log --oneline -20` o GitHub → Commits. Deshacer un commit malo:
`git revert <id>` y `git push`.

## Stack (fijo)
Flutter 3.47.4 / Dart 3.13.3. Deps: flame 1.38.2, provider 6.1.5+1, http 1.6.0.
Dev: flame_test 2.3.1, flutter_lints. Tests HTTP con `package:http/testing.dart` (MockClient), sin mockito.

## Arquitectura (aprobada)
```
lib/
  main.dart                    # runApp(PokemonGameApp(dependencies: AppDependencies.create()))
  app/app.dart                 # MaterialApp, tema, rutas con nombre (AppRoutes)
  app/dependencies.dart        # composition root: construye services/controllers/handlers
  models/                      # pokemon.dart, pokemon_type.dart, named_resource.dart, paged_result.dart, load_state.dart
  services/                    # poke_api_exception.dart, poke_api_service.dart, pokemon_repository.dart, random_pokemon_picker.dart
  controllers/                 # pokedex_controller.dart, game_controller.dart, encounter/{encounter_handler,encounter_state}.dart
  views/                       # main_menu/, pokedex/(+widgets/pokemon_card.dart), game/(game_screen, widgets/d_pad, stub_encounter_handler)
  game/                        # poke_game.dart, config/world_config.dart, input/movement_input.dart,
                               # components/{map,ash,smoke}_component.dart, visuals/{ash,smoke}_visual.dart
```
- `PokemonRepository` = caché en memoria (decorador) sobre `PokeApiService`; controllers dependen de interfaces.
- Componentes Flame: lógica (hitbox, movimiento, límites) separada de visual (hijo reemplazable por sprite).
- Flame → `controller.onSmokeReached(smokeId)`; controller → juego vía `isPaused` y humo consumido.

### Contrato de encuentro
```dart
abstract interface class EncounterHandler {
  Future<EncounterOutcome> handleEncounter(Pokemon pokemon); // juego pausado hasta que completa
}
enum EncounterOutcome { caught, fled }
```
+ `Stream<Pokemon> get encounters` en GameController. Stub: `StubEncounterHandler` (diálogo).
Flujo: colisión → Resolving(pausa+loading) → picker → Active → emit + await handler → quitar humo → reanudar.
Error → Failed (overlay Reintentar/Cancelar). Guard contra doble disparo.

### Random (opción A, aprobada)
`GET /pokemon-species?limit=1` → `count` (ids contiguos 1..count, cacheado) → id = Random(inyectable) en [1,count] → `GET /pokemon/{id}`.
(NO usar count de /pokemon: incluye ids 10001+ → 404.)

## Fases
| # | Entrega | Tests |
|---|---|---|
| 0 | deps, lints estrictos, carpetas, dependencies.dart, MainMenu + navegación a pantallas placeholder | widget test menú |
| 1 | models + excepciones + PokeApiService | parsing con fixtures; service con MockClient (200/404/500/JSON inválido/red) |
| 2 | PokemonRepository (caché) + RandomPokemonPicker | caché, rango id, count 1 vez, errores |
| 3 | PokedexController (paginación 20, detalles en paralelo) + PokedexScreen grid de cartas | transiciones estado, loadMore sin duplicar, hasMore, retry |
| 4 | PokeGame, mapa, Ash placeholder, teclado (flechas/WASD) + D-pad, límites, cámara | flame_test movimiento/límites |
| 5 | Humo, colisión, GameController, EncounterHandler, stub diálogo, overlays, README contrato | controller flujo/error/doble disparo/stream; colisión |

## Progreso
- [x] Plan aprobado (2026-09-16). Random opción A.
- [x] Fase 0 (2026-09-16): deps añadidas, lints estrictos (strict-casts, strict-raw-types,
      require_trailing_commas, prefer_single_quotes…), `app/app.dart` (AppRoutes: `/`, `/game`, `/pokedex`),
      `app/dependencies.dart` (providers vacío; MultiProvider solo si no está vacío),
      `MainMenuScreen` (Keys `menu_play`, `menu_pokedex`), GameScreen/PokedexScreen placeholders.
      `test/widget_test.dart`: 3 tests. analyze 0 issues, tests OK.
- [x] Fase 1 (2026-09-16): `models/json_reader.dart` (extension con readInt/readString/readMap/readObjectList…
      que lanza FormatException), `Pokemon` (fromJson ordena types por slot; imageUrl = official-artwork ??
      front_default; toJson round-trip; ==/hashCode), `PokemonType` (enum + unknown), `NamedResource` (getter id
      desde url), `PagedResult<T>`, `LoadState<T>` sealed (LoadIdle/LoadInProgress/LoadSuccess/LoadFailure).
      `services/poke_api_exception.dart` sealed: Network/NotFound/Server(statusCode)/Parse.
      `PokeApiService({required client, baseUri, timeout})`: fetchPokemon(id), fetchPokemonPage(offset,limit),
      fetchSpeciesCount(). Constructor usa `this._client` (private named param, parámetro se llama `client`).
      Tests: test/fixtures/(bulbasaur, no_artwork, pokemon_page .json + fixture_loader.dart), models/, services/.
      28 tests OK, analyze 0.
- [x] Fase 2 (2026-09-16): `services/pokemon_repository.dart`: interfaz `PokemonRepository`
      (getPokemon, getPokemonPage, getSpeciesCount) + `CachedPokemonRepository({required service})` que cachea
      Futures (dedup concurrentes, errores se desalojan), `clear()`. `services/random_pokemon_picker.dart`:
      `RandomPokemonPicker({required repository, Random? random})`, `pick()` y `pickId(count)` = nextInt(count)+1
      (count<1 → PokeApiParseException). Tests: pokemon_repository_test (MockClient contando requests),
      random_pokemon_picker_test (_FakeRepository, _FixedRandom). 41 tests OK, analyze 0.
- [x] Fase 3 (2026-09-16): `controllers/pokedex_controller.dart` (pageSize 30; páginas = ids contiguos
      1..speciesCount con getPokemon en paralelo; getters items/total/isLoading/error/hasMore/isInitialLoading/
      hasInitialError; loadInitial (idempotente), loadMore (no reintenta tras error), retry; no notifica tras
      dispose). `app/dependencies.dart`: `AppDependencies.create({PokemonRepository? repository})` →
      Provider<PokemonRepository> + ChangeNotifierProvider<PokedexController> (app-wide).
      `views/common/pokemon_formatters.dart` (displayName, dexNumber, errorMessage en español, extension
      PokemonTypeStyle color/label). `views/pokedex/widgets/pokemon_card.dart` (carta estilo Clash Royale).
      `views/pokedex/pokedex_screen.dart`: CustomScrollView + SliverGrid, skeletons, error full-screen con retry
      (Key `pokedex_retry`), footer (spinner/error/“¡Pokédex completa!”), scroll infinito (umbral 600px + chequeo
      post-frame si no llena la pantalla). Tests: `test/fakes/fake_pokemon_repository.dart` (failNext, gate
      Completer), `test/controllers/pokedex_controller_test.dart`, widget_test usa repo falso. 51 tests, analyze 0.
      TEMP-PREVIEW eliminado (la fase ya es visible por sí misma).
- [x] Fase 4 (2026-09-16): `game/config/world_config.dart` (1600x1200, tile 48, Ash 32x40, speed 180).
      `game/input/movement_input.dart` (keyboard + pad vectors, pad gana, normalizado, `enabled` para pausar,
      `directionFromKeys` flechas/WASD, `isMovementKey`). `game/input/keyboard_movement_component.dart`
      (KeyboardHandler → MovementInput). `game/visuals/ash_visual.dart` (enum Facing, interfaz `AshVisual
      implements Component { updateState(facing,isMoving) }`, `AshPlaceholderVisual` con canvas).
      `game/components/ash_component.dart` (anchor center, mueve speed*dt, clamp a bounds, facing; visual
      inyectable). `game/components/map_component.dart` (pasto a cuadros, caminos, árboles/flores con Random(7)).
      `game/poke_game.dart` (FlameGame + HasKeyboardHandlerComponents [import flame/events.dart]; world: map, ash,
      keyboard; camera.follow + setBounds(Rectangle [flame/experimental.dart], considerViewport)).
      `views/game/widgets/d_pad.dart` (Listener pointer down/up), `views/game/game_screen.dart` (game creado 1 vez
      en State; Stack GameWidget + DPad Key `game_dpad` + hint). Tests: test/game/movement_input_test.dart,
      ash_component_test.dart (testWithFlameGame). widget_test usa pump() (game loop no se asienta). 63 tests.
      Nota: Vector2 es float32 → usar closeTo(…, 1e-6).
- [x] Fase 5 (2026-09-16): `controllers/encounter/encounter_handler.dart` (EncounterOutcome, EncounterHandler
      documentado), `encounter_state.dart` (None/Resolving/Active/Failed). `controllers/game_controller.dart`
      (onSmokeReached con guard de doble disparo, retry, cancel, isPaused, lastOutcome, streams broadcast
      `encounters` y `smokeConsumed`; handler que lanza → FlutterError.reportError + fled). WorldConfig: smokeSpawns
      (SmokeSpawn id,x,y), smokeRadius 28, smokeRespawnSeconds 4. `game/components/smoke_component.dart`
      (CircleHitbox passive **isSolid: true** — sin eso cruzar el humo dispara 2 veces), Ash con RectangleHitbox
      en la parte baja. `game/visuals/smoke_visual.dart`. PokeGame: + HasCollisionDetection, ctor
      `onSmokeReached`, `smokes`, `setPaused`, `removeSmoke` (respawn con TimerComponent en punto aleatorio
      lejos de Ash). Views: `stub_encounter_handler.dart` (diálogo vía navigatorKey), `widgets/encounter_overlay.dart`,
      GameScreen puentea controller↔game. `AppDependencies` tiene `navigatorKey` y `create({repository,
      encounterHandler})`; providers RandomPokemonPicker y EncounterHandler; GameController se crea por sesión en
      la ruta `/game` de app.dart. README con contrato. Tests: game_controller_test, smoke_collision_test.
      73 tests, analyze 0. Nota tests Flame: tras add/remove usar `await game.ready()` antes de avanzar tiempo.
- [x] Fase 6 (2026-09-20): **ventanas de generaciones** (tarea pedida por el profesor:
      generaciones → pokémon por generación → detalle). `models/generation.dart` (fromJson ordena
      `pokemon_species` por número de pokédex; `speciesIds` omite referencias sin id numérico;
      toJson round-trip; ==/hashCode). `PokeApiService.fetchGenerations()` (`GET /generation?limit=50`)
      y `.fetchGeneration(id)`; los mismos dos métodos en la interfaz `PokemonRepository` y memoizados
      en `CachedPokemonRepository` (también en `clear()`).
      `controllers/generations_controller.dart`: estrena el `LoadState<T>` que ya existía sin usar;
      `load()` idempotente, `retry()`. `controllers/generation_detail_controller.dart`: mismo patrón que
      PokedexController pero acotado a los ids de la generación (pageSize 30 en paralelo,
      loadInitial/loadMore/retry, no auto-reintenta tras error).
      Vistas: `views/generations/generations_screen.dart` (Key `generations_retry`),
      `views/generations/generation_detail_screen.dart` (`static route()` que crea su propio controller,
      Key `generation_detail_retry`, reusa `PokemonCard` envuelta en GestureDetector),
      `views/pokemon_detail/pokemon_detail_screen.dart` (recibe el Pokemon ya cargado: sin controller,
      no hay nada que pedir). `_ErrorView` de PokedexScreen extraído a `views/common/error_view.dart`
      (ahora con `retryKey` para que cada pantalla tenga la suya).
      Formatters nuevos: generationLabel, generationNumeral, heightLabel, weightLabel.
      `AppRoutes.generations` + provider app-wide + botón `menu_generations` en el menú.
      Fixtures `generation.json` / `generation_list.json`. **107 tests, analyze 0.**
      Decisión del usuario: el detalle NO muestra estadísticas base — el modelo `Pokemon` no las trae y
      no se quiso tocar (implicaría fromJson/toJson/==/hashCode y sus tests). Si algún día se piden,
      ese es el trabajo.
- **TODAS LAS FASES DEL PLAN ORIGINAL COMPLETAS.** (Fase 7 en pausa; Fase 8 = 3D, en curso.)
- [ ] **Fase 7 — 2D pulido** (aprobada 2026-09-22; en ese momento se descartó el 3D — ver Fase 8, que lo retoma).
      Plan: 7a arte · 7b mapa de baldosas · 7c obstáculos + y-sorting · 7d Ash animado · 7e humo/efectos ·
      7f transición de encuentro. Arte CC0 en `assets/images/` (créditos en `assets/CREDITS.md`):
      Kenney Tiny Town (`tiny_town.png`, 12x11 baldosas de 16px, sin agua ni pasto alto real) y sodri
      (`ash.png`, 4 filas abajo/izq/der/arriba x 6 pasos de 14x22, recoloreado). Todo se dibuja x3 (tile 48).
  - [x] 7a–7d (2026-09-22): `game/art/game_art.dart` (GameArt.load + constantes TinyTown),
        `game/map/map_layout.dart` (TileKind con símbolo ASCII + walkable; parse valida; isAreaWalkable;
        walkableCells; `@` = inicio), `game/map/world_map.dart` (34x26), `game/map/tile_map_component.dart`
        (suelo SpriteBatch + objetos con priority = borde inferior; camino 9 piezas según vecinos; casas =
        bloques H). `MapComponent` = versión placeholder del mismo layout. `AshSpriteVisual`
        (SpriteAnimationGroupComponent<AshPose>). AshComponent: `canOccupy(feet)` con movimiento por ejes (se
        desliza) + priority = pies. PokeGame: `loadArt` inyectable (null en tests → placeholders; GameScreen
        pasa GameArt.load), `layout`, `worldSize`, respawn en casilla pisable. WorldConfig ya no tiene
        width/height/ashStart. 120 tests, analyze 0.
        Captura sin extensión: Chrome headless `--headless=new --use-angle=swiftshader
        --enable-unsafe-swiftshader --virtual-time-budget=15000 --screenshot=… http://127.0.0.1:5500/#/game`.
  - [ ] 7e humo con sprite/partículas y efectos · [ ] 7f transición de encuentro.
- [ ] **Fase 8 — 3D en tercera persona** (aprobada 2026-09-22; el usuario dio ejecución autónoma).
      **Leer TODO.md (subtareas), DECISIONES.md (por qué) y PROGRESO.md (cómo probar).** Motor:
      flutter_scene 0.23 (web WebGL2 + Windows Flutter GPU; el 3D de la Fase 7 se había descartado cuando no
      tenía web). 2D y 3D conviven (menú Jugar 2D / Jugar 3D, ruta /game3d).
      Arquitectura: `lib/game3d/sim` (Dart puro y testeable: World3DSim, OrbitCamera, PlayerBody,
      GrassField, WildPokemon, TrainerPose), `lib/game3d/mesh` (MeshBuilder low-poly → MeshBuffers puros;
      props, terreno, entrenador, hierba), `lib/game3d/render` (ÚNICA capa con flutter_scene, detrás de la
      interfaz SceneRenderer; en tests FakeSceneRenderer porque no hay GPU). Sim en mano derecha, motor en
      mano izquierda: conversión en MeshBuffers.toEngineSpace / _toEngine (Z invertida).
      Verificación visual: puppeteer en scratchpad (drive.mjs) con GPU real (GPU=1 → ANGLE d3d11).
      Hecho: 8.0–8.10 (mundo, entrenador, hierba, Pokémon visibles, captura lanzando Poké Balls, sigilo,
      campo) y casi toda la 8.11 (escondidos en la hierba, briznas, carteles, recentrar cámara, nubes).
      Luego 8.11 completa y 8.12 (marca de capturado, arbustos con bayas), 8.13–8.14 y casi toda la 8.15
      (sensación de captura y exploración; Pokémon dormidos 2026-09-28). 507 tests. El detalle, en TODO.md.

### Notas / siguiente paso
- **Vista previa por fase (pedido del usuario):** al terminar cada fase, poner un parche superficial marcado
  `TEMP-PREVIEW` para verlo en el navegador, `flutter build web`, y servir con `node tool/serve_web.mjs 8080`
  (en background; sirve build/web sin caché → basta recompilar y refrescar). Al INICIAR la fase siguiente,
  eliminar el parche anterior (`grep TEMP-PREVIEW`).
- **PUERTO 5500** (http://localhost:5500). El 8080 lo ocupa un Apache/XAMPP (`httpd`) del usuario con otro
  proyecto. El server escucha en 127.0.0.1. Si no responde, relanzarlo en background.
- TEMP-PREVIEW activo: ninguno.
- **Documentación (2026-09-20):** `Guia_del_codigo_Pokemon_Game.pdf` en la raíz del proyecto: guía de 69 páginas
  que explica todo el código desde cero (para el usuario, que no programa) + banco de preguntas y prompt de
  repaso con IA. Fuente HTML en el scratchpad de la sesión; se genera con Chrome headless + paged.js
  (puppeteer-core, esperando a que termine la paginación antes de imprimir).
- Placeholders de GameScreen/PokedexScreen tienen textos que usan los tests de navegación: al reemplazarlos, actualizar `test/widget_test.dart`.
- Proyecto en OneDrive: si hay errores "file in use" en build/, sugerir moverlo.
- Repo git creado el 2026-09-20, con un commit base del estado previo a la Fase 6.
- **Disco lleno (2026-09-20):** `flutter test` falló con "Espacio en disco insuficiente" antes de que
  se liberara espacio. Si vuelve a pasar: `flutter clean` y borrar las carpetas
  `%TEMP%\flutter_tools.*` que no estén en uso (son caché, se regeneran). Volvió a pasar el 2026-09-25:
  si luego sale "Can't load Kernel binary: Invalid SDK hash", borrar `.dart_tool/hooks_runner`.
- Scripts de vista previa (preview_on.sh / preview_off.sh, drive2.mjs, sheet.mjs, diff.mjs) en
  `%TEMP%\claude\C--Users-omarb-OneDrive-Escritorio-pokemon-game-copia\547de651-…\scratchpad` (con
  node_modules de puppeteer-core). URL: `?sure`, `?card`, `?crit`, `?hide`, `?sign`, `?cloud`, `?town`, `?bush` (delante del arbusto 26,10).
  **Con la vista previa puesta NUNCA `dart format lib`** (parte las líneas TEMP-PREVIEW): formatear
  solo `lib/game3d lib/game test`, o quitar antes la vista previa. preview_off.sh sale con código 1
  (su grep -c da 0): no encadenarlo con &&.
