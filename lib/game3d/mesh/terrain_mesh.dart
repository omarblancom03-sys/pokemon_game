import 'package:vector_math/vector_math.dart';

import '../../game/map/map_layout.dart';
import '../sim/cell_noise.dart';
import 'mesh_builder.dart';

/// Color BASE del suelo según lo que hay en la casilla (sRGB → lineal).
/// Bajo árboles, casas o vallas hay césped.
Vector4 groundColor(TileKind kind) => switch (kind) {
  TileKind.path => srgb(0xD6BE8A),
  TileKind.stone => srgb(0xB4AFA5),
  TileKind.flowers => srgb(0x74BE56),
  TileKind.tallGrass => srgb(0x3C9738),
  _ => srgb(0x78C45C),
};

/// Tonos de las zonas de césped más frondosas (verde intenso) y más secas
/// (amarillentas).
final _lushGrass = srgb(0x5AAE48);
final _dryGrass = srgb(0xA2C258);

/// ¿Crece césped en esta casilla? (no en caminos, losas ni hierba alta)
bool _isLawn(TileKind kind) =>
    kind != TileKind.path &&
    kind != TileKind.stone &&
    kind != TileKind.tallGrass;

/// Color del suelo en el punto (x, z) (metros) de una casilla [kind]: el
/// base con manchas grandes más claras u oscuras, zonas de césped más
/// frondosas o más secas y un granulado fino. Solo depende del tipo y de
/// la posición, así que dos casillas vecinas del mismo tipo se funden sin
/// costuras.
Vector4 groundColorAt(TileKind kind, double x, double z) {
  final tall = kind == TileKind.tallGrass;
  // Manchas de ~6 m: ±15 % de brillo (menos en la hierba alta, ya oscura).
  final patches = (smoothNoise(x / 6, z / 6, 1) - 0.5) * (tall ? 0.16 : 0.3);
  // Granulado: un poco distinto en cada vértice (cada 1 m).
  final grain = (cellNoise((x * 2).round(), (z * 2).round(), 7) - 0.5) * 0.08;
  var color = groundColor(kind);
  if (_isLawn(kind)) {
    // Zonas de ~11 m: donde el ruido es bajo, frondoso; donde es alto, seco.
    final m = smoothNoise(x / 11, z / 11, 2);
    final lush = ((0.42 - m) / 0.22).clamp(0.0, 1.0);
    final dry = ((m - 0.55) / 0.22).clamp(0.0, 1.0);
    color = color + (_lushGrass - color) * (lush * 0.6);
    color = color + (_dryGrass - color) * (dry * 0.6);
  }
  final light = 1 + patches + grain;
  return Vector4(color.x * light, color.y * light, color.z * light, 1);
}

/// Subdivisiones por lado de cada casilla: más vértices = manchas más
/// suaves (cada vértice tiene su color y la GPU los mezcla).
const terrainSubdivisions = 2;

/// Suelo del mundo: cada casilla en 2x2 cuadrados con color por vértice.
/// Plano (y = 0) para que la física del jugador sea simple y exacta.
MeshBuffers buildTerrain(MapLayout layout, double tileSize) {
  final builder = MeshBuilder();
  const sub = terrainSubdivisions;
  final step = tileSize / sub;
  for (var row = 0; row < layout.rows; row++) {
    for (var col = 0; col < layout.columns; col++) {
      final kind = layout.tileAt(col, row)!;
      for (var sz = 0; sz < sub; sz++) {
        for (var sx = 0; sx < sub; sx++) {
          final x0 = col * tileSize + sx * step, x1 = x0 + step;
          final z0 = row * tileSize + sz * step, z1 = z0 + step;
          builder.shadedQuad(
            Vector3(x0, 0, z0),
            Vector3(x0, 0, z1),
            Vector3(x1, 0, z1),
            Vector3(x1, 0, z0),
            groundColorAt(kind, x0, z0),
            groundColorAt(kind, x0, z1),
            groundColorAt(kind, x1, z1),
            groundColorAt(kind, x1, z0),
          );
        }
      }
    }
  }
  return builder.build();
}
