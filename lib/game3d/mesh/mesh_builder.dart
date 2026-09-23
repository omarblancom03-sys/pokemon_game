import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

/// Malla terminada, como listas planas de números (lo que pide la GPU).
/// Es Dart puro: el renderer la convierte a geometría del motor, y los
/// tests pueden inspeccionarla sin GPU.
class MeshBuffers {
  const MeshBuffers({
    required this.positions,
    required this.normals,
    required this.colors,
    required this.indices,
  });

  /// x, y, z por vértice.
  final Float32List positions;

  /// Normal (hacia dónde "mira" la cara) por vértice.
  final Float32List normals;

  /// r, g, b, a por vértice (color LINEAL, no sRGB).
  final Float32List colors;

  /// Tres índices por triángulo.
  final List<int> indices;

  /// Copia en el espacio del MOTOR. La simulación usa ejes de mano
  /// derecha (lo habitual en matemáticas); flutter_scene usa mano
  /// izquierda. Pasar de uno a otro = invertir Z (posiciones y normales)
  /// y dar la vuelta a cada triángulo para que siga mirando hacia fuera.
  MeshBuffers toEngineSpace() {
    final p = Float32List.fromList(positions);
    final n = Float32List.fromList(normals);
    for (var i = 2; i < p.length; i += 3) {
      p[i] = -p[i];
      n[i] = -n[i];
    }
    final idx = <int>[
      for (var i = 0; i < indices.length; i += 3) ...[
        indices[i],
        indices[i + 2],
        indices[i + 1],
      ],
    ];
    return MeshBuffers(positions: p, normals: n, colors: colors, indices: idx);
  }

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;
  bool get isEmpty => indices.isEmpty;
}

/// Constructor de mallas LOW-POLY con sombreado plano: cada cara tiene sus
/// propios vértices y su normal, por eso se ven las facetas (el estilo
/// buscado). Los triángulos se dan en sentido ANTIHORARIO vistos desde
/// fuera (así los espera el motor como "cara delantera").
///
/// Admite una pila de transformaciones: [push]/[pop] para construir un
/// objeto por piezas (tronco, copa...) en coordenadas locales.
class MeshBuilder {
  final List<double> _positions = [];
  final List<double> _normals = [];
  final List<double> _colors = [];
  final List<int> _indices = [];
  final List<Matrix4> _stack = [Matrix4.identity()];

  Matrix4 get _current => _stack.last;

  /// Aplica [transform] a todo lo que se añada hasta el [pop] siguiente.
  void push(Matrix4 transform) => _stack.add(_current.multiplied(transform));

  void pop() {
    if (_stack.length == 1) throw StateError('pop() sin push()');
    _stack.removeLast();
  }

  /// Dibuja [build] con [transform] aplicado (push + pop automáticos).
  void withTransform(Matrix4 transform, void Function() build) {
    push(transform);
    build();
    pop();
  }

  /// Un triángulo de color sólido. Antihorario visto desde fuera.
  void triangle(Vector3 a, Vector3 b, Vector3 c, Vector4 color) =>
      shadedTriangle(a, b, c, color, color, color);

  /// Un triángulo con un color por vértice (la GPU los mezcla por dentro):
  /// sirve para degradados, como un haz de luz que se desvanece arriba.
  void shadedTriangle(
    Vector3 a,
    Vector3 b,
    Vector3 c,
    Vector4 colorA,
    Vector4 colorB,
    Vector4 colorC,
  ) {
    final pa = _current.transformed3(a);
    final pb = _current.transformed3(b);
    final pc = _current.transformed3(c);
    final normal = (pb - pa).cross(pc - pa);
    if (normal.length2 == 0) return; // triángulo degenerado: se ignora
    normal.normalize();
    final base = _positions.length ~/ 3;
    for (final (p, color) in [(pa, colorA), (pb, colorB), (pc, colorC)]) {
      _positions.addAll([p.x, p.y, p.z]);
      _normals.addAll([normal.x, normal.y, normal.z]);
      _colors.addAll([color.x, color.y, color.z, color.w]);
    }
    _indices.addAll([base, base + 1, base + 2]);
  }

  /// Cuadrilátero a-b-c-d (antihorario visto desde fuera).
  void quad(Vector3 a, Vector3 b, Vector3 c, Vector3 d, Vector4 color) {
    triangle(a, b, c, color);
    triangle(a, c, d, color);
  }

  /// Caja alineada a los ejes, entre [min] y [max].
  void box(Vector3 min, Vector3 max, Vector4 color, {Vector4? topColor}) {
    final x0 = min.x, y0 = min.y, z0 = min.z;
    final x1 = max.x, y1 = max.y, z1 = max.z;
    Vector3 v(double x, double y, double z) => Vector3(x, y, z);
    // Arriba (+Y) y abajo (-Y).
    quad(
      v(x0, y1, z0),
      v(x0, y1, z1),
      v(x1, y1, z1),
      v(x1, y1, z0),
      topColor ?? color,
    );
    quad(v(x0, y0, z0), v(x1, y0, z0), v(x1, y0, z1), v(x0, y0, z1), color);
    // Delante (+Z) y detrás (-Z).
    quad(v(x0, y0, z1), v(x1, y0, z1), v(x1, y1, z1), v(x0, y1, z1), color);
    quad(v(x1, y0, z0), v(x0, y0, z0), v(x0, y1, z0), v(x1, y1, z0), color);
    // Derecha (+X) e izquierda (-X).
    quad(v(x1, y0, z1), v(x1, y0, z0), v(x1, y1, z0), v(x1, y1, z1), color);
    quad(v(x0, y0, z0), v(x0, y0, z1), v(x0, y1, z1), v(x0, y1, z0), color);
  }

