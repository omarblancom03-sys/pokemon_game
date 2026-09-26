# TODO — Fase 8: Pokémon 3D en tercera persona

> Al retomar una sesión: leer este archivo y continuar por la primera casilla sin marcar.
> Tras cada subtarea: `flutter analyze` (0 issues) + `flutter test` (verde) + commit.

## 8.0 Base
- [x] Commit del trabajo 7a–7d pendiente (120 tests)
- [x] TODO.md, DECISIONES.md, PROGRESO.md
- [x] Menú con "Jugar 2D" / "Jugar 3D" y ruta `/game3d` (pantalla temporal)

## 8.1 Spike del motor 3D
- [x] Añadir flutter_scene e inicializar
- [x] Cubo iluminado girando en `/game3d` detrás de la interfaz `SceneRenderer`
- [x] Verificar `flutter build web` + captura headless
- [~] Verificar `flutter build windows` (sin Visual Studio en esta máquina; ver DECISIONES)

## 8.2 Simulación (Dart puro)
- [x] OrbitCamera (yaw/pitch/distancia, límites)
- [x] PlayerMotion (WASD relativo a cámara, colisión deslizante con MapLayout)
- [x] Input: arrastrar ratón, rueda, Q/E, WASD, D-pad
- [x] Render: suelo + jugador provisional siguiendo la cámara

## 8.3 Mundo low-poly
- [x] Terreno desde MapLayout (césped, camino, flores, hierba alta)
- [x] Árbol, pino, árbol otoñal, arbusto, valla, cartel, casa, roca, seta
- [x] Luz direccional + cielo

## 8.4 Entrenador
- [x] Modelo low-poly + ciclo de caminar + orientación suave + sombra

## 8.5 Hierba alta + Pokémon salvajes
- [x] Hierba alta animada
- [x] WildSpawner (Pokémon visibles que deambulan, sprite PokeAPI como billboard)
- [x] Encuentros por contacto y por pasos en hierba → GameController

## Cambio de alcance (2026-09-22, pedido del usuario)
El combate lo hace OTRO equipo (se engancha por el contrato EncounterHandler). Nuestro trabajo: SOLO
**capturar** (encontrar Poké Balls en el campo y lanzarlas) y **andar por el campo**, con máxima calidad.

## 8.6 Captura: lógica
- [x] Tipos de Poké Ball (Poké/Super/Ultra) + bolsa y capturados (TrainerController, app-wide)
- [x] Ratio de captura real de PokeAPI (pokemon-species capture_rate) en servicio/repositorio
- [x] CaptureCalculator (probabilidad + sacudidas, bonus por sigilo/espalda) con tests

## 8.7 Captura: en el mundo
- [x] Poké Balls en el suelo para recoger (brillo), reaparecen; las falladas se pueden recoger
      (FieldItems + ItemRenderer + FieldController con bolsa y avisos)
- [x] Lanzar: apuntar (cámara al hombro, mira), fijar objetivo, física parabólica, choques
      (aiming.dart + BallSystem en throwing.dart; arco previsto con puntos y anillo de caída)
- [x] Secuencia: absorber, caer, sacudidas, ¡capturado! (estrellas) o se escapa (BallRenderer)
- [x] HUD: bolsa y bola elegida, mira, avisos, capturados (+ anillo con % de captura)
- [x] Ratio de captura real al aparecer (FieldController.pickWildSpawn)

## 8.8 Comportamiento y sigilo
- [x] Agacharse (sigilo), ruido al correr, la hierba alta oculta (C/Ctrl o botón; indicador abajo)
- [x] Pokémon con carácter: se alertan (?/!), huyen, curiosean o atacan (→ EncounterHandler)
      (wild_behavior.dart: vista en cono + oído; una bola que cae cerca los asusta)
- [x] Encuentros al azar en la hierba apagados por defecto en 3D (flag grassEncounters)

## 8.9 Andar por el campo
- [x] La cámara no atraviesa árboles ni casas (se acerca al instante y se aleja poco a poco;
      de espaldas a un árbol o casa sube para mirar desde arriba — OrbitCamera.avoidObstacles)
- [x] Minimapa (redondo, arriba a la derecha, girado con la cámara; bolas y Pokémon por estado)
- [x] Más vida en el mundo:
  - [x] Suelo con variación (manchas, zonas frondosas y secas, granulado) + matas bajas y piedrecitas
  - [x] Polvo al correr (una nubecilla por pisada), al frenar en seco y al botar una bola
  - [x] Mariposas en las flores (se espantan al pasar; más lejos si corres, agachado te acercas)

