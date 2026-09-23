import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../../game/map/map_layout.dart';
import 'mesh_builder.dart';

/// Paleta del mundo (sRGB → lineal). Colores vivos, estilo Pokémon.
abstract final class Palette {
  static final trunk = srgb(0x7A5234);
  static final trunkDark = srgb(0x5E3E27);
  static final leaf = srgb(0x3FA34D);
  static final leafLight = srgb(0x5DBB4F);
  static final pine = srgb(0x2E7D4F);
  static final pineDark = srgb(0x23633E);
  static final autumn = srgb(0xE0762F);
  static final autumnLight = srgb(0xF2A13B);
  static final bush = srgb(0x2F8F3F);
  static final berry = srgb(0xD8384A);
  static final wood = srgb(0xC89B63);
  static final woodDark = srgb(0x8E6639);
  static final wall = srgb(0xF4EBDD);
  static final wallShade = srgb(0xE3D6C2);
  static final roofRed = srgb(0xD8453C);
  static final roofBlue = srgb(0x3A74C9);
  static final roofGreen = srgb(0x3C9A5B);
  static final door = srgb(0x8A5A34);
  static final window = srgb(0x9ED8F0);
  static final chimney = srgb(0xA9A39A);
  static final stone = srgb(0xC9C4BA);
  static final mushroomCap = srgb(0xE5413B);
  static final mushroomStem = srgb(0xF6EFE0);
  static final signBoard = srgb(0xD9B37C);
  static final flowerColors = [
    srgb(0xFFFFFF),
    srgb(0xFFD84D),
    srgb(0xFF7FB0),
    srgb(0xB88CFF),
  ];
}

/// Número pseudoaleatorio estable por casilla (0..1): el mismo mapa
/// siempre genera los mismos árboles, sin guardar nada.
double cellNoise(int col, int row, [int salt = 0]) {
  var h = col * 374761393 + row * 668265263 + salt * 2246822519;
  h = (h ^ (h >> 13)) * 1274126177;
  h = h ^ (h >> 16);
  return (h & 0xFFFF) / 0xFFFF;
}

/// Casa del mapa: rectángulo de casillas `H` contiguas.
typedef HouseBlock = ({int col, int row, int width, int height});

/// Busca los bloques de casas (cada `H` pertenece a un solo bloque).
/// Un bloque empieza en una `H` sin `H` a su izquierda ni encima.
List<HouseBlock> findHouseBlocks(MapLayout layout) {
  bool isHouse(int c, int r) => layout.tileAt(c, r) == TileKind.house;
  final blocks = <HouseBlock>[];
  for (var row = 0; row < layout.rows; row++) {
    for (var col = 0; col < layout.columns; col++) {
      if (!isHouse(col, row) ||
          isHouse(col - 1, row) ||
          isHouse(col, row - 1)) {
        continue;
      }
      var width = 1;
      while (isHouse(col + width, row)) {
        width++;
      }
      var height = 1;
      while (isHouse(col, row + height)) {
        height++;
      }
      blocks.add((col: col, row: row, width: width, height: height));
    }
  }
  return blocks;
}

/// Construye TODOS los objetos fijos del mapa (árboles, casas, vallas...)
/// en una sola malla: una única llamada de dibujo para el mundo entero.
MeshBuffers buildProps(MapLayout layout, double tile) {
  final b = MeshBuilder();
  for (var row = 0; row < layout.rows; row++) {
    for (var col = 0; col < layout.columns; col++) {
      final center = Vector3((col + 0.5) * tile, 0, (row + 0.5) * tile);
      final n = cellNoise(col, row);
      b.withTransform(
        Matrix4.translation(center)
          ..scaleByDouble(tile / 2, tile / 2, tile / 2, 1),
        () => switch (layout.tileAt(col, row)!) {
          TileKind.tree => addTree(b, n),
          TileKind.pine => addPine(b, n),
          TileKind.autumnTree => addTree(b, n, autumn: true),
          TileKind.bush => addBush(b, n),
          TileKind.fence => _addFence(b, layout, col, row),
          TileKind.sign => addSign(b),
          TileKind.mushroom => addMushrooms(b, col, row),
          TileKind.flowers => addFlowers(b, col, row),
          TileKind.stone => addSteppingStone(b, n),
          _ => null,
        },
      );
    }
  }
  final roofs = [Palette.roofRed, Palette.roofBlue, Palette.roofGreen];
  final houses = findHouseBlocks(layout);
  for (var i = 0; i < houses.length; i++) {
    addHouse(b, houses[i], tile, roofs[i % roofs.length]);
  }
  _addOuterForest(b, layout, tile);
  return b.build();
}

