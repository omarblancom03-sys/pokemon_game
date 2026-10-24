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
    this.leftArm,
    this.twist = 0,
    this.roll = 0,
  });

  /// Postura para alguien que ha andado [distanceWalked] metros y va a
  /// [speed] m/s, con [walkSpeed] y [runSpeed] como referencias.
  factory TrainerPose.fromMotion({
    required double distanceWalked,
    required double speed,
    required double walkSpeed,
    required double runSpeed,
    double crouch = 0,
    double aim = 0,
    double? throwProgress,
    bool lob = false,
    double? rollProgress,
  }) {
    // Voltereta: hecho una bola (piernas y brazos recogidos) y girando.
    if (rollProgress != null) {
      return TrainerPose(
        crouch: 1,
        armSwing: 0.9,
        roll: rollProgress.clamp(0.0, 1.0),
      );
    }
    // 0 quieto, 1 andando, hasta ~1.7 corriendo.
    final intensity = (speed / walkSpeed).clamp(0.0, runSpeed / walkSpeed);
    final phase = distanceWalked / strideLength * 2 * math.pi;
    final swing = math.sin(phase) * 0.55 * math.min(intensity, 1.3);
    final g = _gesture(
      aim: aim,
      progress: throwProgress,
      lob: lob,
      armSwing: -swing * 0.9,
    );
    // El paso del lanzamiento solo se nota parado: andando mandan las
    // piernas (si no, patinarían).
    final still = (1 - intensity).clamp(0.0, 1.0);
    return TrainerPose(
      legSwing: swing + g.step * still,
      armSwing: -swing * 0.9,
      bob: math.sin(phase).abs() * 0.06 * math.min(intensity, 1.3),
      lean: 0.18 * (speed / runSpeed).clamp(0.0, 1.0) + 0.35 * crouch + g.lean,
      crouch: math.min(1, crouch + g.dip),
      rightArm: g.rightArm,
      leftArm: g.leftArm,
      twist: g.twist,
    );
  }

  /// Momento del gesto (0..1) en el que la mano ya pasó por el punto de
  /// soltar y el cuerpo llega al final del giro: de ahí en adelante, la
  /// inercia y la vuelta a la calma.
  static const peak = 0.42;

  // Posturas clave del GESTO de lanzar: al apuntar (preparado), en el
  // [peak] y en reposo. Una Poké Ball se lanza POR ENCIMA del hombro: el
  // brazo sale de arriba y atrás, pasa por encima de la cabeza (por eso
  // los ángulos bajan de −π) y termina cruzado por delante; el torso gira
  // antes que el brazo, el izquierdo (que apuntaba) se recoge y la pierna
  // izquierda da un paso. Una baya se lanza POR DEBAJO, en globo: el brazo
  // sale de abajo y atrás y sube por delante. Al terminar, el brazo
  // derecho queda colgando (−2π es lo mismo que 0).
  static const _ballAim = _Keyframe(
    rightArm: -2.5,
    leftArm: 1.45,
    twist: 0.45,
    lean: -0.06,
  );
  static const _ballPeak = _Keyframe(
    rightArm: -4.3,
    leftArm: -0.4,
    twist: -0.4,
    lean: 0.22,
    step: -0.35,
    dip: 0.1,
  );
  static const _ballFollow = -5.5; // brazo cruzado por delante, abajo
  static const _ballRest = _Keyframe(rightArm: -2 * math.pi);
  static const _lobAim = _Keyframe(
    rightArm: -0.7,
    leftArm: 0.6,
    twist: 0.25,
    lean: 0.08,
    dip: 0.15,
  );
  static const _lobPeak = _Keyframe(
    rightArm: 1.9,
    leftArm: 0.2,
    twist: -0.2,
    lean: -0.08,
    step: -0.2,
  );
  static const _rest = _Keyframe();

  /// Postura del gesto: [aim] (0..1) es cuánto está apuntando (la
  /// postura de preparado entra y sale suave, ver World3DSim.aimPose); en
  /// un lanzamiento ([progress] 0..1) es de dónde arranca: preparado o,
  /// en un tiro rápido sin apuntar, desde los brazos como iban
  /// ([armSwing]). Sin gesto, brazos con su balanceo normal.
  static _Gesture _gesture({
    required double aim,
    required double? progress,
    required bool lob,
    required double armSwing,
  }) {
    final k = _smooth(aim.clamp(0.0, 1.0));
    // Los brazos como van al andar (el izquierdo, al revés que el derecho).
    final swinging = _Keyframe(rightArm: armSwing, leftArm: -armSwing);
    final from = _Keyframe.mix(swinging, lob ? _lobAim : _ballAim, k);
    if (progress == null || progress >= 1) {
      return k > 0 ? from.gesture() : _rest.gesture(arms: false);
    }
    final t = progress.clamp(0.0, 1.0);
    final top = lob ? _lobPeak : _ballPeak;
    final rest = lob ? _rest : _ballRest;
    if (t < peak) {
      final u = t / peak;
      // El torso se adelanta al brazo; el brazo acelera (latigazo).
      final body = _smooth(math.min(1, u * 1.3));
      final arm = math.pow(u, 1.6).toDouble();
      return _Keyframe.mix(from, top, body, arm: arm).gesture();
    }
    final u = (t - peak) / (1 - peak);
    final g = _Keyframe.mix(top, rest, _smooth(u)).gesture();
    if (lob) return g;
    // Por encima del hombro, el brazo sigue de largo (cruzado por delante)
    // antes de volver a colgar.
    const cross = 0.35;
    final arm = u < cross
        ? top.rightArm + (_ballFollow - top.rightArm) * _smooth(u / cross)
        : _ballFollow +
              (rest.rightArm - _ballFollow) *
                  _smooth((u - cross) / (1 - cross));
    return (
      rightArm: arm,
      leftArm: g.leftArm,
      twist: g.twist,
      lean: g.lean,
      step: g.step,
      dip: g.dip,
    );
  }

  static double _smooth(double u) => u * u * (3 - 2 * u);

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
  /// Positivo = hacia delante desde colgando; por debajo de −π el brazo
  /// ha pasado por encima de la cabeza.
  final double? rightArm;

  /// Ángulo fijo del brazo izquierdo (al apuntar señala al objetivo);
  /// null = balanceo. Positivo = hacia delante.
  final double? leftArm;

  /// Giro del torso (rad) sobre la cadera: positivo = hombro derecho
  /// hacia atrás (preparado para lanzar); negativo, hacia delante.
  final double twist;

  /// Voltereta: 0..1 (0 = no rueda).
  final double roll;

  /// Giro hacia delante de la voltereta (rad): una vuelta entera, despacio
  /// al tirarse y al levantarse.
  double get rollAngle => 2 * math.pi * roll * roll * (3 - 2 * roll);

  /// Cuánto se levanta del suelo al rodar (m), para no hundirse en él.
  double get rollLift => 0.45 * math.sin(math.pi * roll);

  /// Altura (m) del punto sobre el que gira al rodar (el centro del cuerpo
  /// hecho una bola).
  static const rollPivot = 0.65;
}

