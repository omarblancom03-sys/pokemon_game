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
- **2026-09-25 — Ayuda de controles plegable** (`widgets/controls_help.dart`). Abierta al entrar,
  agrupada (Moverse / Cámara / Capturar / Más + un consejo de sigilo) para que ocupe ~440 px de
  ancho en vez de la línea de ~840 px que tapaba el cielo y los Pokémon lejanos. Se pliega SOLA a
  los 20 s (tiempo de leerla una vez) en la pestaña "H · Controles"; **H** o tocarla la cambian. Si el
  jugador la toca antes, deja de plegarse sola (manda él). Si está abierta lo guarda un
  `ValueNotifier<bool>` de la pantalla (la tecla H se maneja allí con las demás); el temporizador
  vive en el widget.
- **2026-09-25 — Huellas en el camino** (`sim/footprints.dart`, Dart puro; `FootprintRenderer`, una
  malla instanciada como el polvo). Una huella por pisada (las mismas pisadas que el polvo y las
  briznas: `footstepSpacing`), en el pie que pisa y apuntando hacia donde miras. SOLO en la tierra
  del camino (`=`): en las losas (`o`) no se marca y en el césped/hierba no se vería. Lo marcada
  (alfa) cuenta el sigilo con el mismo lenguaje de siempre: corriendo 1, andando 0,8, agachado
  0,45. Nítidas 18 s y se borran en los 12 siguientes; como mucho 90 (~45 m de rastro; la más vieja
  se va). Huella simétrica (suela + tacón) para no tener que reflejar la malla en el pie izquierdo
  (reflejar invierte las caras). A 0,03 m del suelo, alfa máximo 0,7 y color tierra húmeda
  (0x7A5E38): con 0,55 y un tono más claro apenas se distinguían en la captura.
- **2026-09-25 — Hierba pisada** (`sim/grass_trampling.dart`, Dart puro). La deja cualquier Pokémon
  que cruza la hierba alta a más de 2,5 m/s: huyendo (4,4) o cargando (3,6); pasear (1,3), ir a por
  una baya (2) o acercarse a curiosear (~2) no. El jugador tampoco: el rastro es PISTA de por dónde
  se fue un Pokémon y no debe confundirse con el tuyo (tú ya dejas huellas en el camino). Se guarda
  POR MATA (dirección, fuerza, edad en `Float64List`) con un índice de matas por casilla: pisar solo
  mira las 9 casillas vecinas y el renderer lee un valor por mata, sin recorrer marcas. Radio 0,9 m;
  del todo en el centro del paso (fuerza = min(1; 1,5·(1 − d/r))), menos en los bordes. Una pisada
  solo cambia una mata si la tumba más de lo que ya estaba. La mata se inclina hacia donde iba
  (0,85 rad, por `GrassField.tiltFor(bend:)`) y se APLASTA al 45 % de su altura: en la vista previa
  solo inclinada apenas se distinguía de la hierba que mece el viento; aplastada se ve un pasillo.
  10 s tumbada y 12 s levantándose. Vista previa: `preview_flee.sh` (`?flee`, `?trail`) en el
  scratchpad.
- **2026-09-25 — El aro que se encoge al apuntar** (TODO 8.14; como en Pokémon GO). `ThrowQuality`
  (modelo: ×1 / ×1,2 / ×1,5 / ×2) y `ThrowRing` (sim, Dart puro). El aro corre SOLO apuntando a un
  Pokémon fijado con una bola en la mano (con baya o sin bolas no hay aro: una baya no captura). Va
  de 1 (el anillo de la mira) a 0,12 a ritmo constante en 1,6 s y vuelve a empezar de golpe;
  cambiar de objetivo o dejar de apuntar lo reinicia. Umbrales: < 0,75 "¡Bien!", < 0,5 "¡Genial!",
  < 0,25 "¡Excelente!" (~0,45 s, ~0,45 s y ~0,24 s: el excelente es el difícil). La calidad es la
  del momento de PULSAR lanzar (lo que el jugador cronometra), no la de soltar la bola (0,2 s después)
  y viaja en la bola (`ThrownBall.quality`, campo aparte: el registro `hit` no cambia de forma). Si
  la bola le da a CUALQUIER Pokémon, multiplica la probabilidad y se suma a sigilo y baya. El % de la
  mira NO incluye el aro (es la base para decidir si merece la pena; el aro es cosa del pulso) y el
  color del aro dice qué tiro saldría: blanco, azul, violeta, dorado. "En ambos modos" = el libre y
  el futuro Reto Safari: no hay nada que cambiar cuando exista.
