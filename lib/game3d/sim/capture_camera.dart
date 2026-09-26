import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'throwing.dart';

/// CÁMARA DE CAPTURA: cuando una Poké Ball golpea a un Pokémon, la cámara
/// va a encuadrarla de cerca (absorbe, cae, se sacude y el resultado) y
/// después vuelve sola al jugador. Así las sacudidas se ven aunque el tiro
/// haya sido lejano.
///
/// El jugador manda: moverse, girar la cámara, volver a pulsar apuntar o
/// lanzar otra cosa la SUELTA (hasta que otra bola golpee). Si el tiro fue
/// cercano apenas se mueve: la bola ya se ve bien.
///
/// Solo decide qué mirar ([point]) y cuánto ([focus], 0..1, suavizado);
/// cómo se coloca la cámara lo hace OrbitCamera. Dart puro.
class CaptureCamera {
  /// Bola que sigue (null = ninguna).
  String? get followedId => _followedId;
  String? _followedId;

  /// El jugador la soltó para la bola que sigue.
  bool get released => _released;
  bool _released = false;

  /// ¿Tiene ahora el protagonismo? (hay una bola que enseñar y el jugador
  /// no la ha soltado). Mientras, apuntar queda en suspenso.
  bool get engaged => _showing && !_released;
  bool _showing = false;

  /// 0..1: cuánto manda la cámara de captura (suavizado).
  double weight = 0;

  /// Cuánto se acerca según lo lejos que cayó la bola (0 cerca, 1 lejos).
  double _reach = 1;

  /// Lo que se le pasa a OrbitCamera.focus.
  double get focus => weight * _reach;

  /// Punto que se encuadra: la bola (suavizado, sin tirones al caer).
  Vector3 get point => _point.clone();
  final Vector3 _point = Vector3.zero();

  /// Tras el resultado se queda mirando un poco: las estrellas del "¡clic!"
  /// o el Pokémon saliendo de la bola.
  static const caughtLinger = 1.1;
  static const escapeLinger = 0.5;

  /// Rapidez (1/s) al acercarse y al volver: en ~1 s está encuadrada.
  static const inRate = 3.2;
  static const outRate = 2.4;

  /// Con la bola a menos de [nearDistance] m del jugador no se acerca; a
  /// partir de [farDistance] m, del todo.
  static const nearDistance = 2.5;
  static const farDistance = 4.5;

  /// Altura (m) sobre el centro de la bola a la que se mira.
  static const lookHeight = 0.2;

  /// El jugador hizo algo (moverse, girar la cámara, apuntar de nuevo,
  /// lanzar): se suelta la bola actual.
  void release() {
    if (_followedId != null) _released = true;
  }

  /// Avanza [dt] s mirando las bolas de [balls] y dónde está el jugador
  /// ([player], los pies). [interrupted]: el jugador hizo algo este
  /// fotograma (ver [release]).
  void update(
    double dt, {
    required List<ThrownBall> balls,
    required Vector3 player,
    bool interrupted = false,
  }) {
    // La bola que más recientemente golpeó y aún tiene algo que enseñar.
    ThrownBall? current;
    for (final b in balls) {
      if (!_hasShow(b)) continue;
      if (current == null || b.hitAge! > current.hitAge!) current = b;
    }
    if (current != null && current.id != _followedId) {
      _followedId = current.id;
      _released = false;
      if (weight < 0.05) _point.setFrom(_lookAt(current));
    }
    if (interrupted) release();
    _showing = current != null;

    if (current != null) {
      final goal = _lookAt(current);
      _point.add((goal - _point)..scale(math.min(1, dt * 6)));
      final away = current.position - player
        ..y = 0;
      _reach = ((away.length - nearDistance) / (farDistance - nearDistance))
          .clamp(0.0, 1.0);
    }
    final target = engaged ? 1.0 : 0.0;
    final rate = target > weight ? inRate : outRate;
    weight += (target - weight) * math.min(1, dt * rate);
    if (weight < 1e-3 && !engaged) weight = 0;
  }

  static Vector3 _lookAt(ThrownBall b) =>
      b.position + Vector3(0, lookHeight, 0);

  /// ¿Esta bola tiene algo que enseñar? Desde que golpea hasta un poco
  /// después del resultado.
  static bool _hasShow(ThrownBall b) {
    if (b.hitAge == null) return false;
    return switch (b.phase) {
      BallPhase.absorbing || BallPhase.falling || BallPhase.shaking => true,
      BallPhase.caught => b.phaseTime < caughtLinger,
      BallPhase.escaped => b.phaseTime < escapeLinger,
      BallPhase.flying || BallPhase.missed => false,
    };
  }
}