// Las piezas siguientes se construyen en una casilla "unidad": de -1 a 1
// en X y Z (el llamador escala al tamaño real de la casilla).

/// Árbol redondo: tronco + dos o tres "bolas" facetadas de hojas.
void addTree(MeshBuilder b, double n, {bool autumn = false}) {
  final h = 1.0 + n * 0.35; // altura variable
  final dark = autumn ? Palette.autumn : Palette.leaf;
  final light = autumn ? Palette.autumnLight : Palette.leafLight;
  b
    ..prism(
      base: Vector3.zero(),
      bottomRadius: 0.2,
      topRadius: 0.14,
      height: 1.2 * h,
      sides: 6,
      color: Palette.trunk,
    )
    ..gem(Vector3(0, 1.55 * h, 0), Vector3(0.95, 0.8, 0.95), dark)
    ..gem(Vector3(0.25, 2.15 * h, 0.1), Vector3(0.62, 0.55, 0.62), light)
    ..gem(Vector3(-0.3, 1.9 * h, -0.25), Vector3(0.5, 0.45, 0.5), light);
}

/// Pino: tronco + tres conos apilados.
void addPine(MeshBuilder b, double n) {
  final h = 1.0 + n * 0.4;
  b.prism(
    base: Vector3.zero(),
    bottomRadius: 0.17,
    topRadius: 0.12,
    height: 0.7 * h,
    sides: 6,
    color: Palette.trunkDark,
  );
  for (var i = 0; i < 3; i++) {
    b.prism(
      base: Vector3(0, (0.5 + i * 0.75) * h, 0),
      bottomRadius: 0.95 - i * 0.25,
      topRadius: 0,
      height: 1.3 * h,
      sides: 7,
      color: i.isEven ? Palette.pine : Palette.pineDark,
      twist: i * 0.4 + n,
    );
  }
}

/// Arbusto: racimo de bolas verdes con alguna baya.
void addBush(MeshBuilder b, double n) {
  b
    ..gem(Vector3(0, 0.45, 0), Vector3(0.75, 0.55, 0.75), Palette.bush)
    ..gem(Vector3(0.4, 0.4, 0.2), Vector3(0.45, 0.4, 0.45), Palette.leaf)
    ..gem(Vector3(-0.35, 0.35, -0.2), Vector3(0.45, 0.38, 0.45), Palette.leaf);
  if (n > 0.4) {
    for (var i = 0; i < 3; i++) {
      final a = i * 2.1 + n * 6;
      b.gem(
        Vector3(math.sin(a) * 0.6, 0.55 + i * 0.1, math.cos(a) * 0.6),
        Vector3.all(0.09),
        Palette.berry,
        detail: 0,
      );
    }
  }
}

/// Valla: postes y dos travesaños; se une con las vallas vecinas.
void _addFence(MeshBuilder b, MapLayout layout, int col, int row) {
  bool fenceAt(int c, int r) => layout.tileAt(c, r) == TileKind.fence;
  addFence(
    b,
    left: fenceAt(col - 1, row),
    right: fenceAt(col + 1, row),
    up: fenceAt(col, row - 1),
    down: fenceAt(col, row + 1),
  );
}