- **2026-09-25 — Sonido sintetizado con Web Audio** (TODO 8.14). Sin archivos de sonido: todos los
  efectos se generan en el navegador con osciladores y ruido filtrado (estilo chiptune, a juego con
  el low-poly): nada que descargar, ni licencias, ni una dependencia de audio nueva. Se usa
  `package:web` (ya venía como dependencia transitiva; se declara directa, `^1.1.1`). Alternativa
  descartada: `audioplayers` + archivos CC0 (plugin nuevo, assets, y el Windows tampoco se puede
  compilar aquí). Los GRITOS son los .ogg reales de PokeAPI (`cries.latest`); la URL se deduce del
  número de especie (`pokemonCryUrl`) para no tocar el modelo `Pokemon`.
- **2026-09-25 — Arquitectura del sonido.** `services/sound/`: interfaz `SoundService` (solo I/O:
  `play(GameSound)`, `playCry(id)`, `muted`), `WebSoundService` (web) y `SilentSoundService`
  (Windows y tests), elegidos con import condicional (`dart.library.js_interop`). QUÉ suena y
  CUÁNDO lo decide `controllers/sound_director.dart` (Dart puro, con tests) a partir de los eventos
  de la simulación. Para eso la simulación cuenta cuatro cosas nuevas: `ItemThrown` (la mano suelta
  bola o baya), `BallHit`, `BallShook` (n.º de sacudida, crítica o no) y `PokemonNoticed` ("!").
  El `FieldController` las ignora (no cambian la bolsa ni avisan).
- **2026-09-25 — Gritos sin saturar:** al descubrirte ("!"), al salir asustado de la hierba (no al
  asomarse: no sabe que estás) y al escaparse de la bola (este siempre, como en los juegos). El
  mismo Pokémon no repite antes de 10 s y entre dos gritos cualesquiera pasa al menos 1,2 s. Al
  capturar no grita: suena la fanfarria.
- **2026-09-25 — Silenciar:** tecla **N** y un botón con altavoz bajo el minimapa. El estado vive en
  el servicio (no se guarda entre sesiones). El contexto de audio se crea con el primer sonido (el
  navegador exige un gesto previo: tocar "Jugar 3D" ya lo es). Comprobado en Chrome: un tiro con
  captura crea 19 osciladores (lanzar, golpe, 3 sacudidas, clic y fanfarria) y el grito se descarga
  y suena; sin errores en consola.
- **2026-09-25 — Variocolor (shiny)** (TODO 8.14). Lo decide la simulación al hacer aparecer un
  Pokémon (`World3DSim.shinyChance`, 1/100 como en los juegos modernos con suerte) con SU PROPIO
  azar (`Random(19)`): es cosmético y no debe cambiar dónde aparecen ni cómo se comportan (un test lo
  comprueba). El arte es el `official-artwork/shiny` de PokeAPI; la URL se deduce del número
  (`models/pokemon_shiny.dart`, una extensión) para no tocar el modelo ni su JSON. Si no se puede
  bajar, se usa el normal. `ShinySpotted` se emite UNA vez por Pokémon, cuando se ve (libre, no
  escondido, a ≤ `markRange` = 22 m): aviso dorado, sonido de destellos y un corro grande de
  estrellitas 1,2 s; después brilla a ratos (4 estrellitas cada 2,6 s, cada uno a su ritmo) en la
  capa 2D. La captura guarda `shiny` (`CapturedPokemon`), la tarjeta dice "Variocolor" y "Mis
  capturas" enseña su arte variocolor (`PokemonCard(imageUrl:)`). Vista previa: `preview_shiny.sh`.
