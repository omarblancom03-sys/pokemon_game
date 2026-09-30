import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../../models/poke_ball.dart';
import 'mesh_builder.dart';

// Poké Ball rediseñada (ficha "PokeBall Spec", rev. 2, hecha con Claude
// Design). Todas las medidas van en proporción al radio R = 1; al construir
// se escala al radio pedido. Ejes de la simulación: +Y arriba, +Z frente
// (botón), la bisagra detrás (−Z).

/// Colores de las Poké Balls (sRGB de la ficha → lineal con [srgb]).
abstract final class BallPalette {
  static final red = srgb(0xE3392F);
  static final white = srgb(0xF2EEE6);
  static final blue = srgb(0x2F6BD8);
  static final black = srgb(0x2A2B31);
  static final yellow = srgb(0xF4C21B);

  /// Franja del ecuador y su labio.
  static final band = srgb(0x202027);

  /// Aro negro del botón (y el aro de luz cuando está apagado).
  static final ring = srgb(0x202027);
  static final button = srgb(0xF7F5EF);

  /// Interior hueco (solo se ve con la bola abierta) y su canto de corte.
  static final inside = srgb(0x3A3D46);
  static final rim = srgb(0x2B2C33);

  /// Botón encendido: en cada sacudida (rojo) y en la captura (blanco).
  /// Se multiplican por su intensidad (más de 1.2 → entra el "bloom").
  static final shakeCore = srgb(0xFF3B30);
  static final shakeHalo = srgb(0xFF7A5C);
  static final catchCore = srgb(0xFFFFFF);
  static final catchHalo = srgb(0xCFE9FF);

  /// Captura crítica: dorado (no está en la ficha; sigue el estilo del
  /// juego, donde lo crítico brilla en oro).
  static final criticalCore = srgb(0xFFC83A);
  static final criticalHalo = srgb(0xFFE08A);

  static const coreIntensity = 1.6;
  static const haloIntensity = 2.4;
  static const catchCoreIntensity = 1.8;
  static const catchHaloIntensity = 2.6;
}

/// Las piezas de la bola según su MATERIAL: cada una se dibuja con su
/// propio brillo (el plástico de la carcasa brilla; la franja es mate).
enum BallSurface {
  /// Carcasa y marcas (alas, "H"): plástico brillante.
  shell,

  /// Franja, labio, interior y canto de corte: mate.
  matte,

  /// Aro negro del botón: satinado.
  ring,

  /// Aro de luz alrededor del botón (se enciende).
  halo,

  /// Disco del botón: lo más brillante (se enciende).
  button;

  /// Rugosidad del material (0 = espejo, 1 = mate), según la ficha.
  double roughnessFor(PokeBallType type) => switch (this) {
    // El negro de la Ultra Ball algo más pulido, para que tenga reflejo.
    shell => type == PokeBallType.ultra ? 0.28 : 0.32,
    matte => 0.85,
    ring || halo => 0.55,
    button => 0.25,
  };
}

/// Una bola (o media) como una malla por cada [BallSurface] que tenga.
typedef BallPieces = Map<BallSurface, MeshBuffers>;

/// Una Poké Ball en dos mitades para poder ABRIRLA (al absorber al Pokémon
/// o cuando se escapa): la tapa gira sobre la bisagra trasera.
///
/// [top] ya está desplazada para que su origen sea la bisagra ([hinge], en
/// la parte de atrás de la bola); [bottom] tiene el origen en el centro de
/// la bola y lleva el aro, el aro de luz y el botón (la tapa no lleva
/// muesca). El botón mira hacia +Z.
typedef PokeBallParts = ({BallPieces top, BallPieces bottom, Vector3 hinge});

// --- Medidas de la ficha (R = 1) ---

/// Media altura de la franja: |y| ≤ 0.075 (latitud ±4.30°).
const _bandHalf = 0.075;

/// La franja va HUNDIDA: radio 0.975 (el labio es la pared que queda).
const _bandRadius = 0.975;

/// La bola es hueca: radio interior.
const _innerRadius = 0.93;

