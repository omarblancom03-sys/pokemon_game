# DECISIONES — Fase 8 (3D)

Registro de decisiones tomadas durante la ejecución autónoma (fecha + motivo).

- **2026-09-22 — Motor: flutter_scene.** La versión 0.23 soporta Flutter 3.47 stable, web (WebGL2, sin
  flags) y Windows (Flutter GPU). flame_3d no soporta Windows; three.js en WebView no es testeable.
  Respaldo si falla: renderer propio sobre `Canvas.drawVertices`. El motor queda aislado detrás de una
  interfaz para poder cambiarlo.
- **2026-09-22 — Se mantienen 2D y 3D** (decisión del usuario). Comparten MapLayout, GameController,
  EncounterHandler, repositorio y picker.
- **2026-09-22 — Cámara:** arrastrar con ratón + rueda (zoom) + Q/E (decisión del usuario).
- **2026-09-22 — Sin humo en 3D** (el usuario dio libertad de diseño): Pokémon salvajes visibles en la
  hierba alta + encuentros aleatorios al caminar por ella + combate por turnos con captura.
- **2026-09-22 — Plataformas:** web + Windows (decisión del usuario).
- **2026-09-22 — Spike 8.1 OK en web.** flutter_scene dibuja cubo + sombra en Chrome (WebGL2). En
  `flutter test` no hay GPU ("Flutter GPU requires Impeller") → el motor se inyecta con la interfaz
  `SceneRenderer` (provider en AppDependencies; los tests pasan `FakeSceneRenderer`).
- **2026-09-22 — Windows no verificable aquí.** `flutter build windows` falla: "Unable to find suitable
  Visual Studio toolchain" (no hay Visual Studio en esta máquina). El runner ya activa Flutter GPU
  (`project.set_enable_flutter_gpu(true)` en `windows/runner/main.cpp`). Para probar en Windows:
  instalar Visual Studio con "Desarrollo para el escritorio con C++" y `flutter run -d windows`.
- **2026-09-22 — `dart run flutter_scene:init`** creó `hook/build.dart` y `flutter_scene_generated/`.
  Se añadieron `vector_math` y `hooks` como dependencias directas (los importan nuestro código y el hook).
- **2026-09-22 — Test flaky observado:** `smoke_collision_test` falló una vez mientras se compilaba web en
  paralelo (máquina cargada); repetido aislado y en suite completa pasa. No ejecutar builds y tests a la vez.
- **2026-09-22 — Mano izquierda.** flutter_scene usa coordenadas de mano izquierda (la primera captura
  salió espejada). La simulación sigue en mano derecha y la conversión ocurre en UN sitio:
  `MeshBuffers.toEngineSpace()` (Z invertida + triángulos al revés) y `_toEngine` en `Scene3DView`
  (posiciones, cámara, luz; el giro del jugador cambia de signo).
- **2026-09-22 — Suelo plano (y = 0).** Relieve descartado por ahora: física exacta y simple, y el
  mapa ASCII ya da variedad. Se puede añadir relieve en los bordes del mapa más adelante.
- **2026-09-22 — Verificación visual con puppeteer** (`scratchpad/drive.mjs`): pulsa teclas, arrastra y
  captura. En swiftshader va a pocos FPS y el `dt` se limita a 0.1 s, así que en capturas el
  jugador avanza lento; la dirección es correcta. La primera tecla tras navegar a veces se pierde en
  web headless (foco); no afecta al uso real.
- **2026-09-22 — Test flaky de 2D corregido.** `smoke_collision_test` dejaba la dirección (1,0) pulsada:
  durante `update(1.1)` Ash andaba ~198 px DESPUÉS de elegirse el punto del humo nuevo y a veces quedaba
  a < 200 px. Se suelta la entrada (`input.clear()`) antes de avanzar el tiempo. No era un fallo del juego.
- **2026-09-22 — Mundo en una sola malla.** Todos los objetos fijos (árboles, casas, vallas, bosque exterior)
  se generan con `MeshBuilder` en una única malla con colores por vértice: una llamada de dibujo, ideal para
  web. Aspecto "stylized" (ACES, saturación 1.2, bloom suave, niebla ligera, IBL al 55 %).
- **2026-09-22 — Pokémon salvajes = carteles con el arte oficial** (`imageUrl` = official-artwork de
  PokeAPI) sobre `UnlitMaterial` con alfa, siempre mirando a la cámara, con sombra redonda. Los bytes los
  baja `ImageBytesService` (capa de servicios, con caché y tests); el renderer solo decodifica y sube la
  textura. Tamaño exagerado (`altura·1.3 + 0.5`, entre 1.1 y 3.2 m) para que no desaparezcan en la hierba.
- **2026-09-22 — Encuentros 3D reutilizan GameController.** Nuevos métodos: `onWildEncounter(id, pokemon)`
  (sin descarga: el Pokémon ya se ve), `onGrassEncounter()` (id `grass-N`, mismo flujo que un humo) y
  `pickWildPokemon()` (null si falla la red). El flujo 2D no cambia.
- **2026-09-22 — Hierba alta con InstancedMesh** (≈750 matas en una llamada de dibujo), inclinación por
  viento + empuje calculada en Dart puro (`GrassField.tiltFor`, testeado). Sin sombras propias (costaban
  redibujar las matas en cada cascada).
- **2026-09-22 — vector_math:** `Quaternion.rotated` gira al REVÉS que `Matrix4.compose` con el mismo
  cuaternión. El motor usa la matriz; en tests hay que comprobar con la matriz.
- **2026-09-22 — Medición de rendimiento:** swiftshader da ~0,3 FPS (no sirve para medir). Chrome headless
  con `--use-angle=d3d11 --enable-gpu --ignore-gpu-blocklist` usa la GPU real: 32–40 FPS con todo el mundo.