- **2026-09-25 — Lección (perl):** con `s|...|...|`, un `\|` dentro del patrón deja de ser literal y
  pasa a ser la alternancia de la expresión regular: `a \|\| b` casó vacío al inicio del archivo y
  metió el texto en la línea 1. Con `||` en el código, usar otro delimitador (`#`) o el editor.
- **2026-09-25 — Reto Safari (1.ª parte)** (TODO 8.14). Se empieza con un BOTÓN (a la derecha, bajo el
  altavoz), no con un puesto en el mapa: un puesto sería un tipo de casilla nuevo en el mapa
  compartido con el 2D. Antes, un diálogo con las reglas ("¡Empezar!" / "Ahora no"), con el mundo
  congelado; no empieza si hay una bola en el aire. Reparto: la SIMULACIÓN pone las reglas del mundo
  (`startSafari`/`endSafari`: el reloj, que solo corre con el mundo en marcha y avisa una vez con
  `SafariTimeUp`; `FieldItems.enabled = false`, así las bolas del suelo ni se ven —tampoco en los
  mapas— ni se recogen ni aparecen, y al acabar siguen donde estaban; y las bolas falladas se pierden:
  `BallMissed(lost: true)` y el aviso "Fallaste: en el Safari la bola se pierde"). El
  `SafariController` (por partida, como el FieldController) lleva las 25 bolas PROPIAS (Poké Balls
  normales: se ven y capturan igual), lo capturado y el final: por tiempo, sin bolas (cuando la
  ÚLTIMA termina: cada bola lanzada acaba en captura, escape o fallo, así se cuentan) o al abandonar.
  La bolsa normal no se toca; las BAYAS sí se usan (son tuyas y el reto va de acercarse). Lo
  capturado se queda (es tu equipo para los combates). En el Safari, 1-3 solo cambian baya → bola y
  R alterna bola ↔ baya. El marcador sustituye a la bolsa arriba a la izquierda.
- **2026-09-25 — Ayuda más corta:** con el aro y el sonido la ayuda crecía y, en una ventana de
  800×600, tapaba el aviso de acción de abajo (lo detectó un test de widget). Las líneas se acortan
  para no partirse (6 filas) y el botón del Safari va a la derecha, no bajo la bolsa.
- **2026-09-26 — Puntuación del Reto Safari** (TODO 8.14). Solo existe en el reto (el modo libre no
  puntúa nada). Cada captura vale `base × bonus`. Base por RAREZA con el ratio de captura real:
  `100·√(255/ratio)` → 100 (ratio 255), 238 (45, el más común en los juegos), 922 (3, legendarios).
  Lineal (255/ratio) haría que un legendario valga 85 fáciles y decida él solo el reto; la raíz lo
  deja en ~9. El bonus son los MISMOS multiplicadores que ya facilitan la captura (sin ser visto
  ×1,5 o espalda ×2, comiendo ×1,5, el aro ×1,2–×2): premiar lo que el juego ya enseña, sin reglas
  nuevas. La captura crítica NO suma (es azar, no habilidad) ni el tipo de bola (en el reto todas
  son Poké Balls). Para puntuar, `PokemonCaught` lleva ahora `hit` y `quality` del tiro (opcionales:
  los demás oyentes no cambian). Se ve en el marcador ("Capturas: N · P pts") y en el resumen.
- **2026-09-26 — En el Safari huyen** (TODO 8.14). Solo al ESCAPARSE de la bola (no al fallar el
  tiro: fallar ya cuesta la bola y el Pokémon se asusta). Probabilidad `0,1 + 0,4·(1 − ratio/255)`:
  10 % (ratio 255), ~43 % (45), ~50 % (3). Lineal con tope del 50 %: un raro que huye la mitad de
  las veces ya es tenso; más frustraría. Si la bola le dio MIENTRAS COMÍA, la mitad (el cebo de la
  Zona Safari clásica): así las bayas también sirven en el reto para asegurar a los raros. Lo decide
  la SIMULACIÓN (sabe si hay reto) con su propio azar (`fleeRandom`, inyectable en tests, como el
  variocolor) envolviendo el evento como hace con `BallMissed(lost:)`: `PokemonBrokeFree(fled:)`.
  El que huye (`WildPokemon.leavingFor`) espera al "pop" de la bola, corre a 4,4 m/s lejos del
  jugador sea cual sea su carácter (un agresivo NO carga: huir es huir), no mira bayas ni dispara
  encuentros, tumba la hierba al cruzarla y desaparece a 24 m o, si se atasca, a los 6 s en una
  nubecilla de polvo. Se le puede seguir lanzando bolas mientras corre (atraparlo al vuelo es un
  tiro de mérito). Aviso aparte "¡El X salvaje huyó!" (el de "se ha escapado" sigue saliendo).