/// Las calcomanías (alas, "H") flotan apenas sobre la carcasa. La ficha
/// dice 1.006; con 1.008 ningún triángulo plano de la calcomanía llega a
/// hundirse bajo la carcasa (lo comprueba un test).
const _decalRadius = 1.008;

const _lonSegments = 32;
const _shellRings = 7;
const _innerLon = 16;
const _innerRings = 3;
const _buttonSegments = 24;

/// Perfiles (radio, z) de las piezas del botón, torneadas sobre el eje +Z.
const _ringProfile = [
  (0.300, 0.930),
  (0.300, 1.018),
  (0.282, 1.035),
  (0.195, 1.035),
];
const _buttonProfile = [
  (0.170, 1.035),
  (0.170, 1.058),
  (0.156, 1.070),
  (0.0, 1.070),
];

/// El aro de luz: corona plana justo delante del aro. Llega un poco más
/// afuera que el hueco del aro (0.195) para tapar la costura entre sus 24
/// lados y los 32 del aro (es del mismo color cuando está apagado).
const _haloInner = 0.170;
const _haloOuter = 0.198;
const _haloZ = 1.0355;

/// Alas de la Super Ball: centradas en la longitud ±72° (0° = botón), con
/// semiancho 36°·cos(1.5 λ) entre la franja y la latitud 60° (la punta).
const _wingCenter = 72.0;
const _wingHalfWidth = 36.0;
const _wingTip = 60.0;

/// "H" de la Ultra Ball: palos en 0.30 ≤ |x| ≤ 0.62 (de delante a atrás) y
/// travesaño |x| < 0.30, |z| ≤ 0.12 sobre el polo.
const _hInner = 0.30;
const _hOuter = 0.62;
const _hBar = 0.12;

/// Destino de los triángulos: uno por superficie, con normal por vértice.
typedef _Sink = void Function(
  BallSurface surface,
  Vector3 a,
  Vector3 b,
  Vector3 c,
  Vector3 na,
  Vector3 nb,
  Vector3 nc,
  Vector4 color,
);

/// Cuadrilátero suave a-b-c-d. El ORDEN se decide solo: la cara queda
/// mirando hacia donde apuntan sus normales (así ninguna pieza sale del
/// revés, ni siquiera el interior, que mira hacia dentro).
void _quad(
  _Sink sink,
  BallSurface surface,
  List<Vector3> p,
  List<Vector3> n,
  Vector4 color,
) {
  final average = n.fold(Vector3.zero(), (sum, v) => sum + v);
  // El triángulo más grande de los dos posibles da la orientación (en las
  // puntas, un lado del cuadrilátero puede medir cero).
  final area =
      (p[1] - p[0]).cross(p[2] - p[0]) + (p[2] - p[0]).cross(p[3] - p[0]);
  final flip = area.dot(average) < 0;
  void tri(int i, int j, int k) => flip
      ? sink(surface, p[i], p[k], p[j], n[i], n[k], n[j], color)
      : sink(surface, p[i], p[j], p[k], n[i], n[j], n[k], color);
  tri(0, 1, 2);
  tri(0, 2, 3);
}

/// Refleja la mitad de arriba en la de abajo (y → −y), sin volverla del
/// revés.
_Sink _mirrored(_Sink sink) {
  Vector3 m(Vector3 v) => Vector3(v.x, -v.y, v.z);
  return (s, a, b, c, na, nb, nc, color) =>
      sink(s, m(a), m(c), m(b), m(na), m(nc), m(nb), color);
}

/// Dirección desde el centro para una latitud y longitud (en radianes):
/// longitud 0 = frente (+Z), +90° = +X. En el polo da el punto EXACTO
/// (cos 90° no da 0 justo: saldrían triángulos casi planos que, según el
/// redondeo, a veces se dibujan y a veces no).
Vector3 _direction(double lat, double lon) {
  if (lat >= math.pi / 2 - 1e-12) return Vector3(0, 1, 0);
  return Vector3(
    math.cos(lat) * math.sin(lon),
    math.sin(lat),
    math.cos(lat) * math.cos(lon),
  );
}

Vector4 _topColor(PokeBallType type) => switch (type) {
  PokeBallType.poke => BallPalette.red,
  PokeBallType.great => BallPalette.blue,
  PokeBallType.ultra => BallPalette.black,
};

