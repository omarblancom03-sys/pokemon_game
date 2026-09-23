# PROGRESO — qué funciona y cómo probarlo

## Cómo ejecutar
- Web: `flutter build web` y `node tool/serve_web.mjs 5500` → http://localhost:5500
- Windows: `flutter run -d windows` (necesita Visual Studio con C++; ver DECISIONES.md)
- Tests: `flutter analyze` y `flutter test`

## Estado
- **Menú:** Jugar 2D · Jugar 3D · Pokédex · Generaciones.
- **2D (Flame):** mapa de baldosas, Ash animado, humos que disparan encuentros.
- **3D (flutter_scene):**
  - Suelo con manchas de color (zonas frondosas y secas), matas bajas en el césped y piedrecitas en
    el camino.
  - Mundo low-poly generado por código a partir del mismo mapa ASCII del 2D: césped, caminos, casas con
    tejado, árboles, pinos, árboles otoñales, arbustos con bayas, vallas, setas, flores y un bosque que
    rodea el mapa. Luz de sol con sombras, cielo en degradado, niebla ligera y aspecto "stylized".
  - Entrenador low-poly (gorra, chaqueta, mochila) con ciclo de caminar y carrera. Al correr levanta
    polvo (y al frenar en seco); las Poké Balls también al botar.
  - Cámara en tercera persona: arrastrar con el ratón para girar, rueda para zoom, Q/E para girar con
    teclado. WASD/flechas mueven relativo a la cámara; Mayús corre. D-pad en pantalla. La cámara no
    atraviesa árboles ni casas: se acerca si algo estorba y, de espaldas a un árbol, mira desde arriba.
  - Hierba alta 3D que se mece con el viento y se aparta al pasar.
  - Mariposas de colores sobre las flores: se espantan si te acercas (agachado puedes verlas de cerca).
  - Pokémon salvajes VISIBLES (arte oficial de PokeAPI) que deambulan por la hierba alta.
  - **Sigilo:** los Pokémon ven en un cono delante de ellos y oyen tus pasos (correr se oye de lejos).
    Si sospechan sale "?" y se giran; si te descubren, "!" y reaccionan según su carácter: los
    asustadizos huyen, los curiosos se acercan a mirarte y los agresivos (¡rojo!) cargan: si te
    alcanzan empieza el encuentro (combate, de otro equipo). Agáchate con C para ir despacio y en
    silencio; dentro de la hierba alta casi no te ven ("Escondido en la hierba").
  - El encuentro usa por ahora el diálogo provisional (Atrapar / Huir). El combate lo hace otro equipo.
  - **Tus capturas:** cada captura enseña una tarjeta (arte, número, tipos, bola y "¡Nuevo!" si es
    la primera de su especie). Pulsa P (o toca "Capturados") para ver todas tus cartas.
  - **Minimapa** (arriba a la derecha): gira con la cámara (arriba = adelante), "N" = norte. Puntos
    rojos = Poké Balls en el suelo; Pokémon en blanco (tranquilo), amarillo (sospecha), naranja (te vio)
    o rojo latiendo (viene a por ti).
  - **Poké Balls en el campo:** puñados de Poké/Super/Ultra Balls flotando con un haz de luz (se ven de
    lejos). Se recogen al pasar por encima; reaparecen en otro sitio a los 12 s. Bolsa arriba a la
    izquierda (toca una bola para elegirla) con el número de capturados; avisos arriba en el centro.
  - **Capturar lanzando Poké Balls (estilo Leyendas Arceus):** apunta con clic derecho (o F): la cámara
    se pone al hombro, aparece la mira, la bola en la mano, el arco que seguirá (puntos) y un anillo
    donde caerá (verde si va al Pokémon fijado). Sobre el Pokémon fijado, un anillo con la
    probabilidad de captura. Clic izquierdo (o Espacio) lanza. La bola deja una estela de su color. Si da: la bola se abre, el Pokémon se
    vuelve rojo y entra, la bola cae, se sacude 0–3 veces (el botón se enciende en rojo en cada sacudida) y... ¡estrellas y "capturado"! o se abre y el
    Pokémon sale de un salto (y queda alerta). Si falla, rebota y rueda (también contra árboles y
    casas) y queda en el suelo brillando para recogerla. Por la espalda y sin ser visto es más fácil.
    Al golpear se ve el bonus conseguido: "¡No te vio! ×1,5" y/o "¡Por la espalda! ×2".

## Cómo probar la captura
1. Jugar 3D → ve hacia el prado de hierba alta (arriba a la derecha al empezar).
2. Mantén clic derecho: mira, arco y anillo con el %. Suelta clic izquierdo para lanzar.
3. Recoge bolas brillantes del suelo (y las que falles). Cambia de bola con R o 1-2-3.
4. Agáchate (C) en la hierba alta y acércate por la espalda: sin "?" ni "!" la captura es más fácil.

## Cómo probar el 3D
1. Menú → **Jugar 3D**. Espera a que cargue (círculo de progreso).
2. Gira la cámara arrastrando con el ratón; acércate con la rueda.
3. Camina hacia el prado de hierba alta (a la derecha del camino al empezar).
4. Acércate a un Pokémon o camina por la hierba: aparece el diálogo del encuentro.
