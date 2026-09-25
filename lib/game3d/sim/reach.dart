import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

/// Una casilla del mapa.
typedef MapCell = ({int col, int row});

/// Centro de una casilla en el suelo (m).
Vector3 cellCenterOf(MapCell c, double tileSize) =>
    Vector3((c.col + 0.5) * tileSize, 0, (c.row + 0.5) * tileSize);

/// Hay que mirar lo que se quiere usar: como mucho a 80° de hacia donde
/// mira el jugador.
final _minFacingCos = math.cos(80 * math.pi / 180);

/// La casilla de [cells] que el jugador en [player], mirando hacia
/// [facing] (rad), tiene a mano: la más cercana a menos de [range] m (del
/// centro de la casilla) y delante de él. null si no hay ninguna.
///
/// La usan los carteles (leer) y los arbustos (sacudir): un objeto que no
/// se pisa se usa pegado a él y mirándolo.
MapCell? nearestInReach(
  Iterable<MapCell> cells,
  Vector3 player,
  double facing, {
  required double tileSize,
  required double range,
}) {
  final forward = Vector3(math.sin(facing), 0, math.cos(facing));
  MapCell? best;
  var bestDistance = double.infinity;
  for (final cell in cells) {
    final to = cellCenterOf(cell, tileSize) - player
      ..y = 0;
    final d = to.length;
    if (d > range || d >= bestDistance) continue;
    if (d > 1e-6 && to.dot(forward) / d < _minFacingCos) continue;
    best = cell;
    bestDistance = d;
  }
  return best;
}
