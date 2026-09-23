import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../../game/map/map_layout.dart';
import 'wild_behavior.dart' show PlayerStealth;

/// Una mariposa: revolotea alrededor de su macizo de flores ([home]) y se
/// espanta si el jugador se acerca.
class Butterfly {
  Butterfly({
    required Vector3 home,
    required this.colorIndex,
    this.flapPhase = 0,
  }) : home = home.clone(),
       position = home + Vector3(0, 0.7, 0),
       target = home + Vector3(0, 0.7, 0);

  /// Centro de su macizo de flores (en el suelo).
  final Vector3 home;

  /// Qué color tiene (el renderer elige la paleta).
  final int colorIndex;

  final Vector3 position;

  /// Punto hacia el que revolotea ahora.
  Vector3 target;

  /// Hacia dónde mira (0 = +Z), como el jugador.
  double heading = 0;

  /// Fase del aleteo (radianes).
  double flapPhase;

  /// Segundos que le quedan de huida (0 = tranquila).
  double scaredTime = 0;

  bool get isScared => scaredTime > 0;

  /// Ángulo de las alas (rad): 0 = planas; sube y baja al aletear.
  double get wingAngle => 0.2 + 0.9 * (0.5 + 0.5 * math.sin(flapPhase));
}

/// MARIPOSAS (Dart puro): decorado vivo sobre los macizos de flores. Van
/// de flor en flor sin alejarse y, si te acercas, salen volando hacia
/// arriba y lejos de ti; al rato vuelven. Correr las espanta desde más
/// lejos; agachado puedes acercarte mucho.
class ButterflySwarm {
  ButterflySwarm(this.butterflies, {math.Random? random})
    : _random = random ?? math.Random();

  /// Una mariposa por macizo de flores (`,` en el mapa), como mucho [max]
  /// y separadas al menos [spacing] metros para repartirlas por el mapa.
  factory ButterflySwarm.fromLayout(
    MapLayout layout,
    double tileSize, {
    math.Random? random,
    int max = 12,
    double spacing = 5,
  }) {
    final rng = random ?? math.Random();
    final flowers = <Vector3>[
      for (var row = 0; row < layout.rows; row++)
        for (var col = 0; col < layout.columns; col++)
          if (layout.tileAt(col, row) == TileKind.flowers)
            Vector3((col + 0.5) * tileSize, 0, (row + 0.5) * tileSize),
    ]..shuffle(rng);
    final chosen = <Butterfly>[];
    for (final home in flowers) {
      if (chosen.length >= max) break;
      if (chosen.any((b) => b.home.distanceTo(home) < spacing)) continue;
      chosen.add(
        Butterfly(
          home: home,
          colorIndex: rng.nextInt(1 << 16),
          flapPhase: rng.nextDouble() * 2 * math.pi,
        ),
      );
    }
    return ButterflySwarm(chosen, random: rng);
  }

  final List<Butterfly> butterflies;
  final math.Random _random;

  /// Se espantan si el jugador está a menos de esto (m), según el ruido.
  static double scareDistance(PlayerStealth stealth) => switch (stealth) {
    PlayerStealth.noisy => 4.5,
    PlayerStealth.normal => 2.6,
    PlayerStealth.crouching || PlayerStealth.hidden => 1.0,
  };

  /// Radio (m) y alturas del revoloteo tranquilo alrededor de las flores.
  static const wanderRadius = 1.3;
  static const minHeight = 0.35;
  static const maxHeight = 1.3;

  /// Velocidades (m/s) tranquila y huyendo, y segundos de huida.
  static const calmSpeed = 1.1;
  static const fleeSpeed = 3.2;
  static const fleeSeconds = 2.5;

  /// Avanza [dt] segundos con el jugador en [player] y moviéndose con el
  /// sigilo [stealth] (quieto no espanta a nadie que no esté pegado).
  void update(
    double dt,
    Vector3 player, {
    required PlayerStealth stealth,
    required bool moving,
  }) {
    final reach = moving ? scareDistance(stealth) : 0.6;
    for (final b in butterflies) {
      final flat = Vector3(b.position.x - player.x, 0, b.position.z - player.z);
      if (!b.isScared && flat.length < reach) _scare(b, flat);

      if (b.isScared) {
        b.scaredTime = math.max(0, b.scaredTime - dt);
        if (!b.isScared) b.target = _wanderPoint(b); // vuelve a sus flores
      } else if (b.position.distanceTo(b.target) < 0.15) {
        b.target = _wanderPoint(b);
      }

      final speed = b.isScared ? fleeSpeed : calmSpeed;
      final to = b.target - b.position;
      final d = to.length;
      if (d > 1e-6) {
        b.position.addScaled(to, math.min(1, speed * dt / d));
        if (to.x * to.x + to.z * to.z > 1e-6) {
          b.heading = math.atan2(to.x, to.z);
        }
      }
      b.flapPhase += dt * (b.isScared ? 32 : 18);
    }
  }

  /// Sale volando lejos de quien se acerca ([away], en el suelo) y hacia
  /// arriba.
  void _scare(Butterfly b, Vector3 away) {
    final dir = away.length2 > 1e-6
        ? (away..normalize())
        : Vector3(math.sin(b.heading), 0, math.cos(b.heading));
    b
      ..scaredTime = fleeSeconds
      ..target =
          b.position +
          dir * (fleeSpeed * fleeSeconds * 0.8) +
          Vector3(0, 2.5 + _random.nextDouble(), 0);
  }

  /// Un punto al azar sobre su macizo de flores.
  Vector3 _wanderPoint(Butterfly b) {
    final a = _random.nextDouble() * 2 * math.pi;
    final r = math.sqrt(_random.nextDouble()) * wanderRadius;
    return b.home +
        Vector3(
          math.sin(a) * r,
          minHeight + _random.nextDouble() * (maxHeight - minHeight),
          math.cos(a) * r,
        );
  }
}
