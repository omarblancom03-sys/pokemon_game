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
    teclado. V (o el botón de la cámara) la vuelve a poner detrás del jugador con un giro suave.
    WASD/flechas mueven relativo a la cámara; Mayús corre. D-pad en pantalla. La cámara no
    atraviesa árboles ni casas: se acerca si algo estorba y, de espaldas a un árbol, mira desde arriba.
  - **Nubes:** sus sombras cruzan despacio el suelo con el viento (se ve cómo se oscurece el césped
    y vuelve el sol); si levantas la cámara, hay nubes blancas lejanas sobre el bosque.
  - Hierba alta 3D que se mece con el viento y se aparta al pasar. Al pisarla saltan briznas que dan
    vueltas y caen planeando: tres por pisada corriendo, una andando y ninguna agachado (se ve el
    ruido que haces).
  - Mariposas de colores sobre las flores: se espantan si te acercas (agachado puedes verlas de cerca).
  - **Pájaros:** dos bandadas de gorriones picotean y dan saltitos en el campo abierto. Si te
    acercas salen volando todos a la vez (corriendo desde lejos; agachado te acercas mucho), cruzan
    el cielo y se posan en otro sitio lejos de ti. Una Poké Ball que cae cerca también los espanta.
  - **Arbustos con bayas:** ponte delante de un arbusto y sale "L · Sacudir el arbusto" con las bayas que
    le quedan. Al sacudirlo se balancea, se le caen unas hojas y sus bayas saltan y caen a tus pies: se
    recogen solas y van a la bolsa ("+3 Bayas Frambu"; el contador de bayas está junto a las bolas). Le
    vuelven a crecer poco a poco. Ojo: sacudirlo hace ruido (los Pokémon cercanos se giran a mirar).
  - **Carteles que se leen:** ponte delante de un cartel y sale "L · Leer el cartel" (tócalo o pulsa L
    / Intro): una tabla de madera con lo que pone. Hay cuatro: Pueblo Paleta, la entrada al prado de
    hierba alta, un consejo sobre la hierba que se agita y la tienda de Poké Balls (cerrada). Explican
    el sigilo y la captura dentro del propio juego. Alejarse lo cierra.
  - Pokémon salvajes VISIBLES (arte oficial de PokeAPI) que deambulan por la hierba alta.
  - **Hierba que se agita:** algunos Pokémon están ESCONDIDOS en la hierba alta: no se ven (ni en el
    minimapa) y solo se nota la hierba sacudiéndose a ratos. Si llegas andando o corriendo salen de un
    salto, asustados ("¡Un X salvaje salió de la hierba!"); si llegas agachado se asoman sin verte y de
    espaldas ("X asoma entre la hierba… ¡no te ha visto!"): la ocasión perfecta. Una bola que cae cerca
    también los hace salir, y si le das de lleno a la mata que se agita, ¡lo capturas por sorpresa!
    La mata donde se esconde escupe briznas grandes y claras a ratos; al salir, un surtidor de briznas.
  - **Sigilo:** los Pokémon ven en un cono delante de ellos y oyen tus pasos (correr se oye de lejos).
    Si sospechan sale "?" y se giran; si te descubren, "!" y reaccionan según su carácter: los
    asustadizos huyen, los curiosos se acercan a mirarte y los agresivos (¡rojo!) cargan: si te
    alcanzan empieza el encuentro (combate, de otro equipo). Agáchate con C para ir despacio y en
    silencio; dentro de la hierba alta casi no te ven ("Escondido en la hierba").
  - El encuentro usa por ahora el diálogo provisional (Atrapar / Huir). El combate lo hace otro equipo.
  - **Captura crítica:** cuantas más especies distintas captures, más a menudo (hasta un 25 %) la bola
    brilla en dorado y se decide en una sola sacudida (mucho más fácil).
  - **¿Ya lo tienes?** Sobre los Pokémon cercanos cuya especie ya capturaste sale una Poké Ball
    pequeña. Al apuntar, encima de la mira aparece el nombre del fijado con "¡Nuevo!" si aún no lo
    tienes (o su Poké Ball si ya lo tienes): así sabes a cuál merece la pena ir.
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
