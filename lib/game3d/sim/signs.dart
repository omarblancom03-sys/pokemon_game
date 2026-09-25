import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../../game/map/map_layout.dart';

/// Una casilla del mapa.
typedef MapCell = ({int col, int row});

/// CARTELES que se pueden leer (Dart puro): cuál tiene el jugador delante
/// y cuál está abierto. Aquí solo hay casillas; lo que pone cada cartel es
/// contenido del mapa (ver `world_signs.dart`) y lo muestra la vista.
class SignReader {
  SignReader({required this.signs, required this.tileSize});

  /// Todos los carteles (`s`) de [layout].
  factory SignReader.fromLayout(MapLayout layout, double tileSize) =>
      SignReader(
        signs: [
          for (var row = 0; row < layout.rows; row++)
            for (var col = 0; col < layout.columns; col++)
              if (layout.tileAt(col, row) == TileKind.sign)
                (col: col, row: row),
        ],
        tileSize: tileSize,
      );

  final List<MapCell> signs;
  final double tileSize;

  /// Se lee desde esta distancia (m, al centro de su casilla): pegado a
  /// ella, porque el cartel no se pisa.
  static const readRange = 2.6;

  /// Si te alejas más que esto, el cartel abierto se cierra solo.
  static const closeRange = 3.6;

  /// Hay que mirarlo: como mucho a 80° de hacia donde mira el jugador.
  static final _minFacingCos = math.cos(80 * math.pi / 180);

  /// Cartel que se está leyendo (null = ninguno).
  MapCell? open;

  Vector3 _center(MapCell c) =>
      Vector3((c.col + 0.5) * tileSize, 0, (c.row + 0.5) * tileSize);

  /// El cartel que el jugador en [player], mirando hacia [facing] (rad),
  /// podría leer ahora: el más cercano a su alcance y delante de él.
  MapCell? readable(Vector3 player, double facing) {
    final forward = Vector3(math.sin(facing), 0, math.cos(facing));
    MapCell? best;
    var bestDistance = double.infinity;
    for (final sign in signs) {
      final to = _center(sign) - player
        ..y = 0;
      final d = to.length;
      if (d > readRange || d >= bestDistance) continue;
      if (d > 1e-6 && to.dot(forward) / d < _minFacingCos) continue;
      best = sign;
      bestDistance = d;
    }
    return best;
  }

  /// Leer o dejar de leer (tecla / botón): si hay uno abierto se cierra; si
  /// no, se abre el que se puede leer. Devuelve si algo cambió.
  bool toggle(Vector3 player, double facing) {
    if (open != null) {
      open = null;
      return true;
    }
    open = readable(player, facing);
    return open != null;
  }

  /// Cierra el cartel abierto si el jugador se ha alejado.
  void update(Vector3 player) {
    final sign = open;
    if (sign == null) return;
    final to = _center(sign) - player
      ..y = 0;
    if (to.length > closeRange) open = null;
  }
}
