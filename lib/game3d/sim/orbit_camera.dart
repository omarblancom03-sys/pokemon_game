import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

/// Cámara en tercera persona (estilo GTA): orbita alrededor del jugador.
///
/// Se describe con tres números:
///  - [yaw]: ángulo horizontal alrededor del jugador (radianes).
///  - [pitch]: inclinación hacia abajo (0 = a ras de suelo).
///  - [distance]: metros entre la cámara y el punto que mira.
///
/// Con yaw = 0 la cámara está en +Z respecto al jugador y mira hacia -Z.
/// Es Dart puro (sin motor): se prueba con tests normales.
class OrbitCamera {
  OrbitCamera({
    this.yaw = 0,
    this.pitch = 0.45,
    this.distance = 7,
    this.minPitch = 0.12,
    this.maxPitch = 1.25,
    this.minDistance = 3.5,
    this.maxDistance = 14,
    this.targetHeight = 1.3,
  });

  double yaw;
  double pitch;
  double distance;

  /// 0 = cámara normal, 1 = apuntando (más cerca y sobre el hombro
  /// derecho, como en los juegos de acción). Se anima entre ambos.
  double aim = 0;

  final double minPitch;
  final double maxPitch;
  final double minDistance;
  final double maxDistance;

  /// Altura (sobre los pies del jugador) del punto al que se mira: los
  /// hombros, para que el personaje no quede en el borde de la pantalla.
  final double targetHeight;

  /// Gira la cámara. [dYaw] horizontal, [dPitch] vertical (se limita para
  /// no meterse bajo el suelo ni quedar totalmente cenital).
  void rotate(double dYaw, double dPitch) {
    yaw = _wrapAngle(yaw + dYaw);
    pitch = (pitch + dPitch).clamp(minPitch, maxPitch);
  }

  /// Acerca (negativo) o aleja (positivo) la cámara, con límites.
  void zoom(double delta) {
    distance = (distance + delta).clamp(minDistance, maxDistance);
  }

  /// Acerca [aim] a 1 (apuntando) o a 0 con suavidad.
  void updateAim(double dt, {required bool aiming}) {
    final goal = aiming ? 1.0 : 0.0;
    aim += (goal - aim) * math.min(1, dt * 10);
  }

  /// Distancia real teniendo en cuenta el modo apuntar.
  double get effectiveDistance => distance * (1 - 0.5 * aim);

  /// Punto que mira la cámara, a partir de los pies del jugador. Al apuntar
  /// se desplaza sobre el hombro derecho para no tapar la mira.
  Vector3 targetFor(Vector3 playerFeet) =>
      playerFeet +
      Vector3(0, targetHeight + 0.15 * aim, 0) +
      right * (0.65 * aim);

  /// Posición de la cámara (el "ojo") para un jugador en [playerFeet].
  Vector3 eyeFor(Vector3 playerFeet) {
    final d = effectiveDistance;
    final horizontal = math.cos(pitch) * d;
    return targetFor(playerFeet) +
        Vector3(
          math.sin(yaw) * horizontal,
          math.sin(pitch) * d,
          math.cos(yaw) * horizontal,
        );
  }

  /// Dirección en la que mira la cámara (del ojo al objetivo), unitaria.
  Vector3 lookDirection(Vector3 playerFeet) =>
      (targetFor(playerFeet) - eyeFor(playerFeet))..normalize();

  /// "Adelante" en el suelo (de la cámara hacia el jugador), unitario.
  Vector3 get forward => Vector3(-math.sin(yaw), 0, -math.cos(yaw));

  /// "Derecha" en el suelo, unitario y perpendicular a [forward].
  Vector3 get right => Vector3(math.cos(yaw), 0, -math.sin(yaw));

  /// Deja el ángulo en (-π, π] para que no crezca sin fin.
  static double _wrapAngle(double a) {
    var r = a % (2 * math.pi);
    if (r > math.pi) r -= 2 * math.pi;
    return r;
  }
}