void addFence(
  MeshBuilder b, {
  bool left = false,
  bool right = false,
  bool up = false,
  bool down = false,
}) {
  b.box(
    Vector3(-0.1, 0, -0.1),
    Vector3(0.1, 0.9, 0.1),
    Palette.woodDark,
    topColor: Palette.wood,
  );
  final horizontal = left || right || !(up || down);
  final x0 = left || !right ? -1.0 : 0.0;
  final x1 = right || !left ? 1.0 : 0.0;
  final z0 = up || !down ? -1.0 : 0.0;
  final z1 = down || !up ? 1.0 : 0.0;
  for (final y in [0.35, 0.7]) {
    if (horizontal) {
      b.box(
        Vector3(x0, y - 0.06, -0.05),
        Vector3(x1, y + 0.06, 0.05),
        Palette.wood,
      );
    }
    if (up || down) {
      b.box(
        Vector3(-0.05, y - 0.06, z0),
        Vector3(0.05, y + 0.06, z1),
        Palette.wood,
      );
    }
  }
}

/// Cartel de madera.
void addSign(MeshBuilder b) {
  b
    ..box(Vector3(-0.07, 0, -0.07), Vector3(0.07, 0.8, 0.07), Palette.woodDark)
    ..box(
      Vector3(-0.6, 0.7, -0.06),
      Vector3(0.6, 1.3, 0.06),
      Palette.signBoard,
      topColor: Palette.wood,
    );
}

/// Setas rojas con motas (pisables: solo decoran).
void addMushrooms(MeshBuilder b, int col, int row) {
  for (var i = 0; i < 3; i++) {
    final x = (cellNoise(col, row, i) - 0.5) * 1.3;
    final z = (cellNoise(col, row, i + 7) - 0.5) * 1.3;
    final s = 0.6 + cellNoise(col, row, i + 3) * 0.5;
    b
      ..prism(
        base: Vector3(x, 0, z),
        bottomRadius: 0.07 * s,
        topRadius: 0.06 * s,
        height: 0.25 * s,
        sides: 5,
        color: Palette.mushroomStem,
      )
      ..gem(
        Vector3(x, 0.27 * s, z),
        Vector3(0.2, 0.12, 0.2) * s,
        Palette.mushroomCap,
        detail: 0,
      );
  }
}

/// Flores sueltas sobre el césped.
void addFlowers(MeshBuilder b, int col, int row) {
  for (var i = 0; i < 6; i++) {
    final x = (cellNoise(col, row, i) - 0.5) * 1.6;
    final z = (cellNoise(col, row, i + 11) - 0.5) * 1.6;
    final color =
        Palette.flowerColors[(cellNoise(col, row, i + 5) *
                    Palette.flowerColors.length)
                .floor() %
            Palette.flowerColors.length];
    b
      ..prism(
        base: Vector3(x, 0, z),
        bottomRadius: 0.015,
        topRadius: 0.015,
        height: 0.18,
        sides: 3,
        color: Palette.leaf,
        bottomCap: false,
      )
      ..gem(Vector3(x, 0.2, z), Vector3(0.08, 0.04, 0.08), color, detail: 0);
  }
}

/// Losa de piedra ligeramente elevada.
void addSteppingStone(MeshBuilder b, double n) {
  b.prism(
    base: Vector3.zero(),
    bottomRadius: 0.8,
    topRadius: 0.75,
    height: 0.05,
    sides: 7,
    color: Palette.stone,
    twist: n * 3,
  );
}

