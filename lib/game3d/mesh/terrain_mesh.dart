import 'package:vector_math/vector_math.dart';

import '../../game/map/map_layout.dart';
import 'mesh_builder.dart';

/// Color del suelo según lo que hay en la casilla (colores sRGB → lineal).
Vector4 groundColor(TileKind kind, int col, int row) {
  // Un leve damero da textura al césped sin necesidad de imágenes.
  final checker = (col + row).isEven;
  return switch (kind) {
    TileKind.path => srgb(checker ? 0xD9C18E : 0xD2B985),
    TileKind.stone => srgb(checker ? 0xB9B4AA : 0xAFAAA0),
    TileKind.flowers => srgb(checker ? 0x78C25A : 0x70BA52),
    TileKind.tallGrass => srgb(checker ? 0x3E9A3A : 0x3A9436),
    _ => srgb(checker ? 0x7CC860 : 0x74C058),
  };
}

/// Suelo del mundo: un cuadrado por casilla, del color de su tipo.
/// Plano (y = 0) para que la física del jugador sea simple y exacta.
MeshBuffers buildTerrain(MapLayout layout, double tileSize) {
  final builder = MeshBuilder();
  for (var row = 0; row < layout.rows; row++) {
    for (var col = 0; col < layout.columns; col++) {
      final kind = layout.tileAt(col, row)!;
      final x0 = col * tileSize, x1 = x0 + tileSize;
      final z0 = row * tileSize, z1 = z0 + tileSize;
      builder.quad(
        Vector3(x0, 0, z0),
        Vector3(x0, 0, z1),
        Vector3(x1, 0, z1),
        Vector3(x1, 0, z0),
        groundColor(kind, col, row),
      );
    }
  }
  return builder.build();
}