- **2026-09-26 — Prioridad: 8.15 antes que lo que queda de 8.14.** El usuario pidió centrarse en la
  mecánica de lanzar (animación, trayectoria, impacto, sacudidas, resultado) y en explorar el campo.
  Lo pendiente de 8.14 (botón Combatir —espera al otro equipo—, pantalla final del Safari con récord,
  Pokédex con huecos, misiones) no toca eso, así que se abre 8.15 con mejoras de esas dos áreas y se
  hace primero. En una vista previa (tiro a ~8 m) se vio el problema principal: las sacudidas y el
  resultado pasan lejos y la bola se ve diminuta; de ahí la primera tarea (cámara de captura).
- **2026-09-26 — Cámara de captura** (TODO 8.15; `sim/capture_camera.dart`, Dart puro). Decide QUÉ
  mirar (la bola que más recientemente golpeó, desde el golpe hasta 1,1 s tras el "¡clic!" o 0,5 s
  tras escaparse) y CUÁNTO (`weight` suavizado: entra a 3,2/s, sale a 2,4/s). `OrbitCamera` mezcla
  con `focus` los tres parámetros de la órbita (punto que mira, distancia e inclinación) en vez de
  dos posiciones: el ojo viaja en arco, el giro no cambia (adelante sigue siendo adelante para
  WASD) y todo lo que proyecta la cámara (marcas, bonus) sigue cuadrando solo. Encuadre a 2,6 m y
  0,5 rad: a 3,4 m la bola (radio 0,12) apenas ocupaba 25 px en la vista previa. El factor de
  alcance (0 a < 2,5 m, 1 a ≥ 4,5 m de la bola al jugador) evita meter el ojo en la cabeza del
  jugador o detrás de él en tiros cortos (ahí la bola ya se ve). Si algo alto queda detrás de la
  bola, el encuadre se acerca (misma prueba de obstáculos que la cámara normal).
  **El jugador manda:** moverse, girar la cámara, volver a PULSAR apuntar o lanzar otra cosa la
  sueltan para esa bola; otra bola que golpee la vuelve a llamar. Mantener apuntar desde antes del
  golpe NO la suelta (es lo normal al lanzar): apuntar queda en suspenso (`isAiming`: sin mira, sin
  arco, sin aro) y, al terminar, se vuelve a apuntar. La mezcla del hombro (`camera.aim`) sigue la
  tecla, no `isAiming`: si no, al golpear la cámara se alejaba del hombro y luego volvía hacia la
  bola (se vio en la vista previa).
- **2026-09-26 — Impacto con peso** (TODO 8.15). MICRO-PAUSA (hit-stop, como en los juegos de
  acción): al emitirse `BallHit` la simulación deja de avanzar el MUNDO 0,07 s (bolas, Pokémon,
  decorados); la cámara, el jugador y el gesto de lanzar siguen, así no parece un tirón del
  navegador. 0,14 s si la captura va a ser crítica (el resultado ya está decidido en el golpe): se
  nota que ese golpe es especial antes de ver el brillo dorado. Más de ~0,15 s ya parece un fallo.
  La ONDA: un anillo que mira a la cámara, de 0,2 a 1,5 m en 0,35 s con salida suave, y un
  fogonazo del primer tercio; en el PUNTO DEL GOLPE (`ThrownBall.hitPoint`), no en la bola, que ya
  sube a absorberlo. El tiempo lo da `ThrownBall.impactProgress` (probado sin GPU). Durante la
  micro-pausa la onda se queda en su primer fotograma: justo el "fogonazo congelado" del hit-stop.
