import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'wind.dart';

/// Un vilano (la semilla con pelusa del diente de león) que flota: el
/// viento lo arrastra, sube y baja despacio y gira sobre sí mismo.
class FloatingSeed {
  FloatingSeed({
    required Vector3 position,
    required this.life,
    required this.phase,
    required this.spin,
  }) : position = position.clone();

  final Vector3 position;

  /// Empujón que le dio alguien al pasar corriendo (se frena enseguida).
  final Vector3 push = Vector3.zero();

  /// Segundos que flota antes de irse, y los que lleva.
  final double life;
  double age = 0;

  /// Fase de su vaivén vertical y giro (rad/s).
  final double phase;
  final double spin;
  double angle = 0;

  /// Tamaño relativo para dibujarlo: aparece y se va encogiendo (en el
  /// primer y el último segundo), sin transparencias.
  double get scale {
    final fadeIn = math.min(1.0, age / SeedDrift.fadeTime);
    final fadeOut = math.min(1.0, (life - age) / SeedDrift.fadeTime);
    return math.max(0, math.min(fadeIn, fadeOut));
  }

  bool get isDead => age >= life;
}

/// VILANOS al viento (Dart puro, decorado): siempre hay unos cuantos
/// flotando alrededor del jugador (aparecen entre [nearest] y [farthest]
/// m, sobre todo a barlovento, para que crucen por delante), arrastrados
/// por el viento (más deprisa en cada ráfaga, la misma de [Wind]) y
/// subiendo y bajando despacio. Si pasas corriendo entre ellos, salen
/// despedidos hacia arriba. Solo es estado; el renderer los dibuja.
class SeedDrift {
  SeedDrift({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;
  final List<FloatingSeed> _seeds = [];

  List<FloatingSeed> get seeds => List.unmodifiable(_seeds);

  /// Cuántos flotan a la vez (el renderer reserva este número).
  static const maxSeeds = 36;

  /// Dónde aparecen (m del jugador) y a qué altura (m).
  static const nearest = 3.0;
  static const farthest = 16.0;
  static const minHeight = 0.4;
  static const maxHeight = 2.4;

  /// Más lejos que esto del jugador, se quitan (y aparecen otros).
  static const range = 22.0;

  /// Lo que dura cada uno (s) y lo que tarda en aparecer o irse.
  static const minLife = 9.0;
  static const maxLife = 16.0;
  static const fadeTime = 1.0;

  /// Arrastre del viento (m/s): un poco en calma y mucho más en ráfaga.
  static const calmDrift = 0.35;
  static const gustDrift = 1.8;

  /// Al pasar corriendo a menos de [kickRadius] m, los levanta y aparta.
  static const kickRadius = 1.6;
  static const kickSpeed = 2.4;

  /// Altura (m sobre los pies) desde la que se mide ese empujón.
  static const chestHeight = 0.9;

  double _between(double a, double b) => a + (b - a) * _random.nextDouble();

  /// Uno nuevo alrededor de [player]: dos de cada tres a barlovento (el
  /// viento los trae hacia el jugador).
  FloatingSeed _spawn(Vector3 player) {
    final upwind = math.atan2(-Wind.direction.x, -Wind.direction.z);
    final a = _random.nextDouble() < 2 / 3
        ? upwind + _between(-1.2, 1.2)
        : _random.nextDouble() * 2 * math.pi;
    final d = _between(nearest, farthest);
    return FloatingSeed(
      position: Vector3(
        player.x + math.sin(a) * d,
        _between(minHeight, maxHeight),
        player.z + math.cos(a) * d,
      ),
      life: _between(minLife, maxLife),
      phase: _random.nextDouble() * 2 * math.pi,
      spin: _between(-2, 2),
    );
  }

  /// Avanza [dt] segundos con el jugador en [player] y [time] el reloj del
  /// juego (para las ráfagas). [running]: va corriendo (los espanta).
  void update(
    double dt, {
    required double time,
    required Vector3 player,
    bool running = false,
  }) {
    for (final s in _seeds) {
      s
        ..age += dt
        ..angle += s.spin * dt;
      final gust = Wind.gustAt(time, s.position.x, s.position.z);
      final drift = calmDrift + gustDrift * gust;
      if (running) {
        // Desde el pecho, no desde los pies: casi todos flotan a 1-2 m.
        final away = s.position - player
          ..y -= chestHeight;
        final d = away.length;
        if (d < kickRadius && d > 1e-6) {
          away.scale(kickSpeed * (1 - d / kickRadius) / d);
          s.push
            ..add(away)
            ..y += kickSpeed * 0.5 * (1 - d / kickRadius);
        }
      }
      // Sube y baja despacio (como si respirara) y se aparta del suelo.
      final bob = 0.18 * math.sin(time * 0.9 + s.phase);
      final lift = s.position.y < minHeight ? 0.4 : 0.0;
      s.position
        ..x += (Wind.direction.x * drift + s.push.x) * dt
        ..y += (bob + lift + s.push.y) * dt
        ..z += (Wind.direction.z * drift + s.push.z) * dt;
      s.push.scale(math.exp(-1.5 * dt));
    }
    _seeds.removeWhere(
      (s) =>
          s.isDead ||
          Vector3(s.position.x - player.x, 0, s.position.z - player.z).length >
              range,
    );
    while (_seeds.length < maxSeeds) {
      _seeds.add(_spawn(player));
    }
  }
}
