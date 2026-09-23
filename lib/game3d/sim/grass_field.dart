import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../../game/map/map_layout.dart';
import 'cell_noise.dart';

/// Una mata de hierba alta: dónde está, cuánto mide y su fase de viento.
class GrassTuft {
  const GrassTuft({
    required this.x,
    required this.z,
    required this.yaw,
    required this.scale,
    required this.phase,
  });

  final double x;
  final double z;

  /// Giro propio (para que no todas miren igual).
  final double yaw;
  final double scale;

  /// Desfase del vaivén del viento (así no se mueven todas a la vez).
  final double phase;
}

/// Inclinación de una mata: eje horizontal (x, z) y ángulo en radianes.
typedef GrassTilt = ({double axisX, double axisZ, double angle});

/// LA HIERBA ALTA como datos: matas repartidas por las casillas `"` del
/// mapa, y cuánto se inclina cada una por el viento y por quien la pisa.
/// El renderer solo copia estas inclinaciones a la GPU.
class GrassField {
  GrassField(this.tufts);

  /// Reparte [perCell] matas por casilla de hierba alta, siempre igual
  /// para el mismo mapa (ruido estable por casilla).
  factory GrassField.fromLayout(
    MapLayout layout,
    double tileSize, {
    int perCell = 5,
  }) {
    final tufts = <GrassTuft>[];
    for (var row = 0; row < layout.rows; row++) {
      for (var col = 0; col < layout.columns; col++) {
        if (layout.tileAt(col, row) != TileKind.tallGrass) continue;
        for (var i = 0; i < perCell; i++) {
          double n(int salt) => cellNoise(col, row, i * 5 + salt);
          tufts.add(
            GrassTuft(
              x: (col + 0.1 + n(0) * 0.8) * tileSize,
              z: (row + 0.1 + n(1) * 0.8) * tileSize,
              yaw: n(2) * 2 * math.pi,
              scale: 0.8 + n(3) * 0.45,
              phase: n(4) * 2 * math.pi,
            ),
          );
        }
      }
    }
    return GrassField(tufts);
  }

  final List<GrassTuft> tufts;

  /// Radio (m) dentro del cual alguien aparta la hierba al pasar.
  static const pushRadius = 1.2;

  /// Inclinación máxima (rad) al apartarla.
  static const maxPush = 0.95;

  /// Vaivén del viento (rad).
  static const windStrength = 0.08;

  /// Inclinación de [tuft] en el instante [time], apartándose de cada
  /// punto de [pushers] (el jugador, los Pokémon...).
  static GrassTilt tiltFor(
    GrassTuft tuft,
    double time,
    Iterable<Vector3> pushers,
  ) {
    // El viento sopla hacia +X: gira alrededor del eje Z.
    var vx = 0.0;
    var vz = -windStrength * math.sin(time * 1.8 + tuft.phase);

    for (final p in pushers) {
      final dx = tuft.x - p.x;
      final dz = tuft.z - p.z;
      final d = math.sqrt(dx * dx + dz * dz);
      if (d >= pushRadius || d < 1e-6) continue;
      final strength = (1 - d / pushRadius) * maxPush;
      // Eje = arriba × dirección: así la punta se aleja de quien empuja.
      vx += dz / d * strength;
      vz += -dx / d * strength;
    }
    final angle = math.sqrt(vx * vx + vz * vz);
    if (angle < 1e-9) return (axisX: 1, axisZ: 0, angle: 0);
    return (
      axisX: vx / angle,
      axisZ: vz / angle,
      angle: math.min(angle, maxPush),
    );
  }
}
