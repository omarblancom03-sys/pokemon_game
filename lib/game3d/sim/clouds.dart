import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'world3d_config.dart';

/// Una nube: dónde cae su SOMBRA en el suelo, a qué altura está, su tamaño
/// y su forma. La nube de verdad está arriba, en la línea del sol
/// ([CloudLayer.skyOf]).
class Cloud {
  Cloud({
    required this.shadow,
    required this.height,
    required this.radius,
    required this.stretch,
    required this.yaw,
  });

  /// Centro de la sombra en el suelo (y = 0).
  final Vector3 shadow;

  /// Altura de la nube (m).
  final double height;

  /// Radio (m) de la nube y de su sombra.
  final double radius;

  /// Alargamiento (1 = redonda): tan ancha como [radius]·[stretch] y tan
  /// profunda como [radius].
  final double stretch;

  /// Giro sobre sí misma (rad).
  final double yaw;
}

/// Zona (en el suelo) por la que pasa una banda de nubes y cómo son.
class _Band {
  const _Band({
    required this.reach,
    required this.height,
    required this.heightJitter,
    required this.radius,
    required this.radiusJitter,
  });

  /// Metros que se sale del mapa por cada lado.
  final double reach;
  final double height;
  final double heightJitter;
  final double radius;
  final double radiusJitter;
}

/// NUBES (Dart puro), en dos bandas que el viento empuja igual:
///  - [clouds]: las de ENCIMA del mapa. Su sombra oscurece el suelo a su
///    paso (ellas no se ven: la cámara nunca mira tan arriba).
///  - [farClouds]: más altas, grandes y lejanas; son las que se ven en el
///    cielo, por encima del bosque. No dan sombra en el mapa.
/// La que sale del todo por un lado vuelve a entrar por el opuesto. Es
/// decorado: usa su propio azar.
class CloudLayer {
  CloudLayer({
    required this.width,
    required this.depth,
    math.Random? random,
    int count = 16,
    int farCount = 30,
  }) : _random = random ?? math.Random() {
    for (var i = 0; i < count; i++) {
      clouds.add(_spawn(_near, anywhere: true));
    }
    for (var i = 0; i < farCount; i++) {
      farClouds.add(_spawn(_far, anywhere: true));
    }
  }

  /// Tamaño del mapa (m).
  final double width;
  final double depth;
  final math.Random _random;

  /// Encima del mapa (con sombra).
  final List<Cloud> clouds = [];

  /// Lejos, en el cielo que se ve (sin sombra en el mapa).
  final List<Cloud> farClouds = [];

  /// Viento (m/s): hacia +X, como el que mece la hierba.
  static final wind = Vector3(1.6, 0, 0.4);

  /// Las de encima: a 40 m y con [nearReach] m fuera del mapa por cada
  /// lado (así sus sombras entran y salen sin aparecer de golpe).
  static const nearReach = 45.0;
  static const _near = _Band(
    reach: nearReach,
    height: 40,
    heightJitter: 0,
    radius: 6,
    radiusJitter: 4,
  );

  /// Las lejanas: a 50–80 m y hasta [farReach] m del mapa. Para verse
  /// sobre el bosque tienen que estar a más de ~110 m del jugador.
  static const farReach = 260.0;
  static const _far = _Band(
    reach: farReach,
    height: 50,
    heightJitter: 30,
    radius: 14,
    radiusJitter: 12,
  );

  /// Una nube nueva de [band]: en cualquier sitio de su zona ([anywhere])
  /// o en [x], [z].
  Cloud _spawn(_Band band, {bool anywhere = false, double? x, double? z}) {
    double along(double size) =>
        -band.reach + _random.nextDouble() * (size + 2 * band.reach);
    return Cloud(
      shadow: Vector3(
        anywhere ? along(width) : x!,
        0,
        anywhere ? along(depth) : z!,
      ),
      height: band.height + _random.nextDouble() * band.heightJitter,
      radius: band.radius + _random.nextDouble() * band.radiusJitter,
      stretch: 1 + _random.nextDouble() * 0.6,
      yaw: (_random.nextDouble() - 0.5) * 0.8,
    );
  }

  /// Dónde está la nube en el cielo para que su sombra caiga en
  /// [Cloud.shadow]: subiendo desde la sombra en contra de la luz del sol.
  static Vector3 skyOf(Cloud cloud) {
    final sun = World3DConfig.sunDirection;
    return cloud.shadow - sun * (cloud.height / -sun.y);
  }

  /// Las mueve con el viento.
  void update(double dt) {
    _move(clouds, _near, dt);
    _move(farClouds, _far, dt);
  }

  /// La que sale del todo de su zona por un lado entra por el opuesto (con
  /// otra forma y en otro sitio a lo largo del borde).
  void _move(List<Cloud> list, _Band band, double dt) {
    final spanX = width + 2 * band.reach;
    final spanZ = depth + 2 * band.reach;
    for (var i = 0; i < list.length; i++) {
      final c = list[i]..shadow.addScaled(wind, dt);
      if (c.shadow.x > width + band.reach) {
        list[i] = _spawn(
          band,
          x: c.shadow.x - spanX,
          z: -band.reach + _random.nextDouble() * spanZ,
        );
      } else if (c.shadow.z > depth + band.reach) {
        list[i] = _spawn(
          band,
          x: -band.reach + _random.nextDouble() * spanX,
          z: c.shadow.z - spanZ,
        );
      }
    }
  }
}
