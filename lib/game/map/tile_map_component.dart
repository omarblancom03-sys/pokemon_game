import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../art/game_art.dart';
import 'map_layout.dart';

/// Construye el mapa con el arte de Kenney. Devuelve dos cosas:
///
/// 1. El SUELO (césped, camino, piedra, flores): una sola capa plana que va
///    por debajo de todo.
/// 2. Los OBJETOS ALTOS (árboles, casas, vallas...): un componente por
///    objeto, con `priority` = su borde inferior. Flame pinta primero lo de
///    prioridad baja, así que lo que está más abajo en pantalla queda
///    delante. Ash hace lo mismo, y por eso puede pasar por detrás de un
///    árbol ("y-sorting").
List<Component> buildTileMap({
  required MapLayout layout,
  required GameArt art,
  required double tileSize,
}) {
  return [
    _GroundLayer(layout: layout, art: art, tileSize: tileSize),
    ..._buildObjects(layout, art, tileSize),
  ];
}

/// Prioridad del suelo: siempre por debajo de cualquier objeto.
const groundPriority = -1;

class _GroundLayer extends SpriteBatchComponent {
  _GroundLayer({
    required this.layout,
    required this.art,
    required this.tileSize,
  }) : super(priority: groundPriority);

  final MapLayout layout;
  final GameArt art;
  final double tileSize;

  @override
  Future<void> onLoad() async {
    // SpriteBatch: pinta cientos de baldosas en una sola llamada (rápido).
    final batch = SpriteBatch(art.tilesImage);
    final scale = tileSize / GameArt.tilePixels;
    for (var row = 0; row < layout.rows; row++) {
      for (var col = 0; col < layout.columns; col++) {
        final offset = Vector2(col * tileSize, row * tileSize);
        for (final index in _groundTiles(col, row)) {
          // bleed: agranda un pelo cada baldosa para que no se vean
          // rayitas entre ellas al mover la cámara.
          batch.add(
            source: art.tileSource(index),
            offset: offset,
            scale: scale,
            bleed: 0.5,
          );
        }
      }
    }
    spriteBatch = batch;
  }

  /// Baldosas del suelo de una casilla, de abajo arriba. Debajo de los
  /// objetos (árboles, casas...) se pone césped para que no quede un hueco.
  List<int> _groundTiles(int col, int row) {
    return switch (layout.tileAt(col, row)!) {
      TileKind.path => [_pathTile(col, row)],
      TileKind.stone => [TinyTown.stone],
      TileKind.flowers => [TinyTown.flowers],
      TileKind.tallGrass => [TinyTown.tallGrass],
      TileKind.mushroom => [TinyTown.grass, TinyTown.mushroom],
      _ => [TinyTown.grass],
    };
  }

  /// Elige la pieza del camino según sus vecinos: si arriba no hay camino,
  /// usa la pieza con borde de césped arriba, y así con cada lado.
  int _pathTile(int col, int row) {
    bool isPath(int c, int r) =>
        !layout.contains(c, r) || layout.tileAt(c, r) == TileKind.path;
    final r = isPath(col, row - 1) ? (isPath(col, row + 1) ? 1 : 2) : 0;
    final c = isPath(col - 1, row) ? (isPath(col + 1, row) ? 1 : 2) : 0;
    return TinyTown.path[r][c];
  }
}

Iterable<Component> _buildObjects(
  MapLayout layout,
  GameArt art,
  double tileSize,
) sync* {
  bool isKind(int col, int row, TileKind kind) =>
      layout.tileAt(col, row) == kind;

  for (var row = 0; row < layout.rows; row++) {
    for (var col = 0; col < layout.columns; col++) {
      final kind = layout.tileAt(col, row)!;
      final index = switch (kind) {
        TileKind.tree => TinyTown.tree,
        TileKind.pine => TinyTown.pine,
        TileKind.autumnTree => TinyTown.autumnTree,
        TileKind.bush => TinyTown.bush,
        TileKind.sign => TinyTown.sign,
        TileKind.fence =>
          !isKind(col - 1, row, TileKind.fence)
              ? TinyTown.fenceLeft
              : !isKind(col + 1, row, TileKind.fence)
              ? TinyTown.fenceRight
              : TinyTown.fenceMiddle,
        TileKind.house => _houseTile(layout, col, row),
        _ => null, // suelo: ya lo pinta _GroundLayer
      };
      if (index == null) continue;

      // Toda la casa comparte la prioridad de su fila de abajo, para que se
      // ordene como UN objeto y no baldosa a baldosa.
      var bottomRow = row;
      if (kind == TileKind.house) {
        while (isKind(col, bottomRow + 1, TileKind.house)) {
          bottomRow++;
        }
      }
      yield SpriteComponent(
        sprite: art.tile(index),
        position: Vector2(col * tileSize, row * tileSize),
        size: Vector2.all(tileSize),
        priority: ((bottomRow + 1) * tileSize).round(),
      );
    }
  }
}

/// Qué pieza de la casa va en esta casilla. Cada bloque de `H` del mapa es
/// una casa: las dos primeras filas son techo y la última, pared con puerta.
int _houseTile(MapLayout layout, int col, int row) {
  bool isHouse(int c, int r) => layout.tileAt(c, r) == TileKind.house;
  // Busca la esquina superior izquierda de esta casa.
  var left = col;
  while (isHouse(left - 1, row)) {
    left--;
  }
  var top = row;
  while (isHouse(col, top - 1)) {
    top--;
  }
  final x = col - left;
  final y = row - top;
  final isLastCol = !isHouse(col + 1, row);
  final isLastRow = !isHouse(col, row + 1);

  if (isLastRow) {
    if (isLastCol) return TinyTown.wallRight;
    return switch (x) {
      0 => TinyTown.wallWindow,
      1 => TinyTown.wallDoor,
      _ => TinyTown.wall,
    };
  }
  final roof = y == 0 ? TinyTown.roofTop : TinyTown.roofBottom;
  return roof[x == 0 ? 0 : (isLastCol ? 2 : 1)];
}
