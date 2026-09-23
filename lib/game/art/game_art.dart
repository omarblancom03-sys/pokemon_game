import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';

/// EL ARTE del juego ya cargado en memoria. Origen y licencia (CC0) en
/// `assets/CREDITS.md`.
///
/// Es opcional: si PokeGame no lo recibe, dibuja todo con figuras simples
/// (así los tests no tienen que cargar imágenes).
class GameArt {
  GameArt._(this._tiles, this.ashSheet);

  /// Archivos dentro de `assets/images/` (Flame busca ahí por defecto).
  static const tilesFile = 'tiny_town.png';
  static const ashFile = 'ash.png';

  /// Medidas en píxeles del arte original (antes de ampliarlo x3).
  static const tilePixels = 16.0;
  static const tilesPerRow = 12;
  static const ashFramePixels = (width: 14.0, height: 22.0);
  static const ashFramesPerRow = 6;

  /// Carga las dos imágenes. Se llama una vez, al montar la escena.
  static Future<GameArt> load(Images images) async {
    final loaded = await images.loadAll([tilesFile, ashFile]);
    return GameArt._(loaded[0], loaded[1]);
  }

  final Image _tiles;

  /// Hoja de Ash: 4 filas (abajo, izquierda, derecha, arriba) x 6 pasos.
  final Image ashSheet;

  /// Recorta la baldosa número [index] del tileset (se cuenta de izquierda
  /// a derecha y de arriba abajo, empezando en 0).
  Sprite tile(int index) => Sprite(
    _tiles,
    srcPosition: Vector2(
      (index % tilesPerRow) * tilePixels,
      (index ~/ tilesPerRow) * tilePixels,
    ),
    srcSize: Vector2.all(tilePixels),
  );

  /// Posición (en píxeles de la imagen) de la baldosa [index]: la usa el
  /// SpriteBatch, que pinta muchas baldosas de una sola vez.
  Rect tileSource(int index) => Rect.fromLTWH(
    (index % tilesPerRow) * tilePixels,
    (index ~/ tilesPerRow) * tilePixels,
    tilePixels,
    tilePixels,
  );

  Image get tilesImage => _tiles;
}

/// Números de baldosa de Kenney "Tiny Town" que usa el juego.
abstract final class TinyTown {
  static const grass = 0;
  static const tallGrass = 1;
  static const flowers = 2;
  static const stone = 43;
  static const mushroom = 29;

  static const tree = 16;
  static const pine = 4;
  static const autumnTree = 15;
  static const bush = 5;
  static const sign = 83;

  /// Camino de tierra en 9 piezas: [fila][columna] con bordes de césped.
  static const path = [
    [12, 13, 14],
    [24, 25, 26],
    [36, 37, 38],
  ];

  /// Valla horizontal: extremo izquierdo, tramo, extremo derecho.
  static const fenceLeft = 80;
  static const fenceMiddle = 81;
  static const fenceRight = 82;

  /// Casa de techo rojo: dos filas de techo (izquierda, centro, derecha)
  /// y una de pared (ventana, puerta, pared, esquina).
  static const roofTop = [52, 53, 54];
  static const roofBottom = [64, 65, 66];
  static const wallWindow = 84;
  static const wallDoor = 85;
  static const wall = 73;
  static const wallRight = 75;
}