/// Casa estilo Pokémon: paredes claras, tejado a dos aguas de color,
/// puerta y ventanas en la fachada que da al sur (+Z) y una chimenea.
void addHouse(MeshBuilder b, HouseBlock house, double tile, Vector4 roof) {
  final x0 = house.col * tile + 0.15;
  final x1 = (house.col + house.width) * tile - 0.15;
  final z0 = house.row * tile + 0.15;
  final z1 = (house.row + house.height) * tile - 0.15;
  const wallH = 3.0;
  final roofH = (z1 - z0) * 0.38;
  final midZ = (z0 + z1) / 2;
  final midX = (x0 + x1) / 2;

  // Zócalo y paredes.
  b
    ..box(
      Vector3(x0 - 0.1, 0, z0 - 0.1),
      Vector3(x1 + 0.1, 0.35, z1 + 0.1),
      Palette.chimney,
    )
    ..box(
      Vector3(x0, 0.35, z0),
      Vector3(x1, wallH, z1),
      Palette.wall,
      topColor: Palette.wallShade,
    );

  // Tejado a dos aguas (vertiente norte y sur) con un poco de alero.
  const eave = 0.45;
  final ra = Vector3(x0 - eave, wallH, z0 - eave);
  final rb = Vector3(x1 + eave, wallH, z0 - eave);
  final rc = Vector3(x1 + eave, wallH, z1 + eave);
  final rd = Vector3(x0 - eave, wallH, z1 + eave);
  final ridgeL = Vector3(x0 - eave, wallH + roofH, midZ);
  final ridgeR = Vector3(x1 + eave, wallH + roofH, midZ);
  final roofDark = roof.clone()..scale(0.7);
  roofDark.w = 1;
  b
    ..quad(rd, rc, ridgeR, ridgeL, roof) // sur
    ..quad(rb, ra, ridgeL, ridgeR, roofDark) // norte
    ..triangle(ra, rd, ridgeL, roofDark) // hastial oeste
    ..triangle(rc, rb, ridgeR, roofDark)
    // Bajo del alero (para que no se vea hueco desde abajo).
    ..quad(ra, rb, rc, rd, Palette.wallShade);
  // Hastiales de pared (triángulos bajo el tejado).
  b
    ..triangle(
      Vector3(x0, wallH, z0),
      Vector3(x0, wallH, z1),
      Vector3(x0, wallH + roofH * 0.9, midZ),
      Palette.wallShade,
    )
    ..triangle(
      Vector3(x1, wallH, z1),
      Vector3(x1, wallH, z0),
      Vector3(x1, wallH + roofH * 0.9, midZ),
      Palette.wallShade,
    );

  // Puerta con escalón, en el centro de la fachada sur.
  b
    ..box(
      Vector3(midX - 0.55, 0.35, z1),
      Vector3(midX + 0.55, 2.2, z1 + 0.08),
      Palette.door,
    )
    ..box(
      Vector3(midX - 0.8, 0, z1),
      Vector3(midX + 0.8, 0.2, z1 + 0.6),
      Palette.chimney,
    );

  // Ventanas a los lados de la puerta (y en las fachadas laterales).
  for (final wx in [x0 + (midX - x0) * 0.45, x1 - (x1 - midX) * 0.45]) {
    b
      ..box(
        Vector3(wx - 0.55, 1.3, z1),
        Vector3(wx + 0.55, 2.25, z1 + 0.06),
        Palette.woodDark,
      )
      ..box(
        Vector3(wx - 0.45, 1.4, z1 + 0.02),
        Vector3(wx + 0.45, 2.15, z1 + 0.08),
        Palette.window,
      );
  }

  // Chimenea.
  final cx = x1 - (x1 - x0) * 0.22;
  b.box(
    Vector3(cx - 0.35, wallH, midZ - 1.2),
    Vector3(cx + 0.35, wallH + roofH + 0.8, midZ - 0.5),
    Palette.chimney,
    topColor: Palette.trunkDark,
  );
}

/// Bosque denso alrededor del mapa para que no se vea el vacío del borde.
void _addOuterForest(MeshBuilder b, MapLayout layout, double tile) {
  const ring = 4;
  for (var row = -ring; row < layout.rows + ring; row++) {
    for (var col = -ring; col < layout.columns + ring; col++) {
      if (layout.contains(col, row)) continue;
      final n = cellNoise(col, row, 99);
      final center = Vector3(
        (col + 0.5 + (n - 0.5) * 0.4) * tile,
        0,
        (row + 0.5 + (cellNoise(col, row, 98) - 0.5) * 0.4) * tile,
      );
      b.withTransform(
        Matrix4.translation(center)..scaleByDouble(
          tile / 2 * (1 + n * 0.3),
          tile / 2 * (1 + n * 0.3),
          tile / 2 * (1 + n * 0.3),
          1,
        ),
        () => n > 0.45 ? addPine(b, n) : addTree(b, n),
      );
    }
  }
}
