import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../../game/map/map_layout.dart';
import 'cell_noise.dart';

/// Tipos de árbol (cada uno con su copa).
enum TreeKind {
  /// Árbol redondo de hojas verdes.
  round,

  /// Árbol otoñal: como el redondo, con la copa naranja.
  autumn,

  /// Pino: tres conos; más rígido, apenas se mece.
  pine;

  bool get isPine => this == pine;
}

/// Inclinación de la copa: hacia dónde (en el suelo) se va su punta, ya
/// multiplicada por el ángulo (rad).
typedef TreeLean = ({double x, double z});

/// Un árbol del mundo (los del mapa y los del bosque que lo rodea).
///
/// El modelo se construye en una casilla "unidad" (ver props.dart): [size]
/// son los metros por unidad y [height] lo estira en vertical.
class Tree {
  Tree({
    required this.kind,
    required this.col,
    required this.row,
    required this.x,
    required this.z,
    required this.size,
    required this.height,
    required this.yaw,
    required this.phase,
  });

  final TreeKind kind;

  /// Casilla del árbol (fuera del mapa en el bosque del borde).
  final int col;
  final int row;

  /// Centro del tronco (m).
  final double x;
  final double z;

  /// Metros por unidad del modelo (media casilla; algo más en el borde).
  final double size;

  /// Alto relativo (1 … 1,4): así no miden todos lo mismo.
  final double height;

  /// Giro propio (rad): así no todos miran igual.
  final double yaw;

  /// Desfase del vaivén (así no se mecen todos a la vez).
  final double phase;

  /// Altura del pivote del vaivén en la casilla unidad (antes de [height]):
  /// lo alto del tronco del árbol redondo; la base de las ramas del pino.
  static double pivotUnit(TreeKind kind) => kind.isPine ? 0.5 : 1.2;

  /// Altura (m) del punto sobre el que se mece la copa (el tronco no se
  /// mueve).
  double get pivotHeight => pivotUnit(kind) * height * size;

  /// Centro aproximado de la copa (de ahí caen las hojas) y su radio (m).
  Vector3 get crown =>
      Vector3(x, (kind.isPine ? 1.6 : 1.85) * height * size, z);
  double get crownRadius => (kind.isPine ? 0.6 : 0.85) * size;

  // Sacudida por un golpe (ver TreeField.knock).
  double _knock = 0;
  double _knockAge = double.infinity;
  double _knockX = 1;
  double _knockZ = 0;

  /// ¿Se está sacudiendo aún por un golpe?
  bool get isShaking => _knockAge < TreeField.knockSeconds;

  /// Inclinación (rad) que le queda por el golpe, hacia donde lo empujó.
  TreeLean get knockLean {
    if (!isShaking) return (x: 0, z: 0);
    final t = _knockAge;
    // Oscilación amortiguada: sale hacia donde lo empujaron y va y viene.
    final a =
        _knock *
        math.exp(-t / TreeField.knockDecay) *
        math.sin(2 * math.pi * TreeField.knockFrequency * t);
    return (x: _knockX * a, z: _knockZ * a);
  }
}

/// LOS ÁRBOLES como datos (Dart puro): dónde está cada uno, cuánto se mece
/// con el viento (a RÁFAGAS que cruzan el campo: se ve la ola de viento
/// pasar por el bosque) y cómo se sacuden si les da una Poké Ball. El
/// tronco no se mueve: solo la copa, sobre su pivote. El renderer solo
/// copia estas inclinaciones a la GPU.
class TreeField {
  TreeField(List<Tree> trees, {required this.tileSize})
    : trees = List.unmodifiable(trees),
      _byCell = {for (final t in trees) (t.col, t.row): t};

  /// Los árboles de las casillas `T`, `P` y `A` del mapa y un bosque de
  /// [outerRing] casillas de ancho alrededor (para que no se vea el borde
  /// del mundo). Siempre igual para el mismo mapa (ruido por casilla).
  factory TreeField.fromLayout(
    MapLayout layout,
    double tileSize, {
    int outerRing = 4,
  }) {
    final trees = <Tree>[];
    for (var row = -outerRing; row < layout.rows + outerRing; row++) {
      for (var col = -outerRing; col < layout.columns + outerRing; col++) {
        final tree = layout.contains(col, row)
            ? _mapTree(layout, col, row, tileSize)
            : _forestTree(col, row, tileSize);
        if (tree != null) trees.add(tree);
      }
    }
    return TreeField(trees, tileSize: tileSize);
  }

