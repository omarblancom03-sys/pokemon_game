import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

/// Una huella en la tierra del camino: dónde, hacia dónde apunta la
/// punta y lo marcada que quedó.
class Footprint {
  Footprint({
    required Vector3 position,
    required this.facing,
    required this.depth,
  }) : position = Vector3(position.x, 0, position.z);

  /// En el suelo (y = 0).
  final Vector3 position;

  /// Hacia dónde apunta la punta (0 = +Z, como el jugador).
  final double facing;

  /// Lo marcada que quedó, 0..1: corriendo se hunde más que andando y
  /// agachado casi no deja.
  final double depth;

  double age = 0;

  /// 0..1: nítida al principio; se va borrando en los últimos
  /// [FootprintTrail.fadeTime] segundos.
  double get opacity {
    final left = FootprintTrail.life - age;
    return depth * (left / FootprintTrail.fadeTime).clamp(0.0, 1.0);
  }

  bool get isGone => age >= FootprintTrail.life;
}

/// HUELLAS del entrenador en la tierra del camino (Dart puro): una por
/// pisada, que se borran solas con el tiempo. Es decorado: el renderer
/// las dibuja y los tests comprueban cuándo aparecen y desaparecen.
class FootprintTrail {
  final List<Footprint> _prints = [];

  List<Footprint> get prints => List.unmodifiable(_prints);

  /// Nunca más de estas a la vez (el renderer reserva este número). Con
  /// una pisada cada ~0,5 m son unos 45 m de rastro.
  static const maxPrints = 90;

  /// Segundos que dura una huella y, de ellos, los últimos en los que se
  /// va borrando.
  static const life = 30.0;
  static const fadeTime = 12.0;

  /// Lo marcada que queda una pisada según cómo se va.
  static const runDepth = 1.0;
  static const walkDepth = 0.8;
  static const crouchDepth = 0.45;

  static double depthFor({required bool running, required bool crouching}) =>
      crouching ? crouchDepth : (running ? runDepth : walkDepth);

  /// Un pie que pisa la tierra en [foot] yendo hacia [facing].
  void step(Vector3 foot, double facing, {double depth = walkDepth}) {
    if (_prints.length >= maxPrints) _prints.removeAt(0); // la más vieja
    _prints.add(
      Footprint(
        position: foot,
        facing: facing,
        depth: math.max(0, math.min(1, depth)),
      ),
    );
  }

  /// Envejece y retira las que ya se borraron.
  void update(double dt) {
    for (final p in _prints) {
      p.age += dt;
    }
    _prints.removeWhere((p) => p.isGone);
  }
}
