import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

/// Una nubecilla de polvo: nace en el suelo, sale despedida un poco, sube,
/// crece y se desvanece.
class DustPuff {
  DustPuff({
    required Vector3 position,
    required Vector3 velocity,
    required this.size,
    this.life = 0.7,
  }) : position = position.clone(),
       velocity = velocity.clone();

  final Vector3 position;
  final Vector3 velocity;

  /// Tamaño máximo (radio en metros).
  final double size;

  /// Segundos que dura.
  final double life;

  double age = 0;

  /// 0 al nacer … 1 al desaparecer.
  double get progress => math.min(1, age / life);

  /// Radio para dibujarla: crece deprisa y luego se encoge un poco.
  double get radius {
    final t = progress;
    final grow = 1 - math.pow(1 - math.min(1, t * 2.5), 2);
    return size * (0.35 + 0.65 * grow) * (1 - 0.3 * t);
  }

  /// Opacidad 0..1: se desvanece hacia el final.
  double get opacity => 0.55 * (1 - progress * progress);

  bool get isDead => age >= life;
}

/// POLVO (Dart puro): las nubecillas que levantan los pies al correr, un
/// frenazo o una Poké Ball al golpear el suelo. Solo es estado; el
/// renderer las dibuja y los tests comprueban cuándo aparecen.
class DustSystem {
  DustSystem({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;
  final List<DustPuff> _puffs = [];

  List<DustPuff> get puffs => List.unmodifiable(_puffs);

  /// Nunca más de estas a la vez (el renderer reserva este número).
  static const maxPuffs = 40;

  /// Frenado del movimiento de cada nubecilla (1/s) y lo que sube (m/s).
  static const drag = 4.0;
  static const rise = 0.5;

  double _jitter(double amount) => (_random.nextDouble() - 0.5) * 2 * amount;

  void _add(DustPuff puff) {
    if (_puffs.length >= maxPuffs) _puffs.removeAt(0); // la más vieja
    _puffs.add(puff);
  }

  /// Un pie que toca el suelo corriendo en [foot], moviéndose con
  /// [velocity]: nubecillas pequeñas que se quedan atrás.
  void footstep(Vector3 foot, Vector3 velocity) {
    final back = Vector3(-velocity.x, 0, -velocity.z)..scale(0.12);
    for (var i = 0; i < 2; i++) {
      _add(
        DustPuff(
          position: Vector3(foot.x + _jitter(0.1), 0.08, foot.z + _jitter(0.1)),
          velocity: back + Vector3(_jitter(0.5), 0.3, _jitter(0.5)),
          size: 0.16 + _random.nextDouble() * 0.08,
          life: 0.55 + _random.nextDouble() * 0.2,
        ),
      );
    }
  }

  /// Un golpe contra el suelo en [at]: un corro de nubecillas que salen
  /// hacia fuera. [strength] 0..1 escala el tamaño y el número.
  void burst(Vector3 at, {double strength = 1}) {
    final s = strength.clamp(0.2, 1.0);
    final count = (3 + 5 * s).round();
    final start = _random.nextDouble() * 2 * math.pi;
    for (var i = 0; i < count; i++) {
      final a = start + i * 2 * math.pi / count;
      final speed = 1.2 + 1.2 * s;
      _add(
        DustPuff(
          position: Vector3(at.x, 0.06, at.z),
          velocity: Vector3(math.sin(a) * speed, 0.4, math.cos(a) * speed),
          size: (0.14 + 0.12 * s) * (0.8 + _random.nextDouble() * 0.4),
          life: 0.5 + 0.3 * s,
        ),
      );
    }
  }

  /// Envejece, mueve y retira las que ya se han desvanecido.
  void update(double dt) {
    final slow = math.exp(-drag * dt);
    for (final p in _puffs) {
      p
        ..age += dt
        ..position.addScaled(p.velocity, dt)
        ..position.y += rise * dt;
      p.velocity
        ..x *= slow
        ..y *= slow
        ..z *= slow;
    }
    _puffs.removeWhere((p) => p.isDead);
  }
}
