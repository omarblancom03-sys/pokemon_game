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
- **2026-09-23 — Mariposas:** una por macizo de flores (`,`), máx. 12 y separadas ≥ 5 m. Revolotean
  sobre sus flores (radio 1,3 m, 0,35–1,3 m de alto) y huyen hacia arriba y lejos del jugador si se
  acerca: 4,5 m corriendo, 2,6 m andando, 1 m agachado; quieto solo si estás pegado. Mismo lenguaje
  que el sigilo de los Pokémon (el jugador aprende que agachado se acerca más). Se dibujan con tres
  mallas instanciadas (ala izq., ala der., cuerpo); la transformación de simulación pasa al motor con
  F·M·F (F = invertir Z). Dibujadas a ×1,6 para que se vean. Azar propio (semilla fija).
- **2026-09-23 — Texto del bonus al golpear:** la bola guarda cómo fue el golpe (`ThrownBall.hit`:
  sin ser visto / por la espalda) y cuándo (`sinceHit`); la capa 2D pinta "¡No te vio! ×1,5" y
  "¡Por la espalda! ×2" (los números salen de CaptureCalculator) a media altura del Pokémon, sube
  40 px y se apaga en 1,6 s, con fondo oscuro para leerse sobre cualquier cosa. Si no hubo bonus no
  se enseña nada (solo refuerzo positivo). Enseña al jugador POR QUÉ el sigilo ayuda.
- **2026-09-23 — Vista previa sin ensuciar el repo:** el parche TEMP-PREVIEW (jugador junto al prado
  y un Pokémon de espaldas 8 m delante) se guarda como `preview.patch` en el scratchpad y solo se
  aplica para compilar la web; se revierte antes de probar y hacer commit.
- **2026-09-23 — Botón de la bola:** se enciende en rojo durante cada sacudida (seno de la
  sacudida: sube y baja) y se apaga en la pausa entre sacudidas; al capturar, un destello blanco
  de 0,35 s ("¡clic!"). Además un halo rojo suave alrededor de la bola (la bola es pequeña y en
  la hierba alta casi no se veía el botón solo). Los valores (`buttonGlow`, `clickFlash`) son
  puros en ThrownBall y tienen test; el renderer solo los pinta.
- **2026-09-23 — Estela de la bola:** la bola guarda sus últimos 12 puntos de vuelo (cada 0,3 m;
  `ThrownBall.trail`, con test); al dejar de volar (golpe o primer bote) se acorta un punto por
  fotograma hasta desaparecer. Se pinta con UNA malla instanciada compartida por todas las bolas
  (bolitas sin luz semitransparentes, con un punto intermedio entre cada dos para que parezca una
  línea), del color de la bola: roja, azul o amarilla, más gruesa y opaca cerca de la bola.
- **2026-09-23 — Tarjeta de captura y "Mis capturas":** una captura ya no es un aviso pequeño sino
  una tarjeta (arte oficial, nombre, número, tipos, bola usada y "¡Nuevo!" si es la primera de su
  especie: `FieldNotice.isNew`, lo decide el controlador antes de registrar la captura). El panel
  "Mis capturas" (tecla P o tocar "Capturados") reutiliza la carta de la Pokédex con la bola en la
  esquina; mientras está abierto el mundo se congela (`_capturesOpen` entra en `_syncPause`, así un
  encuentro que termine no lo descongela) y se sueltan apuntar y las teclas de cámara.
- **2026-09-23 — Vista previa: script, no parche git.** Un `git diff` regenerado arrastró cambios
  sin commit y un `git checkout` los quitó (se recuperaron del parche). Ahora `preview_on.sh` inserta
  líneas marcadas `// TEMP-PREVIEW` y `preview_off.sh` las borra con `sed`; nunca `git checkout` ni
  `dart format` con la vista previa puesta. URL: `?sure` (ratio 255) y `?card` (captura a los 9 s).
