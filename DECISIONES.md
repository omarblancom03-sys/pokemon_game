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
- **2026-09-22 — CAMBIO DE ALCANCE (pedido del usuario).** El combate lo hace otro equipo. Nos quedamos
  solo con capturar (Poké Balls en el campo + lanzarlas) y andar por el campo. Se descarta la Fase 8.6 de
  combate (no se llegó a escribir código). El contrato EncounterHandler sigue siendo el punto de enganche
  del combate: en 3D solo se dispara si un Pokémon AGRESIVO y alerta alcanza al jugador.
- **2026-09-22 — Captura estilo Leyendas Arceus:** se lanza la Poké Ball directamente en el mundo. Sin
  combate no hay PS, así que la probabilidad sale del ratio de captura real de la especie (PokeAPI
  pokemon-species), del tipo de bola y del sigilo (sin ser visto ×1,5; por la espalda ×2).
- **2026-09-22 — Sin encuentros aleatorios en la hierba en 3D:** con Pokémon visibles y captura en el
  mundo, interrumpían el juego. El código queda (flag), desactivado por defecto.
- **2026-09-23 — Controles de captura:** clic derecho mantenido o F = apuntar (cámara al hombro, mira,
  arco previsto); clic izquierdo o Espacio = lanzar; R / 1-3 = cambiar de bola. En táctil, botones
  "Apuntar" (se queda activo) y "Lanzar". En web se desactiva el menú contextual del navegador
  mientras se juega. El ratón es UN puntero: pulsar un segundo botón no genera un "down" nuevo, por
  eso la pantalla sigue las transiciones de la máscara de botones.
- **2026-09-23 — Ayuda al apuntar:** la mira fija al Pokémon libre más centrado en un cono de ±20° y
  a ≤ 17 m (alcance real del tiro), incluso sin apuntar (se ve una flechita). Con objetivo fijado el
  tiro es una parábola exacta que se adelanta a su movimiento; sin objetivo, "a ojo" hacia donde mira
  la cámara (su inclinación decide la altura del arco).
- **2026-09-23 — Se muestra la probabilidad de captura (%)** en el anillo de la mira, con color
  (rojo → verde). Leyendas Arceus no la enseña, pero aquí explica la mecánica (ratio de la especie,
  bola, sigilo) y ayuda a defender el proyecto.
- **2026-09-23 — Reglas de las bolas:** solo cuenta el golpe DIRECTO (tras rebotar ya es fallo); una
  bola fallada queda en el suelo y se puede recoger; si el Pokémon se escapa, la bola se pierde (como
  en los juegos). El resultado se decide en el momento del golpe; lo demás es animación con tiempos
  fijos (absorber 0,55 s, sacudidas 1,2 s cada una).
- **2026-09-23 — La simulación usa CaptureCalculator** (lib/controllers/capture) directamente: es
  lógica pura, sin estado de interfaz; se inyecta en World3DSim para poder forzar resultados en tests.
- **2026-09-23 — Avisos del campo = datos, no texto.** FieldController guarda qué pasó (tipo, bola,
  Pokémon, sacudidas) y la vista compone la frase en español (noticeText). MVC estricto.
- **2026-09-23 — Verificación visual con un parche TEMP-PREVIEW** (jugador junto al prado con un
  Pokémon delante, ratio por `?rate=`) y puppeteer con GPU (`scratchpad/drive2.mjs` entra por el menú;
  `sheet.mjs` junta capturas en una hoja). Parche retirado tras comprobarlo.
- **2026-09-23 — Sigilo (números):** vista en cono de ±60° y 13 m; oído según ruido: correr 14 m,
  andar 6 m, agachado 1,8 m, agachado en hierba alta 1,2 m, quieto 0. Agachado en la hierba alta
  solo te ven a < 2,6 m. Pegado a ellos (< 1,4 m) siempre te notan. La sospecha sube más rápido
  cuanto más cerca; con "?" se paran y se giran hacia ti; con "!" reaccionan 5 s tras perderte.
  Tras calmarse se quedan con sospecha 0,6 (no vuelven a asustarse al instante ni se olvidan).
- **2026-09-23 — Reacciones:** asustadizos huyen a 4,4 m/s (rodeando obstáculos) y a > 24 m se
  pierden (desaparecen: deja sitio a otro); curiosos se acercan a 3,2 m y se quedan mirándote (más
  fáciles de alcanzar, pero te ven: sin bonus de sigilo); agresivos cargan y, si te alcanzan, empieza
  el encuentro (EncounterHandler, el combate del otro equipo). Tocar a uno tranquilo solo lo asusta.
- **2026-09-23 — Correr te levanta** (no se puede correr agachado). Agacharse: C, Ctrl o botón táctil
  (conmutador, como en Leyendas Arceus).
- **2026-09-23 — Los encuentros al azar en la hierba quedan tras el flag `grassEncounters`** (false por
  defecto en 3D, como ya decía la decisión de 2026-09-22 pero no estaba implementado).
- **2026-09-23 — Cámara contra obstáculos:** se usan las mismas alturas por casilla que los choques de
  las bolas (`obstacleHeight`: árbol 4,5 m, casa 5 m, bosque exterior 8 m; vallas y arbustos no
  estorban a una cámara que mira desde arriba). Si algo se interpone, la cámara se acerca AL INSTANTE
  (nunca se ve a través de una pared) y se aleja a 5 m/s cuando deja de estorbar (sin tirones). Si
  de espaldas a un árbol o casa no cabe (< 2,8 m libres), en vez de meterse dentro SUBE hasta 86°
  (vista cenital, como en los juegos de plataformas) y baja despacio al salir. La inclinación elegida
  por el jugador no cambia: el tiro "a ojo" sigue usando esa.
- **2026-09-23 — Minimapa girado con la cámara** (arriba = hacia donde mira la cámara, que es también
  "adelante" en el teclado), radio 26 m, con una "N" en el borde. Marca bolas del suelo y Pokémon con
  el color de lo que saben de ti (blanco / amarillo "?" / naranja "!" / rojo que late si vienen a por
  ti): refuerza el sigilo sin tener que mirar alrededor. Las cuentas están en `sim/minimap.dart`
  (testeadas); la vista solo pinta. El mapa de casillas se graba una vez en un `ui.Picture` y se
  coloca girado en cada fotograma. La ayuda de controles pasa debajo de la bolsa (izquierda).
- **2026-09-23 — Suelo sin damero:** el damero daba aspecto de "tablero". Ahora cada casilla son 2x2
  cuadrados con color por vértice: manchas de ~6 m (±15 % de brillo), zonas de césped frondosas o
  secas de ~11 m y un granulado fino, con un ruido suave (`smoothNoise`) que solo depende de la
  posición → casillas vecinas del mismo tipo se funden sin costuras y los bordes entre tipos (camino
  / césped) siguen nítidos. Matas bajas (≤ 35 cm) en el césped y piedrecitas en el camino, dentro de
  la malla única de objetos (sin coste de llamadas de dibujo).
- **2026-09-23 — Polvo:** una nubecilla por pisada al correr (cada 0,75 m, medio ciclo de pasos, en
  el pie que toca el suelo), un corro al frenar en seco tras correr > 0,3 s y otro cuando una bola bota
  fuerte (> 2 m/s; tamaño según la fuerza). En la hierba alta no hay polvo. Lógica en
  `sim/dust.dart` (máx. 40 a la vez, la más vieja se va); se dibuja con UNA malla instanciada con 40
  huecos, material sin luz semitransparente (la opacidad va en el color de cada instancia). Usa su
  propio azar (semilla fija): es decorado y no debe cambiar el azar del juego ni de los tests.
