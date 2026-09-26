/// Lo que pone un cartel: un título y el texto.
class SignText {
  const SignText(this.title, this.body);

  final String title;
  final String body;
}

/// LOS CARTELES DEL MUNDO ([worldMapRows], casillas `s`): qué pone cada
/// uno, por casilla. Es contenido del mapa, como el propio dibujo ASCII;
/// además sirven de tutorial dentro del juego (sigilo y captura).
///
/// Si se añade un `s` al mapa sin texto aquí, se lee [unreadableSign].
const Map<({int col, int row}), SignText> worldSigns = {
  (col: 7, row: 7): SignText(
    'Pueblo Paleta',
    'Tonos de un comienzo inmaculado.\n'
        'Al este, el prado de hierba alta. Al sur, más hierba y un jardín.',
  ),
  (col: 21, row: 10): SignText(
    'Prado de hierba alta',
    '¡Cuidado: Pokémon salvajes!\n'
        'Agáchate (C) y acércate por la espalda: si no te ven, la Poké Ball '
        'atrapa mejor (×1,5 sin ser visto, ×2 por la espalda). Si te miran, '
        '¡pueden esquivarla de un salto!',
  ),
  (col: 14, row: 15): SignText(
    'Consejo del entrenador',
    '¿La hierba se agita y saltan briznas? Hay un Pokémon escondido.\n'
        'Si llegas agachado se asoma sin verte. Si corres, sale asustado. '
        'También puedes lanzar la bola a la mata… ¡y pillarlo por sorpresa!',
  ),
  (col: 20, row: 17): SignText(
    'Tienda de Poké Balls (cerrada)',
    'Vuelva pronto. Mientras tanto, busca bolas que brillan por el campo.\n'
        'Súper Ball ×1,5 · Ultra Ball ×2. Si fallas, la bola queda en el '
        'suelo: ¡recógela!',
  ),
};

/// Un cartel sin texto propio.
const unreadableSign = SignText(
  'Cartel',
  'Las letras están tan gastadas que no se pueden leer.',
);

/// Qué pone el cartel de la casilla ([col], [row]).
SignText signTextAt(int col, int row) =>
    worldSigns[(col: col, row: row)] ?? unreadableSign;