- **2026-09-23 — Captura crítica (como en los juegos desde la 5.ª generación):** antes de las
  comprobaciones se tira un dado de crítico; si sale, hay UNA sola comprobación (probabilidad
  p^(1/4) en vez de p) y la bola se sacude una vez, más fuerte. La probabilidad depende de la
  experiencia: 2 % por especie distinta capturada, máx. 25 % (con 0 especies nunca). Con
  probabilidad 0 no se tira el dado, así el azar de siempre no cambia. La pone la pantalla en la
  simulación desde el TrainerController (`_syncTrainer`, junto a la bola elegida). Efectos: destello
  y botón dorados, "¡Captura crítica!" sobre el Pokémon al golpear y en la tarjeta. El % del anillo
  de la mira sigue siendo la probabilidad normal (el crítico es una sorpresa, como en los juegos).
- **2026-09-25 — Pokémon escondidos en la hierba alta ("hierba que se agita").** El 35 % de los que
  aparecen solos lo hacen escondidos (`WildPokemon.hidden`): no se dibujan, la mira no los fija, no
  salen en el minimapa ni apartan la hierba; en su lugar la hierba de alrededor (1,5 m) se sacude a
  ráfagas (`GrassField.rustleBurst`, ~40 % del tiempo y distinto en cada sitio, para que llame la
  atención sin ser constante). No se mueven ni te buscan. Salen a una distancia según lo que se te
  note (`World3DSim.revealDistance`): corriendo 6,5 m, andando 4 m, agachado 2,2 m, agachado en la
  hierba 1,6 m, quieto 1,2 m. De pie salen ASUSTADOS (mirándote, en alerta, reaccionan según su
  carácter); agachado se ASOMAN distraídos y mirando hacia otro lado: premio al sigilo (se les puede
  lanzar por la espalda y sin ser visto). Una bola que cae a < 4 m los hace salir asustados; si la
  bola da de lleno en uno escondido, lo captura por sorpresa (cuenta como "no te vio"). Si nadie
  los encuentra en 60 s, se van (deja sitio a otro). Aviso en pantalla distinto para cada caso
  (evento `PokemonRevealed(startled)` → `FieldNoticeKind.burstOut` / `peeked`).
- **2026-09-25 — La sacudida sola no basta para verse de lejos**: en capturas se confunde con el viento
  (todas las matas se mecen). Se refuerza en la tarea siguiente con briznas que saltan de la mata.
- **2026-09-25 — Disco lleno otra vez.** Con 235 MB libres `flutter analyze` no podía ni crear hilos y
  `flutter build web` falló con "Can't load Kernel binary: Invalid SDK hash": los `hook.dill` de
  `.dart_tool/hooks_runner` quedaron corruptos al escribirse sin espacio. Solución: borrar `build/`,
  cachés viejas de %TEMP% (`flutter_tools.*`, perfiles HeadlessChrome) y `.dart_tool/hooks_runner`
  (se regenera solo).
- **2026-09-25 — Briznas de hierba** (`sim/grass_blades.dart`, como el polvo: Dart puro, azar propio
  con semilla fija, máx. 48, una malla instanciada). Al pisar la hierba alta: 3 por pisada corriendo,
  1 andando, 0 agachado (mismo lenguaje que el sigilo: se VE el ruido que haces). Sobre un Pokémon
  escondido, la mata escupe briznas grandes (0,34 m) y más claras mientras se agita (hasta 14/s en
  lo más fuerte de la ráfaga); al salir de un salto, un surtidor de 12. Física: gravedad 6 m/s² y
  rozamiento asimétrico (0,8/s subiendo: salen disparadas por encima de la hierba, que mide ~0,6–0,9
  m; 3/s bajando: caen planeando a ≤ 2 m/s). Al tocar el suelo se quedan quietas y se encogen en
  0,4 s (sin transparencias). Con un rozamiento único las briznas no pasaban de 0,66 m: quedaban
  escondidas dentro de la propia hierba (lo detectó un test).