- **2026-09-26 — Sacudidas con tensión** (TODO 8.15). Antes, las tres sacudidas eran iguales (0,55
  rad, ciclos de 1,2 s) y el resultado llegaba sin aviso. Ahora cada una se ladea más (0,42 · 0,58 ·
  0,74 rad; la crítica, la única, 0,85), la pausa tras cada una crece (0,35 · 0,5 s) y tras la
  ÚLTIMA hay 0,8 s de silencio: el momento de "¿lo tengo?". Tres sacudidas pasan de 4,0 a 4,6 s en
  el suelo. Los tiempos salen de `ThrownBall.shakeStart(i)` / `pauseAfter(i, n)` (Dart puro, con
  tests); `shakeCycle` desaparece. `BallShook` (el "toc") se emitía al TERMINAR cada ciclo, es decir,
  ~1 s después del vaivén que se veía; ahora se emite al empezar, a la vez que la bola se mueve.
- **2026-09-26 — El resultado se ve** (TODO 8.15). CAPTURADO: la bola ya no se encoge en el sitio;
  tras el "¡clic!" (0–0,35 s) y las estrellas (hasta 1,2 s) VUELVE A LA MOCHILA en 0,6 s
  (`caughtTime` 1,6 → 1,8 s): curva de Bézier con un arco más alto cuanto más lejos (1 m + 10 %
  de la distancia, hasta 2,5 m), que sale despacio y entra deprisa (ease-in, como atraída), girando
  y encogiéndose, con un destellito al llegar. Es solo visual: la simulación da el tiempo y la
  curva (`ThrownBall.returnProgress` / `returnPosition`, con tests) y la mochila
  (`World3DSim.backpackPosition`: a la espalda, a 1,1 m; más baja agachado). La cámara de captura
  suelta la bola a los 1,1 s: vuelve al jugador a la vez que la bola, así se ve llegar.
  SE ESCAPA: la bola se PARTE (la tapa se abre de golpe y sale volando hacia arriba y atrás, la
  base se vuelca) y saltan 7 chispas. El fogonazo blanco se redujo (1,3 m y 0,75 de opacidad →
  0,9 m, 0,55 y 0,3 s): en la vista previa tapaba la rotura entera.
- **2026-09-26 — La bola aparta la hierba** (TODO 8.15). La bola que ha capturado (cayendo por
  debajo de 0,6 m, sacudiéndose, rompiéndose o con las estrellas) entra en `grassPushers` como el
  jugador y los Pokémon, con el MISMO radio (1,2 m): en la vista previa, con la cámara de captura a
  2,6 m, un radio pequeño dejaba matas delante de la bola. Volando o rodando tras fallar no aparta
  nada (pasa de largo y el "claro" parpadearía). Deja de hacerlo al volver a la mochila.
- **2026-09-26 — Esquivar la bola** (TODO 8.15). Solo un Pokémon que te VIGILA ("!" alerta o "?"
  sospecha) y MIRA la bola (su frente a menos de ~70° de ella) cuando le llegaría en < 0,4 s; se
  decide una vez por bola y Pokémon. Probabilidad por carácter: asustadizo 40 %, curioso 20 %,
  agresivo 0 (embiste: esquivar sería raro y ya es el más peligroso); por el aro: ×0,7 "¡Bien!",
  ×0,4 "¡Genial!", ×0 "¡Excelente!" (premia la habilidad del aro sin dar un bonus nuevo).
  Consecuencia que se vio al probar: un asustadizo alerta HUYE de espaldas, así que en la práctica
  esquivan los curiosos que te miran y los que están con "?" (antes de salir corriendo). Salto
  lateral de 1,6 m en 0,3 s (rápido al principio: en la mitad del tiempo ya lleva > 60 %, más que
  el radio de golpe) hacia el lado en que ya estaba respecto al camino de la bola (o al otro si no
  se puede pisar; si no cabe, no esquiva), con un saltito de 0,45 m. Durante el salto no hace nada
  más; al caer sigue alerta. Evento `PokemonDodged` → aviso "¡X esquivó la bola! Te vio venir" y un
  "¡zas!" sintetizado. El cartel del prado lo cuenta.
