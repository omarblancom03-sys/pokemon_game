import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'minimap.dart';
import 'world3d_sim.dart';

/// LO QUE SE MARCA EN EL MAPA GRANDE (Dart puro): el mundo entero con el
/// norte arriba. Lo fijo o que brilla de lejos se ve en todo el mapa
/// (carteles, arbustos con sus bayas, Poké Balls y bayas del suelo); lo
/// que se mueve (Pokémon), solo cerca del jugador, como en el minimapa: el
/// mapa es para orientarse, no para encontrar Pokémon sin buscarlos.
class MapOverview {
  const MapOverview({
    required this.width,
    required this.depth,
    required this.player,
    required this.facing,
    required this.cameraYaw,
    this.balls = const [],
    this.bushes = const [],
    this.berries = const [],
    this.signs = const [],
    this.wild = const [],
  });

  /// Todo lo que hay que marcar ahora en [sim].
  factory MapOverview.of(World3DSim sim) {
    final me = sim.player.position;
    bool near(Vector3 p) =>
        Vector3(p.x - me.x, 0, p.z - me.z).length <= wildRange;
    return MapOverview(
      width: sim.width,
      depth: sim.depth,
      player: me,
      facing: sim.player.facing,
      cameraYaw: sim.camera.yaw,
      balls: [for (final item in sim.fieldItems.items) item.position],
      bushes: [
        for (final bush in sim.berries.bushes)
          (at: bush.center, berries: bush.berries),
      ],
      berries: [
        for (final berry in sim.berries.loose)
          if (berry.landed) berry.position,
      ],
      signs: [
        for (final cell in sim.signReader.signs)
          sim.cellCenter(cell.col, cell.row),
      ],
      wild: [
        for (final w in sim.wild)
          // Los escondidos tampoco salen aquí: se buscan por la hierba.
          if (w.isFree && !w.hidden && near(w.position))
            (at: w.position, mark: MinimapMark.forWild(w)),
      ],
    );
  }

  /// Hasta dónde (m) se ven los Pokémon en el mapa: lo que alcanza el
  /// minimapa.
  static const wildRange = MinimapView.defaultRadius;

  /// Tamaño del mundo en metros (ancho en X, fondo en Z).
  final double width;
  final double depth;

  final Vector3 player;

  /// Hacia dónde mira el jugador (0 = +Z, como en la simulación).
  final double facing;

  /// El yaw de la cámara (ver OrbitCamera).
  final double cameraYaw;

  /// Poké Balls en el suelo.
  final List<Vector3> balls;

  /// Arbustos y cuántas bayas le quedan a cada uno.
  final List<({Vector3 at, int berries})> bushes;

  /// Bayas sueltas en el suelo (lanzadas o caídas).
  final List<Vector3> berries;

  /// Carteles (centro de su casilla).
  final List<Vector3> signs;

  /// Pokémon cerca del jugador, con lo que saben de él.
  final List<({Vector3 at, MinimapMark mark})> wild;

  /// Punto del mundo → mapa: de 0 a 1 en x (hacia el este) y en y (hacia
  /// el sur, abajo en la pantalla).
  ({double x, double y}) project(Vector3 world) =>
      (x: world.x / width, y: world.z / depth);

  /// Ángulo en pantalla (rad; 0 = arriba, sentido horario) de algo que
  /// mira hacia [facing] (0 = +Z = sur, abajo).
  static double screenAngle(double facing) => math.pi - facing;

  /// Hacia dónde mira el jugador, en pantalla.
  double get playerAngle => screenAngle(facing);

  /// Hacia dónde mira la cámara, en pantalla. Su "adelante" es
  /// (−sin yaw, −cos yaw), es decir, mirar hacia yaw + π.
  double get cameraAngle => screenAngle(cameraYaw + math.pi);
}