## 8.10 Captura: pulido (añadido 2026-09-23)
- [x] Texto del bonus al golpear ("¡No te vio! ×1,5", "¡Por la espalda! ×2") sobre el Pokémon
- [x] Botón de la bola que se enciende en rojo (con halo) en cada sacudida y destello blanco en el "clic"
- [x] Estela de la bola en vuelo (del color de la bola)
- [x] Tarjeta "¡Capturado!" con el arte, número, tipos, bola y "¡Nuevo!" + panel "Mis capturas" (P)
- [x] Captura crítica (una sola sacudida más fuerte, brillo dorado, "¡Captura crítica!"; más probable con más especies)

## 8.11 Exploración: más vida (añadido 2026-09-23)
- [x] Hierba que se agita: Pokémon escondidos en la hierba alta que salen al acercarte
      (35 % aparecen escondidos; de pie salen asustados, agachado se asoman de espaldas; una bola cerca
      los hace salir; darles de lleno los captura por sorpresa; a los 60 s se van)
- [x] Briznas de hierba al correr por la hierba alta (y sobre los escondidos, y al salir de un salto)
      (GrassBladeSystem: 3 por pisada corriendo, 1 andando, 0 agachado; suben, giran y caen planeando)
- [x] Carteles que se pueden leer (L / Intro o tocar el aviso; 4 carteles con consejos de sigilo y captura)
- [x] Recentrar la cámara detrás del jugador (V o botón; suave, por el camino corto; girarla a mano lo cancela)
- [x] Nubes que pasan: sombras que cruzan el suelo con el viento + nubes lejanas en el cielo
- [x] Pájaros: se posan en el suelo y salen volando al acercarte (y bandadas que cruzan el cielo)
      (2 bandadas de 5; picotean y saltan; se espantan según tu sigilo o si cae una bola cerca)

## 8.12 Captura: más estrategia (añadido 2026-09-25)
- [x] Poké Ball pequeña sobre los Pokémon cuya especie ya tienes; al apuntar, su nombre (y "¡Nuevo!" si no la tienes)
- [x] Arbustos con bayas: acércate y sacúdelos para recoger bayas (van a la bolsa)
      (L / Intro o tocar el aviso; caen a tus pies y se recogen al pasar; vuelven a crecer; hace ruido;
      2 arbustos nuevos junto a los prados)
- [x] Lanzar bayas: la baya en la mano (4, R o tocarla en la bolsa), arco previsto y cae un poco por detrás
      del Pokémon fijado (más floja que una bola: llega menos lejos); rebota en árboles; se puede recoger
- [x] Bayas para distraer: el Pokémon va a comérsela y, mientras come, no te ve (bonus "¡Está comiendo!")
      (la baya cae POR DETRÁS del fijado: se da la vuelta para comer; huele bayas a 10 m, no las que
      están junto a ti; ×1,5 que se suma al sigilo; bocadillo con la baya y mordiscos)
- [x] Mapa grande (M): todo el mundo con carteles, bolas del suelo, arbustos con bayas y dónde estás
      (M o tocar el minimapa; norte arriba; congela el mundo; Pokémon solo en el círculo cercano)

## 8.13 Exploración: detalles (añadido 2026-09-25)
- [x] Ayuda de controles plegable (H): se ve al entrar y luego queda en una pestaña pequeña (ahora tapa
      a los Pokémon lejanos de la parte de arriba de la pantalla)
- [x] Huellas del entrenador en la tierra del camino (se borran con el tiempo)
      (una por pisada; corriendo más marcadas, agachado apenas; nítidas 18 s y se borran en 12)
- [x] Pokémon que dejan rastro: la hierba pisada por donde pasó uno que huyó
      (huyendo o cargando por la hierba alta: matas tumbadas hacia donde iba y aplastadas; 10 s y se
      levantan en 12)

## 8.14 Diversión sin quitar protagonismo a los combates (añadido 2026-09-25)
Principio: todo es OPCIONAL. El modo libre no tiene tiempo ni límites; capturar alimenta los
combates (tus capturas = tu equipo), nunca compite con ellos. Nada de lo de aquí da niveles ni stats.

- [ ] Acordar con el equipo de combate: qué hace el botón "Combatir" y que lean los capturados
      de TrainerController como equipo
- [ ] Botón "Combatir" siempre visible en el HUD 3D (y en pausa) → hook del otro equipo
- [x] Sonido: gritos de PokeAPI (campo cries) al alertarse, "fiu" al lanzar, clic por sacudida,
      fanfarria al capturar
      (sintetizado con Web Audio; también golpe, escape, recoger y arbustos; N o el altavoz silencian)