  /// Cilindro o cono de [sides] lados, de pie sobre [base] (y crece hacia
  /// arriba). Con [topRadius] = 0 es un cono.
  void prism({
    required Vector3 base,
    required double bottomRadius,
    required double topRadius,
    required double height,
    required int sides,
    required Vector4 color,
    Vector4? topColor,
    bool bottomCap = true,
    double twist = 0,
  }) {
    Vector3 ring(double radius, double y, int i) {
      final a = twist + i * 2 * math.pi / sides;
      return base + Vector3(math.sin(a) * radius, y, math.cos(a) * radius);
    }

    final top = base + Vector3(0, height, 0);
    for (var i = 0; i < sides; i++) {
      final b0 = ring(bottomRadius, 0, i);
      final b1 = ring(bottomRadius, 0, i + 1);
      final t0 = ring(topRadius, height, i);
      final t1 = ring(topRadius, height, i + 1);
      if (topRadius == 0) {
        triangle(b0, b1, top, color);
      } else {
        quad(b0, b1, t1, t0, color);
        triangle(top, t0, t1, topColor ?? color);
      }
      if (bottomCap && bottomRadius > 0) triangle(base, b1, b0, color);
    }
  }

  /// Esfera facetada (icosaedro subdividido [detail] veces). Con
  /// [colorAt] cada cara toma el color que toque según su dirección desde
  /// el centro (así se pinta una Poké Ball: arriba roja, abajo blanca...).
  void gem(
    Vector3 center,
    Vector3 radii,
    Vector4 color, {
    int detail = 1,
    Vector4 Function(Vector3 direction)? colorAt,
  }) {
    const t = 1.618033988749895;
    final verts = [
      Vector3(-1, t, 0),
      Vector3(1, t, 0),
      Vector3(-1, -t, 0),
      Vector3(1, -t, 0),
      Vector3(0, -1, t),
      Vector3(0, 1, t),
      Vector3(0, -1, -t),
      Vector3(0, 1, -t),
      Vector3(t, 0, -1),
      Vector3(t, 0, 1),
      Vector3(-t, 0, -1),
      Vector3(-t, 0, 1),
    ].map((v) => v.normalized()).toList();
    var faces = const [
      [0, 11, 5],
      [0, 5, 1],
      [0, 1, 7],
      [0, 7, 10],
      [0, 10, 11],
      [1, 5, 9],
      [5, 11, 4],
      [11, 10, 2],
      [10, 7, 6],
      [7, 1, 8],
      [3, 9, 4],
      [3, 4, 2],
      [3, 2, 6],
      [3, 6, 8],
      [3, 8, 9],
      [4, 9, 5],
      [2, 4, 11],
      [6, 2, 10],
      [8, 6, 7],
      [9, 8, 1],
    ].map((f) => [verts[f[0]], verts[f[1]], verts[f[2]]]).toList();

    for (var d = 0; d < detail; d++) {
      faces = [
        for (final f in faces)
          ...() {
            final ab = (f[0] + f[1]).normalized();
            final bc = (f[1] + f[2]).normalized();
            final ca = (f[2] + f[0]).normalized();
            return [
              [f[0], ab, ca],
              [f[1], bc, ab],
              [f[2], ca, bc],
              [ab, bc, ca],
            ];
          }(),
      ];
    }
    Vector3 place(Vector3 unit) =>
        center + Vector3(unit.x * radii.x, unit.y * radii.y, unit.z * radii.z);
    for (final f in faces) {
      final faceColor = colorAt == null
          ? color
          : colorAt((f[0] + f[1] + f[2])..normalize());
      triangle(place(f[0]), place(f[1]), place(f[2]), faceColor);
    }
  }

  /// Añade otra malla ya construida (con la transformación actual).
  void addBuffers(MeshBuffers other) {
    for (var i = 0; i < other.indices.length; i += 3) {
      Vector3 at(int idx) => Vector3(
        other.positions[idx * 3],
        other.positions[idx * 3 + 1],
        other.positions[idx * 3 + 2],
      );
      final c = other.indices[i] * 4;
      triangle(
        at(other.indices[i]),
        at(other.indices[i + 1]),
        at(other.indices[i + 2]),
        Vector4(
          other.colors[c],
          other.colors[c + 1],
          other.colors[c + 2],
          other.colors[c + 3],
        ),
      );
    }
  }

  bool get isEmpty => _indices.isEmpty;

  MeshBuffers build() => MeshBuffers(
    positions: Float32List.fromList(_positions),
    normals: Float32List.fromList(_normals),
    colors: Float32List.fromList(_colors),
    indices: List.unmodifiable(_indices),
  );
}

/// Color sRGB (el de los editores, 0..255) → color LINEAL para el motor.
Vector4 srgb(int hex, [double alpha = 1]) {
  double lin(int c) {
    final s = c / 255;
    return s <= 0.04045
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return Vector4(
    lin((hex >> 16) & 0xFF),
    lin((hex >> 8) & 0xFF),
    lin(hex & 0xFF),
    alpha,
  );
}