/// Media bola de ARRIBA (y ≥ 0): carcasa, franja con su labio, interior
/// hueco con el canto de corte, y las marcas si las lleva ([marks]). La de
/// abajo es su reflejo (con la carcasa blanca y sin marcas).
void _half(_Sink sink, Vector4 shellColor, {PokeBallType? marks}) {
  const tau = 2 * math.pi;
  final bandLat = math.asin(_bandHalf); // 4.30°

  // Carcasa: casquete de radio 1 con anillos de latitud uniformes; el
  // primero cae justo en el borde de la franja. Normal = posición.
  for (var i = 0; i < _shellRings; i++) {
    final lat0 = bandLat + (math.pi / 2 - bandLat) * i / _shellRings;
    final lat1 = bandLat + (math.pi / 2 - bandLat) * (i + 1) / _shellRings;
    for (var j = 0; j < _lonSegments; j++) {
      final lon0 = tau * j / _lonSegments;
      final lon1 = tau * (j + 1) / _lonSegments;
      final a = _direction(lat0, lon0);
      final b = _direction(lat0, lon1);
      if (i == _shellRings - 1) {
        // Último anillo: abanico hasta el polo.
        final pole = Vector3(0, 1, 0);
        _quad(
          sink,
          BallSurface.shell,
          [a, b, pole, pole],
          [a, b, pole, pole],
          shellColor,
        );
        continue;
      }
      final c = _direction(lat1, lon1);
      final d = _direction(lat1, lon0);
      _quad(sink, BallSurface.shell, [a, b, c, d], [a, b, c, d], shellColor);
    }
  }

  // Franja hundida (radio 0.975, de y = 0 a y = 0.075) y el labio: la pared
  // plana en y = 0.075 que la separa de la carcasa (mira hacia la franja).
  final bandTop = math.asin(_bandHalf / _bandRadius);
  final lipInner = math.sqrt(_bandRadius * _bandRadius - _bandHalf * _bandHalf);
  final lipOuter = math.sqrt(1 - _bandHalf * _bandHalf);
  final down = Vector3(0, -1, 0);
  for (var j = 0; j < _lonSegments; j++) {
    final lon0 = tau * j / _lonSegments;
    final lon1 = tau * (j + 1) / _lonSegments;
    final n = [
      _direction(0, lon0),
      _direction(0, lon1),
      _direction(bandTop, lon1),
      _direction(bandTop, lon0),
    ];
    _quad(
      sink,
      BallSurface.matte,
      [for (final v in n) v * _bandRadius],
      n,
      BallPalette.band,
    );
    Vector3 ring(double r, double lon) =>
        Vector3(r * math.sin(lon), _bandHalf, r * math.cos(lon));
    _quad(
      sink,
      BallSurface.matte,
      [
        ring(lipInner, lon0),
        ring(lipInner, lon1),
        ring(lipOuter, lon1),
        ring(lipOuter, lon0),
      ],
      [down, down, down, down],
      BallPalette.band,
    );
    // Canto de corte (y = 0, de 0.93 a 0.975): lo que se ve al abrirla.
    Vector3 cut(double r, double lon) =>
        Vector3(r * math.sin(lon), 0, r * math.cos(lon));
    _quad(
      sink,
      BallSurface.matte,
      [
        cut(_innerRadius, lon0),
        cut(_innerRadius, lon1),
        cut(_bandRadius, lon1),
        cut(_bandRadius, lon0),
      ],
      [down, down, down, down],
      BallPalette.rim,
    );
  }

  // Interior: media esfera de radio 0.93 con las normales hacia DENTRO.
  for (var i = 0; i < _innerRings; i++) {
    final lat0 = math.pi / 2 * i / _innerRings;
    final lat1 = math.pi / 2 * (i + 1) / _innerRings;
    for (var j = 0; j < _innerLon; j++) {
      final lon0 = tau * j / _innerLon;
      final lon1 = tau * (j + 1) / _innerLon;
      final d = [
        _direction(lat0, lon0),
        _direction(lat0, lon1),
        _direction(lat1, lon1),
        _direction(lat1, lon0),
      ];
      _quad(
        sink,
        BallSurface.matte,
        [for (final v in d) v * _innerRadius],
        [for (final v in d) -v],
        BallPalette.inside,
      );
    }
  }

  switch (marks) {
    case PokeBallType.great:
      _wings(sink);
    case PokeBallType.ultra:
      _letterH(sink);
    case PokeBallType.poke || null:
      break;
  }
}