- [x] Anillo que se encoge al apuntar: "¡Bien!/¡Genial!/¡Excelente!" ×1,2/×1,5/×2 (en ambos modos)
      (aro dentro de la mira, 1,6 s por vuelta; cuenta el tamaño al PULSAR; se suma a los demás bonus)
- [x] Reto Safari (opcional): se empieza en un puesto del mapa o con un botón; 10 min, 25 bolas
      propias sin reaparición; "Abandonar reto" en cualquier momento sin penalización
      (botón "Reto Safari" bajo el altavoz; reloj que se para con la pausa; sin bolas en el suelo;
      las falladas se pierden; bayas propias sí; resumen al terminar)
  - [x] Puntuación solo en el Safari: base por rareza (capture_rate) × bonus que ya existen
        (100·√(255/ratio): 100 a 922; × sigilo/espalda, baya y aro; la crítica no suma; marcador y resumen)
  - [x] Solo en el Safari: probabilidad de que huyan al fallar (mayor si es raro)
        (al escaparse de la bola: 10 % a 50 % según el ratio; la mitad si comía; corre lejos y desaparece)
  - [ ] Pantalla final con resumen y récord; premio en bolas y bayas
- [x] Shinies (sprites.front_shiny, 1/100, destello al aparecer; solo cosmético)
      (arte oficial variocolor; aviso, destello grande y sonido al verlo; brilla a ratos; la carta lo dice)
- [ ] Pokédex con huecos en "Mis capturas": siluetas de las especies del mapa (7/20)
- [ ] Misiones cortas opcionales (3 activas, panel plegable, sin tiempo): enseñan sigilo, espalda,
      hierba y bayas; premio en Super/Ultra Balls
## 8.15 Captura y exploración: sensación (añadido 2026-09-26)
Foco pedido por el usuario: lanzar (animación, trayectoria, impacto, sacudidas, resultado) y andar por
el campo (movimiento, cámara, hierba alta, encuentros, escenario). Va antes que lo que queda de 8.14.
- [x] Cámara de captura: al golpear, la cámara se acerca y encuadra la bola durante las sacudidas y
      el resultado; vuelve sola. Moverse, girar la cámara o volver a apuntar la suelta
      (a 2,6 m de la bola en ~1 s; tiros a menos de 2,5 m no se acercan; si se mantiene apuntar, al
      terminar vuelve al hombro)
- [x] Impacto con peso: micro-pausa al golpear (hit-stop), onda/destello en el punto del golpe
      (0,07 s; 0,14 s si va a ser crítica; onda que mira a la cámara 0,35 s, dorada si es crítica)
- [x] Sacudidas con tensión: cada sacudida más larga y ladeada; pausa antes del resultado
      (inclinación 0,42 → 0,58 → 0,74 rad; pausas 0,35 → 0,5 s y 0,8 s tras la última; el "toc" al empezar)
- [x] Resultado: al capturar, la bola vuela a la mochila; al escaparse, la bola se parte con destellos
      (vuelta en arco de 0,6 s tras las estrellas; al escaparse la tapa sale volando, 7 chispas)
- [x] La hierba alta se aparta alrededor de la bola que se sacude (se ve la bola en la hierba)
      (al caer cerca del suelo, sacudiéndose y hasta volver a la mochila o romperse)
- [x] Pokémon que te miran pueden esquivar la bola de un salto (según carácter): el sigilo importa más
      (con "?" o "!" y mirando la bola: asustadizos 40 %, curiosos 20 %, agresivos nunca; el aro lo
      reduce y un "¡Excelente!" no se esquiva; salto lateral de 1,6 m en 0,3 s; aviso y sonido)
- [x] Rodar para esquivar (tecla X o botón): escapar de una carga sin combate
      (3,2 m en 0,5 s; el que te embiste a < 3,5 m se pasa de largo y queda aturdido 2,5 s: cuenta
      como "no te vio"; rodando nadie te alcanza; ruido y polvo/briznas)
- [ ] Cámara que respira: al correr se aleja un poco, agachado se acerca y baja
- [ ] Pasos que suenan según el suelo (camino, césped, crujido en la hierba alta)
- [ ] Pokémon dormidos (Zzz): se acercan sin despertar si vas con sigilo; bonus al capturarlos
- [ ] Manadas: algunos aparecen en grupo; si uno te descubre, avisa a los demás
- [ ] Árboles que se mecen con el viento y hojas que caen de los otoñales

## Mejoras continuas
- [ ] (se irán añadiendo)