  /// Un árbol del mapa (centrado en su casilla), o null si no hay.
  static Tree? _mapTree(MapLayout layout, int col, int row, double tile) {
    final kind = switch (layout.tileAt(col, row)) {
      TileKind.tree => TreeKind.round,
      TileKind.autumnTree => TreeKind.autumn,
      TileKind.pine => TreeKind.pine,
      _ => null,
    };
    if (kind == null) return null;
    final n = cellNoise(col, row);
    return Tree(
      kind: kind,
      col: col,
      row: row,
      x: (col + 0.5) * tile,
      z: (row + 0.5) * tile,
      size: tile / 2,
      height: _heightFor(kind, n),
      yaw: _yawFor(kind, col, row, n),
      phase: cellNoise(col, row, 95) * 2 * math.pi,
    );
  }

  /// Un árbol del bosque del borde: algo desplazado dentro de su casilla
  /// y más grande; pinos y árboles redondos (algunos otoñales).
  static Tree _forestTree(int col, int row, double tile) {
    final n = cellNoise(col, row, 99);
    final kind = n > 0.45
        ? TreeKind.pine
        : cellNoise(col, row, 97) < autumnForestShare
        ? TreeKind.autumn
        : TreeKind.round;
    return Tree(
      kind: kind,
      col: col,
      row: row,
      x: (col + 0.5 + (n - 0.5) * 0.4) * tile,
      z: (row + 0.5 + (cellNoise(col, row, 98) - 0.5) * 0.4) * tile,
      size: tile / 2 * (1 + n * 0.3),
      height: _heightFor(kind, n),
      yaw: _yawFor(kind, col, row, n),
      phase: cellNoise(col, row, 95) * 2 * math.pi,
    );
  }

  static double _heightFor(TreeKind kind, double n) =>
      kind.isPine ? 1 + n * 0.4 : 1 + n * 0.35;

  /// El pino gira lo que antes giraban sus conos (`n` rad); el redondo,
  /// cualquier cosa (su copa no es simétrica: así no se repite).
  static double _yawFor(TreeKind kind, int col, int row, double n) =>
      kind.isPine ? n : cellNoise(col, row, 96) * 2 * math.pi;

  /// Parte de los árboles redondos del bosque del borde que son otoñales
  /// (dan color al borde; también sueltan hojas).
  static const autumnForestShare = 0.2;

  final List<Tree> trees;
  final double tileSize;
  final Map<(int, int), Tree> _byCell;
  final List<Tree> _shaking = [];

  /// El árbol de la casilla que contiene [p] (null si no hay).
  Tree? treeAt(Vector3 p) =>
      _byCell[((p.x / tileSize).floor(), (p.z / tileSize).floor())];

  /// Hacia dónde sopla el viento (en el suelo; el de la hierba y las
  /// nubes también va hacia +X).
  static final windDirection = Vector3(1, 0, 0.25)..normalize();

  /// Las RÁFAGAS son olas que avanzan con el viento: una de [gustLength] m
  /// a [gustSpeed] m/s (una cada ~6 s en cada sitio) y otra más larga y
  /// lenta que hace que no todas sean iguales.
  static const gustSpeed = 7.0;
  static const gustLength = 45.0;

  /// Inclinación (rad) a favor del viento: siempre un poco y más en cada
  /// ráfaga; y el vaivén alrededor de ella.
  static const baseLean = 0.012;
  static const gustLean = 0.03;
  static const baseSway = 0.01;
  static const gustSway = 0.025;

  /// El pino es más rígido: se mece a esta parte.
  static const pineStiffness = 0.55;

  /// Vaivén de un árbol de tamaño normal (Hz); los grandes, más despacio.
  static const swayFrequency = 0.5;

  /// Golpe: inclinación por cada m/s de la bola (rad), con un tope; se
  /// mece a [knockFrequency] Hz y se apaga en [knockDecay] s (del todo a
  /// los [knockSeconds] s). Por debajo de [minKnockSpeed] m/s no se nota.
  static const knockPerSpeed = 0.012;
  static const maxKnock = 0.16;
  static const knockFrequency = 2.4;
  static const knockDecay = 0.45;
  static const knockSeconds = 2.0;
  static const minKnockSpeed = 2.0;

