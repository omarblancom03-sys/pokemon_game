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
- [ ] Lanzar bayas para distraer: el Pokémon va a comérsela y, mientras come, no te ve (bonus "¡Está comiendo!")
- [ ] Mapa grande (M): todo el mundo con carteles, bolas del suelo, arbustos con bayas y dónde estás

## 8.13 Exploración: detalles (añadido 2026-09-25)
- [ ] Huellas del entrenador en la tierra del camino (se borran con el tiempo)
- [ ] Pokémon que dejan rastro: la hierba pisada por donde pasó uno que huyó

## Mejoras continuas
- [ ] (se irán añadiendo)