/// Las dos alas rojas de la Super Ball, como calcomanía sobre la tapa.
void _wings(_Sink sink) {
  const rows = 8;
  const columns = 8;
  const deg = math.pi / 180;
  final bandLat = math.asin(_bandHalf) / deg;
  for (final side in [-1.0, 1.0]) {
    Vector3 at(int row, int column) {
      final lat = bandLat + (_wingTip - bandLat) * row / rows;
      // En la punta el ancho es 0 exacto (el coseno no llega a darlo).
      final half = row == rows
          ? 0.0
          : _wingHalfWidth * math.cos(1.5 * lat * deg);
      final lon = _wingCenter + half * (2 * column / columns - 1);
      return _direction(lat * deg, side * lon * deg);
    }

    for (var i = 0; i < rows; i++) {
      for (var j = 0; j < columns; j++) {
        final d = [at(i, j), at(i, j + 1), at(i + 1, j + 1), at(i + 1, j)];
        _quad(
          sink,
          BallSurface.shell,
          [for (final v in d) v * _decalRadius],
          d,
          BallPalette.red,
        );
      }
    }
  }
}

/// La "H" amarilla de la Ultra Ball, como calcomanía sobre la tapa: dos
/// palos de delante a atrás y un travesaño sobre el polo.
void _letterH(_Sink sink) {
  const r = _decalRadius;
  // Palos: para cada x fija, la tapa corta un arco de círculo en el plano
  // y-z; se recorre por ÁNGULO (no por z) para que los tramos cercanos a la
  // franja, donde la bola cae casi en vertical, no queden largos.
  const columns = 3;
  const rows = 20;
  for (final side in [-1.0, 1.0]) {
    Vector3 at(int column, int row) {
      final x = side * (_hInner + (_hOuter - _hInner) * column / columns);
      final rho = math.sqrt(r * r - x * x);
      final start = math.asin(_bandHalf / rho);
      final angle = start + (math.pi - 2 * start) * row / rows;
      return Vector3(x, rho * math.sin(angle), rho * math.cos(angle));
    }

    for (var i = 0; i < columns; i++) {
      for (var j = 0; j < rows; j++) {
        final p = [at(i, j), at(i + 1, j), at(i + 1, j + 1), at(i, j + 1)];
        _quad(sink, BallSurface.shell, p, [
          for (final v in p) v.normalized(),
        ], BallPalette.yellow);
      }
    }
  }
  // Travesaño.
  const across = 6;
  const along = 2;
  Vector3 bar(int i, int j) {
    final x = _hInner * (2 * i / across - 1);
    final z = _hBar * (2 * j / along - 1);
    return Vector3(x, math.sqrt(r * r - x * x - z * z), z);
  }

  for (var i = 0; i < across; i++) {
    for (var j = 0; j < along; j++) {
      final p = [bar(i, j), bar(i + 1, j), bar(i + 1, j + 1), bar(i, j + 1)];
      _quad(sink, BallSurface.shell, p, [
        for (final v in p) v.normalized(),
      ], BallPalette.yellow);
    }
  }
}

/// Pieza torneada sobre el eje +Z a partir de un perfil (radio, z). Cada
/// tramo del perfil lleva su propia normal: aristas duras entre la pared,
/// el bisel y la cara, y redondo alrededor del eje.
void _lathe(
  _Sink sink,
  BallSurface surface,
  List<(double, double)> profile,
  int segments,
  Vector4 color,
) {
  for (var k = 0; k + 1 < profile.length; k++) {
    final (r0, z0) = profile[k];
    final (r1, z1) = profile[k + 1];
    // Normal del tramo en el plano (radio, z), hacia fuera.
    final nr = z1 - z0;
    final nz = -(r1 - r0);
    final length = math.sqrt(nr * nr + nz * nz);
    for (var j = 0; j < segments; j++) {
      final t0 = 2 * math.pi * j / segments;
      final t1 = 2 * math.pi * (j + 1) / segments;
      Vector3 point(double r, double z, double t) =>
          Vector3(r * math.cos(t), r * math.sin(t), z);
      Vector3 normal(double t) => Vector3(
        nr / length * math.cos(t),
        nr / length * math.sin(t),
        nz / length,
      );
      _quad(
        sink,
        surface,
        [
          point(r0, z0, t0),
          point(r0, z0, t1),
          point(r1, z1, t1),
          point(r1, z1, t0),
        ],
        [normal(t0), normal(t1), normal(t1), normal(t0)],
        color,
      );
    }
  }
}

