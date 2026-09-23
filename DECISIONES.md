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
