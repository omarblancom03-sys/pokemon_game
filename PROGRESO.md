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
    En la tierra del camino deja huellas (una por pisada, más marcadas corriendo y apenas agachado)
    que se van borrando: a los 30 s ya no están.
  - Cámara en tercera persona: arrastrar con el ratón para girar, rueda para zoom, Q/E para girar con
    teclado. V (o el botón de la cámara) la vuelve a poner detrás del jugador con un giro suave.
    La cámara "respira" con tu postura: corriendo se aleja un poco (se nota la velocidad) y agachado
    se acerca y baja (vas a ras de hierba).
    WASD/flechas mueven relativo a la cámara; Mayús corre. D-pad en pantalla. La cámara no
    atraviesa árboles ni casas: se acerca si algo estorba y, de espaldas a un árbol, mira desde arriba.
  - **Ayuda de controles** (arriba a la izquierda, bajo la bolsa): los controles por grupos (moverse,
    cámara, capturar, más). A los 20 s se pliega sola en una pestaña "H · Controles"; H o tocarla la
    abre y la cierra (si la tocas antes, ya no se pliega sola).
  - **Nubes:** sus sombras cruzan despacio el suelo con el viento (se ve cómo se oscurece el césped
    y vuelve el sol); si levantas la cámara, hay nubes blancas lejanas sobre el bosque.
  - Hierba alta 3D que se mece con el viento y se aparta al pasar. Al pisarla saltan briznas que dan
    vueltas y caen planeando: tres por pisada corriendo, una andando y ninguna agachado (se ve el
    ruido que haces).
  - **Hierba pisada:** un Pokémon que cruza la hierba alta corriendo (huyendo de ti o cargando) deja un
    pasillo de matas tumbadas hacia donde iba y aplastadas: se ve por dónde se fue. Siguen así unos
    10 s y luego se levantan poco a poco. Los que pasean no dejan rastro.
  - **Voltereta** (X o el botón del gimnasta): una voltereta rápida de unos 3 m hacia donde te mueves
    (o hacia donde miras). Levanta polvo o briznas, hace ruido y te levanta si ibas agachado; no se
    puede apuntar ni lanzar mientras dura y hay que esperar un momento para dar otra. Si un Pokémon
    te está embistiendo y lo tienes cerca, al rodar se pasa de largo y queda ATURDIDO unos segundos
    ("¡X se pasó de largo! Está aturdido: ¡ahora!", estrellitas girando sobre su cabeza): quieto y
    sin verte, de espaldas a ti. ¡Es el momento de lanzarle una bola por la espalda! Mientras ruedas,
    ninguno te alcanza.
  - Mariposas de colores sobre las flores: se espantan si te acercas (agachado puedes verlas de cerca).
  - **Pájaros:** dos bandadas de gorriones picotean y dan saltitos en el campo abierto. Si te
    acercas salen volando todos a la vez (corriendo desde lejos; agachado te acercas mucho), cruzan
    el cielo y se posan en otro sitio lejos de ti. Una Poké Ball que cae cerca también los espanta.
  - **Arbustos con bayas:** ponte delante de un arbusto y sale "L · Sacudir el arbusto" con las bayas que
    le quedan. Al sacudirlo se balancea, se le caen unas hojas y sus bayas saltan y caen a tus pies: se
    recogen solas y van a la bolsa ("+3 Bayas Frambu"; el contador de bayas está junto a las bolas). Le
    vuelven a crecer poco a poco. Ojo: sacudirlo hace ruido (los Pokémon cercanos se giran a mirar).
  - **Lanzar bayas:** pulsa 4 (o R, o toca la baya en la bolsa) para llevar una baya en la mano. Apunta
    y lanza igual que una bola: con un Pokémon fijado, la baya cae un poco POR DETRÁS de él. Llega
    menos lejos que una bola (se lanza en globo). Si cae lejos de todo, puedes volver a recogerla.
  - **Bayas para distraer:** un Pokémon tranquilo que huele una baya en el suelo (a unos 10 m) va a por
    ella (sale una baya en un bocadillo sobre él) y se la come unos segundos. Mientras come no te ve y
    casi no te oye: como la baya cayó detrás de él, se da la vuelta y te da la espalda. ¡Lánzale una
    bola! "¡Por la espalda! ×2" y "¡Está comiendo! ×1,5" se suman. Una baya junto a la hierba que se
    agita hace asomarse al escondido. Si corres cerca o te ve, deja la baya.
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
  - **Pokémon dormidos:** algunos Pokémon (1 de cada 5 de los que se ven) están DURMIENDO: tumbados,
    respirando despacio y con "Zzz" que suben (en el minimapa, un punto azul claro). No ven nada, pero
    te OYEN: andando te oyen a unos 5 m y corriendo a 11 m; agachado puedes llegar a su lado. Si las
    zetas tiemblan en naranja se está desvelando: párate o agáchate y se le pasa. Si le despiertas
    (ruido, tropezar con él o una bola que cae al lado) da un respingo, "¡X se despertó!", grita, te
    mira un momento y luego huye, se acerca o carga según su carácter. Tumbado en la hierba, la mira
    solo lo fija a menos de 8 m: hay que acercarse. Capturarlo dormido vale el doble: "¡Estaba
    dormido! ×2" (se suma a "por la espalda"; en el Safari también puntúa). Si nadie le molesta, a
    los 90 s se despierta solo. El cartel "Consejo del entrenador" lo explica.
  - **Manadas:** a veces aparecen tres Pokémon de la misma especie juntos: uno guía y los otros le
    siguen al pasear por la hierba. Si UNO te descubre (o se asusta, o se escapa de una bola), avisa
    a los demás ("¡X avisó a su manada!") y se van girando uno tras otro con su "!": los asustadizos
    salen todos corriendo y los agresivos… cargan todos. Si capturas a uno sin que te vean, los otros
    oyen el "¡clic!" y miran alrededor ("?"): quieto o agachado aún puedes capturarlos a todos.
  - **Sigilo:** los Pokémon ven en un cono delante de ellos y oyen tus pasos (correr se oye de lejos).
    Si sospechan sale "?" y se giran; si te descubren, "!" y reaccionan según su carácter: los
    asustadizos huyen, los curiosos se acercan a mirarte y los agresivos (¡rojo!) cargan: si te
    alcanzan empieza el encuentro (combate, de otro equipo). Agáchate con C para ir despacio y en
    silencio; dentro de la hierba alta casi no te ven ("Escondido en la hierba").
  - El encuentro usa por ahora el diálogo provisional (Atrapar / Huir). El combate lo hace otro equipo.
  - **El golpe pesa:** cuando la bola le da, el mundo se congela un instante (el doble si la captura
    va a ser crítica) y en el punto del golpe salta un fogonazo y una onda blanca que se abre (dorada
    si es crítica).
  - **Sacudidas con tensión:** cada sacudida ladea la bola más que la anterior y la espera entre una
    y otra se alarga; tras la última, un silencio más largo antes del "¡clic!" (o del escape). El
    "toc" suena justo cuando empieza cada vaivén.
  - **El final:** si lo capturas, tras el "¡clic!" y las estrellas la bola sale volando en arco y
    se mete en la mochila del entrenador (con un destellito al llegar). Si se escapa, la bola se
    parte: la tapa sale volando, la base se vuelca, un fogonazo corto y saltan chispas.
  - **La bola en la hierba:** la bola que se sacude aparta la hierba alta a su alrededor (queda en
    un claro de matas tumbadas hacia fuera), así se ve bien aunque caiga en mitad del prado.
  - **Esquivan:** un Pokémon que te está vigilando ("?" o "!") y ve venir la bola de frente puede
    apartarse de un salto a un lado ("¡X esquivó la bola! Te vio venir"): los asustadizos a menudo, los
    curiosos a veces, los agresivos nunca (embisten). Con el aro cuesta más esquivarla y un tiro
    "¡Excelente!" no se puede esquivar. De espaldas, comiendo o sin haberte visto, nunca: otra razón
    para acercarse con sigilo. El cartel del prado lo avisa.
  - **Cámara de captura:** cuando la bola le da a un Pokémon, la cámara va sola a verla de cerca
    (en un segundo, sin dar tirones): se ve cómo lo absorbe, cómo cae, cada sacudida con el botón
    rojo y el "¡clic!" con estrellas (o cómo se escapa). Al terminar vuelve detrás del jugador (o al
    hombro, si sigues manteniendo apuntar). Si te mueves, giras la cámara, vuelves a pulsar apuntar
    o lanzas otra cosa, te devuelve el control al instante. En tiros muy cercanos no hace falta y
    no se mueve.
  - **Captura crítica:** cuantas más especies distintas captures, más a menudo (hasta un 25 %) la bola
    brilla en dorado y se decide en una sola sacudida (mucho más fácil).
  - **¿Ya lo tienes?** Sobre los Pokémon cercanos cuya especie ya capturaste sale una Poké Ball
    pequeña. Al apuntar, encima de la mira aparece el nombre del fijado con "¡Nuevo!" si aún no lo
    tienes (o su Poké Ball si ya lo tienes): así sabes a cuál merece la pena ir.
  - **Tus capturas:** cada captura enseña una tarjeta (arte, número, tipos, bola y "¡Nuevo!" si es
    la primera de su especie). Pulsa P (o toca "Capturados") para ver todas tus cartas.
  - **Minimapa** (arriba a la derecha): gira con la cámara (arriba = adelante), "N" = norte. Puntos
    rojos = Poké Balls en el suelo; Pokémon en blanco (tranquilo), amarillo (sospecha), naranja (te vio)
    o rojo latiendo (viene a por ti). Tocarlo abre el mapa grande.
  - **Mapa grande** (tecla M o tocar el minimapa): todo el mundo con el norte arriba. Flecha amarilla =
    tú (y un cono claro hacia donde mira la cámara), carteles, arbustos con el número de bayas que les
    quedan (aro gris si están vacíos), Poké Balls y bayas del suelo. Los Pokémon solo salen dentro del
    círculo de lo que alcanzas a ver (como en el minimapa; los escondidos nunca). El mundo se congela
    mientras está abierto; M o la X lo cierran.
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
  - **Reto Safari** (opcional; botón "Reto Safari" a la derecha, bajo el altavoz): te explica las
    reglas y, si aceptas, 10 minutos con 25 Poké Balls PROPIAS del reto (tu bolsa no se toca). No hay
    bolas en el suelo y las que falles se pierden; tus bayas sí sirven. Arriba a la izquierda, en vez
    de la bolsa, el marcador: reloj (rojo en el último minuto; se para si pausas o abres un panel),
    bolas y bayas (tócalas para llevarlas en la mano), capturas y "Abandonar". Termina al acabarse el
    tiempo, al resolverse la última bola o al abandonar (sin perder nada): sale un resumen con lo
    capturado y vuelves al modo libre con todo como estaba.
    **Puntos (solo en el reto):** cada captura vale por lo rara que es (100 un Pokémon fácil, ~240 uno
    normal, hasta ~920 un legendario) multiplicado por cómo fue el tiro: sin ser visto ×1,5 o por la
    espalda ×2, comiendo ×1,5 y el aro ×1,2/×1,5/×2. El marcador enseña "Capturas: N · P pts" y el
    resumen, cada captura con su cuenta ("238 ×3 … +714") y el total.
    **Huyen (solo en el reto):** si uno se escapa de la bola, puede HUIR para siempre ("¡El X salvaje
    huyó!"): sale corriendo lejos de ti (tumbando la hierba) y desaparece. Pasa más con los raros
    (1 de cada 10 los fáciles, casi la mitad los normales y raros) y la mitad de veces si le diste
    mientras se comía una baya. Fuera del reto nunca huyen.
  - **Variocolor (shiny):** 1 de cada 100 Pokémon sale con sus colores raros (el arte variocolor oficial).
    Al verlo cerca por primera vez: aviso dorado "¡Un X VARIOCOLOR! Qué suerte", un corro grande de
    destellos y un sonido de campanitas; luego brilla a ratos. Se captura igual (solo es cosmético); su
    tarjeta dice "Variocolor" y en "Mis capturas" sale con su arte raro y una estrellita.
  - **Sonido** (en la web): "¡fiu!" al lanzar, un zumbido cuando la bola lo absorbe, un "toc" por cada
    sacudida (más fuerte y con destellos si es crítica), "¡clic!" y fanfarria al capturar o "¡pop!" si
    se escapa; también al recoger bolas o bayas y al sacudir arbustos. Los Pokémon GRITAN (su grito
    real de PokeAPI) cuando te descubren, cuando salen asustados de la hierba y al escaparse de la
    bola. Las PISADAS suenan según el suelo (golpe sordo en la tierra, clic en las losas, roce en el
    césped y un crujido en la hierba alta) y tan fuerte como te oyen los Pokémon: corriendo mucho,
    agachado casi nada. Tecla N o el altavoz bajo el minimapa para silenciar. En Windows, por ahora, sin sonido.
  - **El aro que se encoge:** al apuntar a un Pokémon con una bola, dentro del anillo del % hay un aro
    que se encoge (en 1,6 s) y vuelve a empezar. Lanza cuando esté pequeño: blanco = sin bonus, azul =
    "¡Bien!" ×1,2, violeta = "¡Genial!" ×1,5 y dorado (el más pequeño, dura un suspiro) = "¡Excelente!"
    ×2. Cuenta el momento en que PULSAS lanzar y se suma al sigilo y a la baya. Si la bola da, se ve
    sobre el Pokémon junto a los demás bonus. Lanzar sin apuntar no tiene aro.

## Cómo probar la captura
1. Jugar 3D → ve hacia el prado de hierba alta (arriba a la derecha al empezar).
2. Mantén clic derecho: mira, arco y anillo con el %. Suelta clic izquierdo para lanzar.
3. Recoge bolas brillantes del suelo (y las que falles). Cambia de bola con R o 1-2-3.
4. Agáchate (C) en la hierba alta y acércate por la espalda: sin "?" ni "!" la captura es más fácil.
5. Con bayas: sacude un arbusto (L), pulsa 4 y lanza la baya a un Pokémon tranquilo (cae detrás de él).
   Cuando se ponga a comer (bocadillo con la baya), pulsa 1 y lánzale una bola por la espalda.

## Cómo probar el 3D
1. Menú → **Jugar 3D**. Espera a que cargue (círculo de progreso).
2. Gira la cámara arrastrando con el ratón; acércate con la rueda.
3. Camina hacia el prado de hierba alta (a la derecha del camino al empezar).
4. Acércate a un Pokémon o camina por la hierba: aparece el diálogo del encuentro.
