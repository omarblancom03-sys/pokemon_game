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

  /// Distancia máxima que deja libre lo que hay detrás del jugador (un
  /// árbol, una casa). null = nada estorba. La calcula [avoidObstacles].
  double? obstructedDistance;

  /// Inclinación extra (rad) para asomarse por encima de lo que estorba
  /// cuando detrás del jugador no cabe la cámara (de espaldas a un árbol o
  /// a una casa). 0 = nada. La calcula [avoidObstacles].
  double pitchLift = 0;

  /// Inclinación con la que se coloca de verdad la cámara. [pitch] es la
  /// que eligió el jugador (y la que usa el tiro "a ojo").
  double get effectivePitch => pitch + pitchLift;

  /// Distancia mínima al jugador aunque algo estorbe (más cerca se
  /// metería dentro de su cabeza).
  static const minClearDistance = 1.2;

  /// Si detrás queda menos sitio que esto, la cámara sube para mirar desde
  /// arriba (como en los juegos de plataformas) hasta [maxLiftedPitch].
  static const comfortDistance = 2.8;
  static const maxLiftedPitch = 1.5;

  /// Metros por segundo a los que vuelve a alejarse cuando deja de estorbar.
  static const clearRecoverSpeed = 5.0;

  /// Evita que la cámara quede DENTRO de un obstáculo o detrás de él
  /// ([heightAt] da la altura de lo que hay en el suelo en cada punto):
  ///  1. Si detrás del jugador no cabe (de espaldas a un árbol), sube poco a
  ///     poco hasta asomarse por encima.
  ///  2. Recorre la línea del jugador a la cámara y, si choca con algo más
  ///     alto que ella en ese punto, la acerca al instante; cuando deja de
  ///     estorbar, se aleja poco a poco (así no da tirones junto a un árbol).
  void avoidObstacles(
    Vector3 playerFeet,
    double Function(double x, double z) heightAt,
    double dt,
  ) {
    final desired = distance * (1 - 0.5 * aim);
    final target = targetFor(playerFeet);

    // 1. ¿Hace falta subir? Se prueba de la inclinación elegida hacia arriba
    // y se queda la primera que deja sitio (o la que más deja).
    final wanted = math.min(desired, comfortDistance);
    var liftGoal = 0.0;
    var bestClear = _clearance(target, pitch, desired, heightAt);
    if (bestClear < wanted) {
      const samples = 12;
      for (var i = 1; i <= samples; i++) {
        final p = pitch + (maxLiftedPitch - pitch) * i / samples;
        final clear = _clearance(target, p, desired, heightAt);
        if (clear > bestClear) {
          bestClear = clear;
          liftGoal = p - pitch;
        }
        if (clear >= wanted) break;
      }
    }
    final rate = liftGoal > pitchLift ? 8.0 : 3.0;
    pitchLift += (liftGoal - pitchLift) * math.min(1, dt * rate);

    // 2. Distancia libre con la inclinación real.
    final allowed = _clearance(target, effectivePitch, desired, heightAt);
    final current = obstructedDistance ?? desired;
    final next = allowed < current
        ? allowed
        : math.min(allowed, current + clearRecoverSpeed * dt);
    obstructedDistance = next >= desired - 1e-6 ? null : next;
  }

  /// Distancia (hasta [desired]) que queda libre desde [target] hacia atrás
  /// con inclinación [p], sin bajar de [minClearDistance].
  double _clearance(
    Vector3 target,
    double p,
    double desired,
    double Function(double x, double z) heightAt,
  ) {
    final horizontal = math.cos(p);
    final dx = math.sin(yaw) * horizontal;
    final dy = math.sin(p);
    final dz = math.cos(yaw) * horizontal;
    for (var t = 0.3; t <= desired + 0.3; t += 0.1) {
      final x = target.x + dx * t;
      final z = target.z + dz * t;
      if (target.y + dy * t < heightAt(x, z)) {
        return math.max(minClearDistance, t - 0.4);
      }
    }
    return desired;
  }

  /// Acerca [aim] a 1 (apuntando) o a 0 con suavidad.
  void updateAim(double dt, {required bool aiming}) {
    final goal = aiming ? 1.0 : 0.0;
    aim += (goal - aim) * math.min(1, dt * 10);
  }

  /// Distancia real teniendo en cuenta el modo apuntar y los obstáculos.
  double get effectiveDistance => math.min(
    distance * (1 - 0.5 * aim),
    obstructedDistance ?? double.infinity,
  );

  /// Punto que mira la cámara, a partir de los pies del jugador. Al apuntar
  /// se desplaza sobre el hombro derecho para no tapar la mira.
  Vector3 targetFor(Vector3 playerFeet) =>
      playerFeet +
      Vector3(0, targetHeight + 0.15 * aim, 0) +
      right * (0.65 * aim);

  /// Posición de la cámara (el "ojo") para un jugador en [playerFeet].
  Vector3 eyeFor(Vector3 playerFeet) {
    final d = effectiveDistance;
    final p = effectivePitch;
    final horizontal = math.cos(p) * d;
    return targetFor(playerFeet) +
        Vector3(
          math.sin(yaw) * horizontal,
          math.sin(p) * d,
          math.cos(yaw) * horizontal,
        );
  }

  /// Dirección en la que mira la cámara (del ojo al objetivo), unitaria.
  Vector3 lookDirection(Vector3 playerFeet) =>
      (targetFor(playerFeet) - eyeFor(playerFeet))..normalize();

  /// Ángulo de visión vertical (rad). Lo usa el motor y también [project].
  static const fovY = 55 * math.pi / 180;

  /// Dónde se ve el punto [world] en pantalla, en coordenadas normalizadas
  /// (-1..1; x a la derecha, y hacia arriba) para una pantalla de
  /// proporción [aspect] (ancho / alto). null si queda detrás de la cámara.
  /// Sirve para dibujar la mira sobre el objetivo fijado.
  ({double x, double y})? project(
    Vector3 world,
    Vector3 playerFeet, {
    required double aspect,
  }) {
    final view = makeViewMatrix(
      eyeFor(playerFeet),
      targetFor(playerFeet),
      Vector3(0, 1, 0),
    );
    final projection = makePerspectiveMatrix(fovY, aspect, 0.1, 400);
    final clip = projection
        .multiplied(view)
        .transform(Vector4(world.x, world.y, world.z, 1));
    if (clip.w <= 1e-6) return null;
    return (x: clip.x / clip.w, y: clip.y / clip.w);
  }

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