- **2026-09-25 — Sacudida de la hierba reforzada** tras mirarla en el navegador: radio 1,8 m (antes
  1,5) y 0,7 rad (antes 0,5). En capturas fijas se ve moderada; en movimiento destaca porque vibra a
  2,5 Hz y el viento va lento. La pista principal a distancia son las briznas claras que saltan.
- **2026-09-25 — Vista previa `?hide`:** Pokémon escondido 4 m delante del jugador (casilla 24,9, sin
  árboles delante). Para ver movimiento en capturas fijas: `diff.mjs` (mapa de cambios entre
  fotogramas, `TH` = umbral) y `crop.mjs` (recorte ampliado) en el scratchpad.
- **2026-09-25 — Carteles que se leen.** La simulación solo sabe QUÉ cartel (casilla `s`):
  `sim/signs.dart` (`SignReader`) elige el más cercano a ≤ 2,6 m del centro de su casilla y a ≤ 80°
  de hacia donde mira el jugador; leer abre/cierra; alejarse a > 3,6 m lo cierra; con el mundo
  congelado no se lee. LO QUE PONE es contenido del mapa, junto al dibujo ASCII:
  `game/map/world_signs.dart` (mapa casilla → título y texto; un `s` sin texto se lee "gastado";
  un test obliga a que cada cartel tenga el suyo y a que no sobre ninguno). La vista
  (`widgets/sign_panel.dart`) mira la simulación en cada fotograma y solo se reconstruye si cambia.
  Tecla **L** ("leer") o Intro: la E ya gira la cámara. No congela el mundo (se lee de un vistazo).
- **2026-09-25 — Tres carteles nuevos en el mapa** (compartido con el 2D): (21,10) entrada al prado,
  (14,15) junto a la hierba del sur y (20,17) junto a la casa del sur. Sirven de TUTORIAL dentro del
  juego (sigilo, hierba que se agita, bolas). Están en casillas libres junto a los caminos: no tapan
  ningún paso ni los humos del 2D.
- **2026-09-25 — Recentrar la cámara:** tecla **V** ("vista") y un botón táctil junto a agacharse y
  apuntar. La cámara gira SOLA hasta quedar detrás de hacia donde mira el jugador en ese momento
  (`OrbitCamera.recenterBehind`: yaw = facing + π), por el camino más corto y con suavidad
  (~0,3 s, sin tirón). Solo cambia el giro horizontal: la inclinación la eligió el jugador y la usa
  el tiro "a ojo". Girar a mano (arrastrar, Q/E) lo cancela al instante; el zoom no. No se añade
  cámara automática que se recoloque sola al andar: la cámara la manda el jugador (decisión del
  22-09).
- **2026-09-25 — Nubes en dos bandas** (`sim/clouds.dart`, Dart puro, azar propio): 16 ENCIMA del
  mapa (a 40 m, radio 6–10 m) de las que solo se ve la SOMBRA, y 30 LEJANAS (50–80 m de altura,
  hasta 260 m del mapa) que son las que se ven en el cielo. Motivo: con los límites de la cámara
  (inclinación mínima 0,12 rad, campo vertical 55°) el borde de arriba de la pantalla queda a ~20°
  sobre el horizonte, así que una nube a 40 m de altura solo se ve si está a más de ~110 m: las
  que dan sombra en el mapa nunca se ven. Todas van con el mismo viento que la hierba (+X) y la que
  sale de su zona entra por el otro lado. Cada nube guarda dónde cae su sombra y la nube se coloca en
  la línea del sol (`World3DConfig.sunDirection`, la misma dirección que usa la luz de la escena).
