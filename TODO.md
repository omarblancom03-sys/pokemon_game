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
- [ ] Poké Balls en el suelo para recoger (brillo), reaparecen; las falladas se pueden recoger
- [ ] Lanzar: apuntar (cámara al hombro, mira), fijar objetivo, física parabólica, choques
- [ ] Secuencia: absorber, caer, sacudidas, ¡capturado! (estrellas) o se escapa
- [ ] HUD: bolsa y bola elegida, mira, avisos, capturados

## 8.8 Comportamiento y sigilo
- [ ] Agacharse (sigilo), ruido al correr, la hierba alta oculta
- [ ] Pokémon con carácter: se alertan (?/!), huyen, curiosean o atacan (→ EncounterHandler)

## 8.9 Andar por el campo
- [ ] La cámara no atraviesa árboles ni casas
- [ ] Minimapa
- [ ] Más vida en el mundo (suelo con variación, polvo al correr, detalles)

## Mejoras continuas
- [ ] (se irán añadiendo)
