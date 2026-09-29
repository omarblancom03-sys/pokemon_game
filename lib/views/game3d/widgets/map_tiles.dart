import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../game/map/map_layout.dart';
import '../../../game3d/mesh/props.dart' show findHouseBlocks;
import '../../../game3d/sim/minimap.dart';

/// Colores de los mapas (minimapa y mapa grande), parecidos a los del mundo
/// 3D.
abstract final class MapColors {
  static const forest = Color(0xFF1E5631);
  static const grass = Color(0xFF7CC35A);
  static const flowers = Color(0xFF93CC6A);
  static const tallGrass = Color(0xFF2F8F3F);
  static const path = Color(0xFFE6D29C);
  static const stone = Color(0xFFC9C4BA);
  static const tree = Color(0xFF2E7D32);
  static const pine = Color(0xFF1F5E3A);
  static const autumn = Color(0xFFE0762F);
  static const bush = Color(0xFF3E9B4A);
  static const berry = Color(0xFFD8384A);
  static const wood = Color(0xFF8E6639);
  static const wall = Color(0xFFF4EBDD);

  /// En el mismo orden que los tejados del mundo 3D (props.dart).
  static const roofs = [
    Color(0xFFD8453C),
    Color(0xFF3A74C9),
    Color(0xFF3C9A5B),
  ];

  static Color forMark(MinimapMark mark) => switch (mark) {
    MinimapMark.ball => const Color(0xFFE53935),
    MinimapMark.calm => Colors.white,
    MinimapMark.asleep => const Color(0xFF80D8FF),
    MinimapMark.suspicious => Colors.amberAccent,
    MinimapMark.alert => Colors.orangeAccent,
    MinimapMark.hostile => Colors.redAccent,
  };
}

/// Dibuja el mapa en metros: suelo por casillas, luego árboles (círculos),
/// vallas, carteles y casas (con el color de su tejado).
ui.Picture recordMapTiles(MapLayout layout, double tile) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // El suelo sin suavizado de bordes: con él, entre dos casillas del mismo
  // color se ve una rendija (una rejilla al girar el mapa).
  final paint = Paint()..isAntiAlias = false;
  for (var row = 0; row < layout.rows; row++) {
    for (var col = 0; col < layout.columns; col++) {
      final kind = layout.tileAt(col, row)!;
      paint.color = switch (kind) {
        TileKind.tallGrass => MapColors.tallGrass,
        TileKind.path => MapColors.path,
        TileKind.stone => MapColors.stone,
        TileKind.flowers => MapColors.flowers,
        _ => MapColors.grass,
      };
      canvas.drawRect(Rect.fromLTWH(col * tile, row * tile, tile, tile), paint);
    }
  }
  paint.isAntiAlias = true;
  for (var row = 0; row < layout.rows; row++) {
    for (var col = 0; col < layout.columns; col++) {
      final center = Offset((col + 0.5) * tile, (row + 0.5) * tile);
      switch (layout.tileAt(col, row)!) {
        case TileKind.tree:
          canvas.drawCircle(center, tile * 0.48, paint..color = MapColors.tree);
        case TileKind.pine:
          canvas.drawCircle(center, tile * 0.45, paint..color = MapColors.pine);
        case TileKind.autumnTree:
          canvas.drawCircle(
            center,
            tile * 0.48,
            paint..color = MapColors.autumn,
          );
        case TileKind.bush:
          canvas.drawCircle(center, tile * 0.35, paint..color = MapColors.bush);
        case TileKind.fence:
          canvas.drawRect(
            Rect.fromCenter(center: center, width: tile, height: tile * 0.2),
            paint..color = MapColors.wood,
          );
        case TileKind.sign:
          canvas.drawRect(
            Rect.fromCenter(
              center: center,
              width: tile * 0.5,
              height: tile * 0.3,
            ),
            paint..color = MapColors.wood,
          );
        default:
          break;
      }
    }
  }
  final houses = findHouseBlocks(layout);
  for (var i = 0; i < houses.length; i++) {
    final h = houses[i];
    final rect = Rect.fromLTWH(
      h.col * tile,
      h.row * tile,
      h.width * tile,
      h.height * tile,
    ).deflate(tile * 0.08);
    canvas
      ..drawRect(rect, paint..color = MapColors.wall)
      ..drawRect(
        rect.deflate(tile * 0.18),
        paint..color = MapColors.roofs[i % MapColors.roofs.length],
      );
  }
  return recorder.endRecording();
}