/// El botón delantero (va con la BASE): aro negro, aro de luz y disco.
void _button(_Sink sink) {
  _lathe(sink, BallSurface.ring, _ringProfile, _lonSegments, BallPalette.ring);
  _lathe(
    sink,
    BallSurface.halo,
    [(_haloOuter, _haloZ), (_haloInner, _haloZ)],
    _buttonSegments,
    BallPalette.ring,
  );
  _lathe(
    sink,
    BallSurface.button,
    _buttonProfile,
    _buttonSegments,
    BallPalette.button,
  );
}

/// Constructores por superficie, con la misma transformación de partida.
Map<BallSurface, MeshBuilder> _builders(Matrix4 transform) => {
  for (final s in BallSurface.values) s: MeshBuilder()..push(transform),
};

_Sink _into(Map<BallSurface, MeshBuilder> builders) =>
    (s, a, b, c, na, nb, nc, color) =>
        builders[s]!.smoothTriangle(a, b, c, na, nb, nc, color);

BallPieces _finish(Map<BallSurface, MeshBuilder> builders) => {
  for (final MapEntry(:key, :value) in builders.entries)
    if (value.build() case final mesh when !mesh.isEmpty) key: mesh,
};

/// Poké Ball entera de radio [radius], centrada en el origen.
BallPieces buildPokeBall(PokeBallType type, {double radius = 1}) {
  final builders = _builders(Matrix4.diagonal3Values(radius, radius, radius));
  final sink = _into(builders);
  _half(sink, _topColor(type), marks: type);
  _half(_mirrored(sink), BallPalette.white);
  _button(sink);
  return _finish(builders);
}

/// La misma bola partida en tapa y base (ver [PokeBallParts]).
PokeBallParts buildPokeBallParts(PokeBallType type, {double radius = 1}) {
  final hinge = Vector3(0, 0, -_bandRadius * radius);
  final scale = Matrix4.diagonal3Values(radius, radius, radius);
  final top = _builders(Matrix4.translation(-hinge)..multiply(scale));
  final bottom = _builders(scale);
  _half(_into(top), _topColor(type), marks: type);
  final base = _into(bottom);
  _half(_mirrored(base), BallPalette.white);
  _button(base);
  return (top: _finish(top), bottom: _finish(bottom), hinge: hinge);
}

/// Haz de luz vertical (dos planos cruzados) que se desvanece hacia
/// arriba: marca desde lejos dónde hay algo que recoger. [color] lleva el
/// brillo en rgb (puede pasar de 1 para que el "bloom" lo haga resplandecer)
/// y la opacidad de la base en alfa.
MeshBuffers buildGlowBeam(
  Vector4 color, {
  double width = 0.55,
  double height = 2.4,
}) {
  final b = MeshBuilder();
  final top = Vector4(color.x, color.y, color.z, 0);
  final w = width / 2;
  for (final (dx, dz) in [(w, 0.0), (0.0, w)]) {
    final a = Vector3(-dx, 0, -dz);
    final bb = Vector3(dx, 0, dz);
    final c = Vector3(dx, height, dz);
    final d = Vector3(-dx, height, -dz);
    // Las dos caras (se ve desde cualquier lado).
    b
      ..shadedTriangle(a, bb, c, color, color, top)
      ..shadedTriangle(a, c, d, color, top, top)
      ..shadedTriangle(a, c, bb, color, top, color)
      ..shadedTriangle(a, d, c, color, top, top);
  }
  return b.build();
}
