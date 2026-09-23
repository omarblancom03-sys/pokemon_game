import 'dart:math' as math;

/// Postura del entrenador en un instante: ángulos de piernas y brazos,
/// rebote vertical e inclinación. Se calcula a partir del movimiento real
/// (metros andados y rapidez), así los pies nunca "patinan": si no avanza,
/// no mueve las piernas.
class TrainerPose {
  const TrainerPose({
    this.legSwing = 0,
    this.armSwing = 0,
    this.bob = 0,
    this.lean = 0,
    this.crouch = 0,
    this.rightArm,
  });

  /// Postura para alguien que ha andado [distanceWalked] metros y va a
  /// [speed] m/s, con [walkSpeed] y [runSpeed] como referencias.
  factory TrainerPose.fromMotion({
    required double distanceWalked,
    required double speed,
    required double walkSpeed,
    required double runSpeed,
    double crouch = 0,
    bool aiming = false,
    double? throwProgress,
  }) {
    // 0 quieto, 1 andando, hasta ~1.7 corriendo.
    final intensity = (speed / walkSpeed).clamp(0.0, runSpeed / walkSpeed);
    final phase = distanceWalked / strideLength * 2 * math.pi;
    final swing = math.sin(phase) * 0.55 * math.min(intensity, 1.3);
    return TrainerPose(
      legSwing: swing,
      armSwing: -swing * 0.9,
      bob: math.sin(phase).abs() * 0.06 * math.min(intensity, 1.3),
      lean: 0.18 * (speed / runSpeed).clamp(0.0, 1.0) + 0.35 * crouch,
      crouch: crouch,
      rightArm: _rightArm(aiming: aiming, throwProgress: throwProgress),
    );
  }

  /// Brazo derecho al apuntar (echado atrás, preparado) y al lanzar
  /// (barrido rápido hacia delante). null = balanceo normal.
  static double? _rightArm({required bool aiming, double? throwProgress}) {
    const back = -2.5; // rad: brazo arriba y atrás
    const forward = 1.1; // rad: brazo estirado hacia delante
    if (throwProgress != null && throwProgress < 1) {
      final t = throwProgress;
      // Rápido hacia delante y vuelta suave.
      return t < 0.4
          ? back + (forward - back) * (t / 0.4)
          : forward * (1 - (t - 0.4) / 0.6);
    }
    return aiming ? back : null;
  }

  /// Metros por ciclo completo de pasos (izquierda + derecha).
  static const strideLength = 1.5;

  static const idle = TrainerPose();

  /// Radianes: pierna derecha hacia delante (+) o atrás (-). La izquierda
  /// va en contra.
  final double legSwing;

  /// Radianes: los brazos se balancean al revés que las piernas.
  final double armSwing;

  /// Metros que sube el cuerpo en cada paso.
  final double bob;

  /// Radianes de inclinación hacia delante al correr (y agachado).
  final double lean;

  /// 0 de pie, 1 agachado (sigilo).
  final double crouch;

  /// Ángulo fijo del brazo derecho (apuntar/lanzar); null = balanceo.
  final double? rightArm;
}