- **2026-09-26 — Dados de juego sin semilla.** La vista previa de la esquiva salió igual en tres
  partidas seguidas: el dado tenía semilla fija (`Random(31)`), así que cada partida repetía la
  misma secuencia. Lo mismo pasaba con la huida del Safari (`Random(23)`) y con el variocolor
  (`Random(19)`: el mismo n.º de aparición salía siempre variocolor). Ahora los tres usan
  `Random()` sin semilla; los tests inyectan el suyo (`fleeRandom`, `dodgeRandom`) o fijan la
  probabilidad a 0/1. Los azares de DECORADO (polvo, briznas, pájaros…) siguen con semilla: da
  igual que se repitan y así las vistas previas son comparables.
- **2026-09-26 — Voltereta y aturdidos** (TODO 8.15). Tecla **X** (libre) y un botón pequeño junto
  a agacharse. 3,2 m en 0,5 s: sale a 8,5 m/s y frena a la mitad (así se nota el impulso y enlaza
  con andar), por el mismo choque que andar (`PlayerBody.dash`). Hacia donde empujas o, quieto,
  hacia donde miras. Espera de 0,35 s entre volteretas (sin ella se encadenan y es más rápida que
  correr). Te levanta, hace ruido (sigilo "ruidoso") y no deja apuntar ni lanzar.
  **Para qué sirve:** escapar de una carga sin combate. Correr (7,5 m/s) ya dejaba atrás a un
  agresivo (3,6 m/s), así que la voltereta tenía que dar algo más: el que te embiste a < 3,5 m
  cuando ruedas va a por donde ESTABAS (recto, +2 m, a 5 m/s) y queda ATURDIDO 2,5 s (quieto, sin
  percibir nada, `alertTime = 0`): cuenta como "no te vio" (×1,5) y, como se pasó de largo, suele
  quedar de espaldas (×2). Riesgo y premio: hay que dejar que se acerque. Rodando, un contacto con un
  agresivo lo aturde en vez de empezar el combate. Al volver en sí sigue mosqueado (sospecha 0,9).
  Animación: una vuelta entera hacia delante alrededor del centro del cuerpo (0,65 m), hecho una
  bola y levantándose 0,45 m a mitad para no hundirse en el suelo. Sonidos: "¡zas!" al rodar,
  "uiuiui" al aturdirse; aviso morado y tres estrellitas girando sobre su cabeza.
- **2026-09-26 — La cámara respira con la postura** (TODO 8.15). `OrbitCamera.stance` (1 corriendo,
  0 andando o quieto, −1 agachado) lo suaviza la simulación a 2,5/s (~0,4 s: rápido, sin marear).
  Corriendo, la distancia ×1,12; agachado ×0,85 y el punto que mira 0,35 m más bajo. Se eligió la
  DISTANCIA y no el campo de visión: el FOV fijo lo usan el motor y `project` (marcas, mira), y
  cambiarlo obligaba a pasarlo por todos lados; alejarse da la misma sensación. Mientras ruedas no
  cambia (la voltereta es muy corta y daría un tirón). Nada de balanceo al correr: marea.
- **2026-09-26 — Pisadas con sonido** (TODO 8.15). Evento `Footstep(superficie, fuerza)` en cada
  pisada (las mismas que el polvo, las briznas y las huellas: cada 0,75 m). Superficie por casilla:
  camino = tierra, `o` = losas, hierba alta, y el resto césped. La FUERZA es la del sigilo
  (`footstepLoudness`, de `stealth`): el jugador oye lo mismo que le delata, así el sonido enseña el
  sigilo sin carteles. Para eso `SoundService.play` admite `volume` (0..1; escala todas las ganancias
  del sonido sintetizado). Durante la voltereta no hay pisadas (suena su "¡zas!"). Comprobado en
  Chrome contando nodos de audio: 8 pisadas (ruido + golpe) en 1,5 s andando por el camino. Ojo en
  los tests: la casilla de inicio `@` del mapa es CAMINO.