  /// Fuerza de la ráfaga (0 = calma … 1 = ráfaga fuerte) en (x, z).
  static double gustAt(double time, double x, double z) {
    final along = x * windDirection.x + z * windDirection.z;
    const k = 2 * math.pi / gustLength;
    final a = math.sin((gustSpeed * time - along) * k);
    final b = math.sin((gustSpeed * 0.7 * time - along) * k / 1.7 + 1.3);
    final u = (0.6 * a + 0.4 * b + 1) / 2;
    return u * u; // más rato en calma; las ráfagas, más cortas
  }

  /// Inclinación de la copa de [tree] en [time]: a favor del viento (más
  /// en las ráfagas), con su vaivén, algo de lado y la sacudida de un
  /// golpe si la hay.
  static TreeLean leanOf(Tree tree, double time) {
    final g = gustAt(time, tree.x, tree.z);
    final stiff = tree.kind.isPine ? pineStiffness : 1.0;
    final w = 2 * math.pi * swayFrequency / math.sqrt(tree.height * tree.size);
    final sway = baseSway + gustSway * g;
    final along =
        (baseLean + gustLean * g + sway * math.sin(w * time + tree.phase)) *
        stiff;
    // Un poco de lado, a otro ritmo: la copa dibuja un ocho, no una raya.
    final across =
        sway * 0.4 * stiff * math.sin(w * 1.31 * time + tree.phase * 2.3);
    final knock = tree.knockLean;
    return (
      x: windDirection.x * along - windDirection.z * across + knock.x,
      z: windDirection.z * along + windDirection.x * across + knock.z,
    );
  }

  /// Transformación de la copa (espacio de la simulación): la copa se
  /// construye con el pivote en el origen (ver `addCanopy`). Se estira con
  /// [Tree.height], gira con [Tree.yaw] y se inclina con [lean] sobre el
  /// pivote. Si se da [into], se escribe ahí (sin crear matrices).
  static Matrix4 canopyTransform(Tree tree, TreeLean lean, [Matrix4? into]) {
    final m = (into ?? Matrix4.zero())
      ..setIdentity()
      ..setTranslationRaw(tree.x, tree.pivotHeight, tree.z);
    final angle = math.sqrt(lean.x * lean.x + lean.z * lean.z);
    if (angle > 1e-9) {
      // Eje = arriba × dirección: así la punta va hacia donde se inclina.
      m.rotate(Vector3(lean.z / angle, 0, -lean.x / angle), angle);
    }
    return m
      ..rotateY(tree.yaw)
      ..scaleByDouble(tree.size, tree.size * tree.height, tree.size, 1);
  }

  /// Una Poké Ball choca en [at] con velocidad [velocity]: si hay un
  /// árbol y va lo bastante rápida, la copa se sacude hacia donde iba la
  /// bola (más cuanto más rápida; el pino, menos). Devuelve el árbol y la
  /// fuerza del golpe (rad); null si no hay árbol o el golpe es flojo.
  ({Tree tree, double strength})? knock(Vector3 at, Vector3 velocity) {
    final tree = treeAt(at);
    if (tree == null) return null;
    final speed = math.sqrt(velocity.x * velocity.x + velocity.z * velocity.z);
    if (speed < minKnockSpeed) return null;
    final stiff = tree.kind.isPine ? pineStiffness : 1.0;
    final strength = math.min(maxKnock, speed * knockPerSpeed) * stiff;
    // Si aún se mueve por otro golpe, gana el más fuerte de los dos.
    final left = tree.isShaking
        ? tree._knock * math.exp(-tree._knockAge / knockDecay)
        : 0.0;
    if (strength < left) return (tree: tree, strength: strength);
    tree
      .._knock = strength
      .._knockAge = 0
      .._knockX = velocity.x / speed
      .._knockZ = velocity.z / speed;
    if (!_shaking.contains(tree)) _shaking.add(tree);
    return (tree: tree, strength: strength);
  }

  /// Árboles que aún se sacuden por un golpe.
  List<Tree> get shaking => List.unmodifiable(_shaking);

  /// Avanza las sacudidas [dt] segundos (el viento solo depende del tiempo).
  void update(double dt) {
    for (final t in _shaking) {
      t._knockAge += dt;
    }
    _shaking.removeWhere((t) => !t.isShaking);
  }
}
