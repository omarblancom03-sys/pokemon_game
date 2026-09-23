# PROGRESO — qué funciona y cómo probarlo

## Cómo ejecutar
- Web: `flutter build web` y `node tool/serve_web.mjs 5500` → http://localhost:5500
- Windows: `flutter run -d windows` (necesita Visual Studio con C++; ver DECISIONES.md)
- Tests: `flutter analyze` y `flutter test`

## Estado
- **Menú:** Jugar 2D · Jugar 3D · Pokédex · Generaciones.
- **2D (Flame):** mapa de baldosas, Ash animado, humos que disparan encuentros.
- **3D (flutter_scene):**
  - Mundo low-poly generado por código a partir del mismo mapa ASCII del 2D: césped, caminos, casas con
    tejado, árboles, pinos, árboles otoñales, arbustos con bayas, vallas, setas, flores y un bosque que
    rodea el mapa. Luz de sol con sombras, cielo en degradado, niebla ligera y aspecto "stylized".
  - Entrenador low-poly (gorra, chaqueta, mochila) con ciclo de caminar y carrera.
  - Cámara en tercera persona: arrastrar con el ratón para girar, rueda para zoom, Q/E para girar con
    teclado. WASD/flechas mueven relativo a la cámara; Mayús corre. D-pad en pantalla.
  - Hierba alta 3D que se mece con el viento y se aparta al pasar.
  - Pokémon salvajes VISIBLES (arte oficial de PokeAPI) que deambulan por la hierba alta; al tocarlos
    empieza el encuentro. Andar por la hierba también puede dar encuentros al azar.
  - El encuentro usa por ahora el diálogo provisional (Atrapar / Huir). El combate llega en la Fase 8.6.

## Cómo probar el 3D
1. Menú → **Jugar 3D**. Espera a que cargue (círculo de progreso).
2. Gira la cámara arrastrando con el ratón; acércate con la rueda.
3. Camina hacia el prado de hierba alta (a la derecha del camino al empezar).
4. Acércate a un Pokémon o camina por la hierba: aparece el diálogo del encuentro.
