/// El mundo del juego dibujado en ASCII: una fila por cadena, un carácter
/// por baldosa. Leyenda en [TileKind] (map_layout.dart); `@` = inicio de Ash.
///
/// Se generó una vez con un script y se retocó a mano. Para cambiar el mapa
/// basta con editar estas líneas (todas deben medir lo mismo).
const List<String> worldMapRows = [
  'PTTTPPTTPTTTPPPTTTPPTTTPTPTTTPTTTT',
  'T...............==...............T',
  'T.......,.......==...""""T"""""",P',
  'T..HHHH..HHHH...==..."T""""""""T.T',
  'T.,HHHH..HHHH...==..."""""""T""".T',
  'P..HHHH..HHHH...==..."""""m"""m".P',
  'T...o.....o.....==..."""A""""""".P',
  'P...o..s..o.....==...""""""""T"".T',
  'T.##o#####o###..==...T"""""""""".T',
  'T...o.....o.....==...""T"""A""A".T',
  'P.b.o.....o...b.==...s....b......P',
  'T...o.....o.....==............,..P',
  'T===============@================P',
  'T================================T',
  'T.......,.......==...............P',
  'T..T..,..,.T..s.==.......,..T....P',
  'P."""""""""""...==.b,HHHH.b......T',
  'T."""""""""""...==..sHHHH........T',
  'P.""",,,,,"""...==...HHHH.....T..T',
  'P.""",,,,,"""T..==oooooooo.,.....T',
  'P.""",,,,,"""...==oooooooo.......T',
  'T."""""""""""...==.........P.....T',
  'T."""""""""""...==............,P.T',
  'P.T....T..b.....==..P............P',
  'T...............==...............T',
  'TTTTTPPPTTPTTTPTTTTTPTTTTTTTTPTPPT',
];
