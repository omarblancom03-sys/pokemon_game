import 'dart:ui';

import 'package:flame/components.dart';

import '../map/map_layout.dart';

/// Mapa PROVISIONAL: pinta el mismo [MapLayout] que la versión con arte,
/// pero con un cuadrado de color por casilla. Se usa cuando el juego no
/// recibe imágenes (en los tests), así la lógica se prueba sin cargar nada.
class MapComponent extends PositionComponent {
  MapComponent({required this.layout, required this.tileSize})
    // priority -1: se dibuja por debajo de todo lo demás.
    : super(
        size: Vector2(layout.columns * tileSize, layout.rows * tileSize),
        priority: -1,
      );

  final MapLayout layout;
  final double tileSize;

  // Paint = "brocha": el color con el que se pinta cada tipo de casilla.
  static final _paints = <TileKind, Paint>{
    for (final (kind, color) in const [
      (TileKind.grass, Color(0xFF7EC850)),
      (TileKind.flowers, Color(0xFF9ED86A)),
      (TileKind.tallGrass, Color(0xFF4E9A2E)),
      (TileKind.path, Color(0xFFD9B77A)),
      (TileKind.stone, Color(0xFFB0B7C0)),
      (TileKind.mushroom, Color(0xFF7EC850)),
      (TileKind.tree, Color(0xFF2E7D32)),
      (TileKind.pine, Color(0xFF1B5E20)),
      (TileKind.autumnTree, Color(0xFFE0A030)),
      (TileKind.bush, Color(0xFF388E3C)),
      (TileKind.fence, Color(0xFF8D5A2B)),
      (TileKind.sign, Color(0xFF8D5A2B)),
      (TileKind.house, Color(0xFFC0503A)),
    ])
      kind: Paint()..color = color,
  };

  /// render: dibuja el fotograma. Se ejecuta ~60 veces por segundo.
  @override
  void render(Canvas canvas) {
    for (var row = 0; row < layout.rows; row++) {
      for (var col = 0; col < layout.columns; col++) {
        canvas.drawRect(
          Rect.fromLTWH(col * tileSize, row * tileSize, tileSize, tileSize),
          _paints[layout.tileAt(col, row)]!,
        );
      }
    }
  }
}