/// Gesto en un instante (ver TrainerPose._gesture).
typedef _Gesture = ({
  double? rightArm,
  double? leftArm,
  double twist,
  double lean,
  double step,
  double dip,
});

/// Una postura clave del gesto de lanzar: brazos (rad; positivo = hacia
/// delante), giro del torso, inclinación extra, paso de la pierna
/// izquierda (negativo = adelantada) y cuánto flexiona las rodillas.
class _Keyframe {
  const _Keyframe({
    this.rightArm = 0,
    this.leftArm = 0,
    this.twist = 0,
    this.lean = 0,
    this.step = 0,
    this.dip = 0,
  });

  /// Entre [a] y [b] en [u] (0..1); el brazo derecho puede ir a su ritmo
  /// ([arm]).
  factory _Keyframe.mix(_Keyframe a, _Keyframe b, double u, {double? arm}) {
    double lerp(double x, double y, double k) => x + (y - x) * k;
    return _Keyframe(
      rightArm: lerp(a.rightArm, b.rightArm, arm ?? u),
      leftArm: lerp(a.leftArm, b.leftArm, u),
      twist: lerp(a.twist, b.twist, u),
      lean: lerp(a.lean, b.lean, u),
      step: lerp(a.step, b.step, u),
      dip: lerp(a.dip, b.dip, u),
    );
  }

  final double rightArm;
  final double leftArm;
  final double twist;
  final double lean;
  final double step;
  final double dip;

  /// Como gesto; sin [arms], los brazos quedan libres (balanceo normal).
  _Gesture gesture({bool arms = true}) => (
    rightArm: arms ? rightArm : null,
    leftArm: arms ? leftArm : null,
    twist: twist,
    lean: lean,
    step: step,
    dip: dip,
  );
}