- **2026-09-25 — Sombra de nube = disco negro semitransparente** a 0,1 m del suelo (a 0,05
  parpadeaba con las losas del camino), con el borde difuminado en el último cuarto del radio.
  Las nubes se dibujan SIN luz (con luz, la tripa quedaba gris de tormenta) y algo por encima de 1
  para que se vean blancas.
- **2026-09-25 — flutter_scene, alfa en mallas instanciadas SIN luz** (comprobado con experimentos en
  el navegador): el alfa POR VÉRTICE sí llega, pero atenuado (0,5 oscurece como ~0,2: parece tratarse
  como un color sRGB), por eso la sombra usa 0,72 en el centro. El alfa POR INSTANCIA se ignora si
  `vertexColorWeight = 0`. El alfa del `baseColorFactor` funciona tal cual.
- **2026-09-25 — Lección: nunca `dart format lib` con la vista previa puesta.** Partió las líneas
  TEMP-PREVIEW en varias sin la marca; se arregló restaurando el archivo desde HEAD (el diff solo
  tenía la vista previa). Con la vista previa puesta, formatear solo `lib/game3d`, `lib/game` y
  `test`. Nuevas opciones de la vista previa: `?cloud` (sombra delante) y `?town` (lejos de la
  hierba, para que ningún Pokémon agresivo interrumpa las capturas).
- **2026-09-25 — Pájaros** (`sim/birds.dart`, Dart puro, azar propio; 3 mallas instanciadas como
  las mariposas). 2 bandadas de 5 posadas en casillas abiertas (ni hierba alta ni obstáculos, con
  las 4 vecinas libres para que quepa el corro) a > 15 m del jugador. En el suelo picotean (55 %) o
  dan saltitos de 0,25 m sin alejarse más de 1,4 m de su bandada; alas plegadas. Se espantan
  (TODA la bandada, cada pájaro con 0–0,35 s de retraso) si el jugador pasa cerca — corriendo 8 m,
  andando 5 m, agachado 2,2 m, quieto 1,2 m: el mismo lenguaje de sigilo que los Pokémon y las
  mariposas — o si cae una Poké Ball a < 5 m. Entonces eligen otro sitio a > 16 m del jugador y,
  de 6 al azar, el más al lado contrario; suben a un punto alto a medio camino (10 m) aleteando
  deprisa, allí alternan aletear y planear, y bajan frenando hasta posarse. El vuelo es un
  "steering" simple (velocidad deseada con aceleración máxima 14 m/s²). Vista previa: `?town&birds`.
- **2026-09-25 — Marca de "ya capturado"** (como en Leyendas Arceus): la capa 2D recibe
  `isCaught` (= `TrainerController.hasCaught`, por número de Pokédex) y pinta una Poké Ball
  pequeña sobre los Pokémon que se ven a ≤ 22 m (`World3DSim.visibleWildNearby`: libres, no
  escondidos). Al apuntar, el fijado lleva además su nombre encima del anillo (debajo si no cabe) y
  "¡Nuevo!" en dorado si no tienes la especie. La simulación no sabe nada del entrenador: solo
  filtra quién se ve cerca; la decisión de marcar es de la vista con el dato del controlador.
- **2026-09-25 — Nuevas tareas (8.12 y 8.13)** al acabar la 8.11, siguiendo el enfoque pedido
  (atrapar y explorar): más estrategia de captura (bayas para distraer, como en Leyendas Arceus,
  recogidas de los arbustos con bayas que ya hay en el mapa) y detalles de exploración.

- **2026-09-25 — Arbustos con bayas** (`sim/berries.dart`, Dart puro). Una sola baya: la **Baya
  Frambu** (Razz Berry: en los juegos es la que ayuda a capturar). Cada arbusto (`b`) empieza con 3
  bayas colgando y le crece UNA cada 40 s hasta volver a 3 (con un pequeño "pop"). Se sacude con la
  **tecla de acción L / Intro** (la misma de los carteles: una sola tecla para "usar lo que tengo
  delante"; si hay cartel y arbusto a mano, el más cercano) o tocando el aviso "Sacudir el arbusto",
  que enseña cuántas bayas le quedan. Mismo alcance que los carteles (2,6 m y mirándolo); la lógica
  común está en `sim/reach.dart` (`nearestInReach`). Al sacudirlo se balancea 0,7 s (no se puede
  repetir mientras), se le caen unas hojitas (briznas) y TODAS sus bayas saltan y caen a los pies
  del jugador (entre él y el arbusto, nunca dentro de una casilla que no se pisa), botan y, cuando
  llevan 0,25 s quietas, se recogen al pasar (radio 1,1 m, como las bolas). Las que nadie recoge se
  pudren a los 2 min. Recoger varias seguidas junta el aviso ("+3 Bayas Frambu" y no tres "+1": lo
  decide el FieldController). Sacudir un arbusto vacío avisa ("le vuelven a crecer").
- **2026-09-25 — Sacudir hace ruido** (mismo lenguaje que el sigilo): los Pokémon tranquilos a < 7 m
  se ponen en "?" (sospecha 0,6) y se giran; los escondidos a < 4 m salen asustados; los pájaros
  cercanos se van. Así coger bayas junto al prado tiene un precio.
- **2026-09-25 — Arbustos fuera de la malla única:** para que se balanceen, cada arbusto es su propio
  nodo (`BushRenderer`) con sus bayas como hijos (`buildProps(..., bushes: false)`). Son pocos (6).
  La forma del arbusto (`bushLeafBalls`) vive en la simulación porque también decide dónde cuelgan
  las bayas (justo por fuera de las hojas); la malla la usa desde ahí.
- **2026-09-25 — Dos arbustos nuevos en el mapa** (compartido con el 2D): (26,10) al sur del prado del
  noreste y (10,23) bajo el prado del suroeste. Los 4 que había estaban en el pueblo, lejos de los
  prados donde se usarán las bayas. No tapan caminos ni humos del 2D.
- **2026-09-25 — `SignPanel` pasa a `ActionPanel`** (`widgets/action_panel.dart`): enseña lo que haría
  la tecla de acción (leer el cartel o sacudir el arbusto) y el cartel abierto.
- **2026-09-25 — Lanzar bayas con el mismo gesto que las bolas.** En la mano va una bola O una baya
  (`TrainerController.berrySelected`): tecla **4**, **R** (Poké → Super → Ultra → baya, saltando lo que
  no tengas) o tocar la baya en la bolsa; elegir una bola la guarda. Apuntar y lanzar son los mismos
  controles; el botón de lanzar enseña la baya. Al lanzar la última baya se vuelve a la bola; quedarse
  sin bolas NO pone una baya en la mano (sería un cambio por sorpresa), salvo que no tengas ninguna
  bola cuando recoges bayas.
- **2026-09-25 — Física de la baya lanzada** (en `BerrySystem`, no en `BallSystem`: las bolas llevan un
  tipo de Poké Ball y su secuencia de captura). Misma gravedad (14 m/s²) y mismo radio que una bola, así
  que el arco previsto de las bolas (`BallSystem.predict`, sin Pokémon) vale para la baya. Sale más
  floja (11 m/s en vez de 15, "en globo"): llega a unos 9–10 m, hay que acercarse. Con un objetivo
  fijado cae en `baitSpot`: 1,4 m por delante del Pokémon, del lado del jugador (a mitad de camino si
  está más cerca de 2,8 m), para que la vea sin darle; sin objetivo, "a ojo" como una bola. No choca
  con los Pokémon (se lanza cerca, no a ellos); sí rebota en árboles y casas. Una baya que queda donde
  no se pisa se lleva a la casilla libre más cercana. En el suelo se puede volver a recoger.
- **2026-09-25 — Sin probabilidad con la baya en la mano:** el anillo de la mira sigue marcando el
  objetivo (y su nombre), pero sin %: una baya no captura.
- **2026-09-25 — Bayas para distraer** (como la comida de Leyendas Arceus). Un Pokémon TRANQUILO
  (sin "!"; si tenía "?" se le pasa: la sospecha baja a 0,2) huele la baya libre más cercana del
  suelo a ≤ 10 m, se la queda (nadie más va a por ella y el jugador ya no puede recogerla), va a
  por ella a 2 m/s rodeando obstáculos y se la come quieto y mirándola durante 6 s (mengua a
  mordiscos); luego desaparece. Aviso "¡X se está comiendo la baya! Aprovecha". Mientras COME: no
  ve (solo si lo tocas) y oye a un 35 % de lo normal (correr a < 5 m sí lo oye). Si te descubre,
  deja la baya a medio comer para otro. Si en 15 s no llega (atascado), se rinde. Dentro de una bola
  deja de comer. Una baya que cae a < 3,5 m de un escondido lo hace ASOMARSE sin verte (viene a
  comer).
- **2026-09-25 — La baya cae POR DETRÁS del Pokémon fijado** (1,4 m más allá, del lado contrario al
  jugador). Primero se probó delante (entre los dos): al girarse para ir a por ella te miraba y te
  veía. Detrás, se da la vuelta y come de espaldas: la jugada es "baya detrás → se gira → bola por la
  espalda" y el golpe suma los tres bonus (sin ser visto ×1,5 o por la espalda ×2, y comiendo ×1,5).
- **2026-09-25 — "¡Está comiendo!" ×1,5 se MULTIPLICA con el sigilo** (el sigilo sigue siendo
  "sin ser visto" ×1,5 o "por la espalda" ×2, sin sumarse entre ellos). Como la Baya Frambu de los
  juegos. Se enseña al golpear ("¡Está comiendo! ×1,5", en rosa) y ya cuenta en el % del anillo.
- **2026-09-25 — Nadie va a por una baya a < 3,5 m del jugador.** Lo detectó la vista previa: las
  bayas que un arbusto suelta a tus pies atraían a un Pokémon a 9 m, que venía hacia ti y te veía.
  Un Pokémon salvaje no se acerca tanto a una persona; y así las del arbusto son para ti.
- **2026-09-25 — Señales de las bayas:** bocadillo blanco con una baya sobre el Pokémon que va a por
  una (late con cada mordisco mientras come) y el dibujo se achata un poco con cada mordisco
  (`WildPokemon.munch`, ~3 por segundo). Vista previa `?bait` (junto al prado del noreste, 3 bayas en
  la mano, Pokémon 8 m delante y de espaldas).
- **2026-09-25 — TODO 8.14 lo añadió el usuario** (diversión sin quitar protagonismo a los
  combates: todo opcional, nada da niveles). Se respeta ese principio en lo que se haga de ahí.
- **2026-09-25 — Mapa grande** (tecla **M** o tocar el minimapa). Lo que se marca lo decide
  `sim/map_overview.dart` (`MapOverview.of(sim)`, Dart puro y con tests); la vista
  (`widgets/big_map.dart`) solo pinta. Norte arriba (el minimapa ya gira con la cámara; aquí se
  quiere un mapa fijo para orientarse). Lo FIJO o que brilla de lejos sale en todo el mapa (carteles,
  arbustos con sus bayas, Poké Balls y bayas del suelo); los Pokémon SOLO dentro del radio del
  minimapa (26 m) y nunca los escondidos: el mapa es para orientarse, no para encontrar Pokémon sin
  buscarlos. Congela el mundo como "Mis capturas" (un solo `_openPanel` para los dos) y, como está
  congelado, se pinta una sola vez. El dibujo del suelo (`recordMapTiles`) y los colores
  (`MapColors`) pasan a `widgets/map_tiles.dart`, compartidos por el minimapa y el mapa grande.
