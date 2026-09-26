import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math.dart';

import 'world3d_config.dart';

/// Decide si el jugador cabe en un punto del suelo (x, z). Lo aporta el
/// mundo (mapa ASCII); así el cuerpo no depende del mapa directamente.
typedef FootprintTest = bool Function(Rect footprint);

/// EL JUGADOR en el mundo 3D: posición en el suelo, velocidad y hacia
/// dónde mira. Movimiento libre (no por casillas) con aceleración, y
/// choques que dejan deslizarse junto a paredes y árboles.
class PlayerBody {
  PlayerBody({
    required this.config,
    required this.canOccupy,
    required Vector3 position,
    this.facing = math.pi,
  }) : _position = position.clone();

  final World3DConfig config;
  final FootprintTest canOccupy;

  Vector3 _position;
  final Vector3 _velocity = Vector3.zero();

  /// Ángulo horizontal hacia donde mira el cuerpo (0 = hacia +Z).
  double facing;

  /// Metros recorridos en total: marca el ritmo de la animación de pasos.
  double distanceWalked = 0;

  Vector3 get position => _position.clone();
  Vector3 get velocity => _velocity.clone();

  /// Rapidez actual en el suelo (m/s).
  double get speed => _velocity.length;

  bool get isMoving => speed > 0.2;

  /// Coloca al jugador en otro sitio (por ejemplo, al reaparecer).
  void teleport(Vector3 position) {
    _position = position.clone();
    _velocity.setZero();
  }

  /// Avanza [dt] segundos. [wish] es la dirección deseada en el suelo
  /// (x, z) de longitud 0..1, ya en coordenadas del mundo.
  ///
  /// Agachado va más lento. Con [face] el cuerpo mira hacia esa dirección
  /// aunque camine hacia otro lado (al apuntar se camina de lado).
  void update(
    double dt,
    Vector3 wish, {
    bool running = false,
    bool crouching = false,
    Vector3? face,
  }) {
    final maxSpeed = crouching
        ? config.crouchSpeed
        : running
        ? config.runSpeed
        : config.walkSpeed;
    final target = Vector3(wish.x, 0, wish.z)..scale(maxSpeed);

    // Acercar la velocidad a la deseada sin pasarse (aceleración limitada).
    final delta = target - _velocity;
    final maxStep = config.acceleration * dt;
    if (delta.length > maxStep) delta.scale(maxStep / delta.length);
    _velocity.add(delta);

    _moveAxis(_velocity.x * dt, 0);
    _moveAxis(0, _velocity.z * dt);

    // Girar el cuerpo poco a poco hacia donde camina.
    final look = face ?? (wish.length2 > 0.01 ? wish : null);
    if (look != null && look.length2 > 1e-6) {
      final desired = math.atan2(look.x, look.z);
      facing = _turnTowards(facing, desired, config.turnSpeed * dt);
    }
  }

  /// Movimiento FORZADO (una voltereta): va a [speed] m/s hacia [dir]
  /// (unitario, en el suelo), chocando igual que al andar, y se gira
  /// deprisa hacia allí.
  void dash(double dt, Vector3 dir, double speed) {
    _velocity.setValues(dir.x * speed, 0, dir.z * speed);
    _moveAxis(_velocity.x * dt, 0);
    _moveAxis(0, _velocity.z * dt);
    facing = _turnTowards(
      facing,
      math.atan2(dir.x, dir.z),
      config.turnSpeed * 2 * dt,
    );
  }

  /// Mueve por un solo eje; si choca, se anula la velocidad en ese eje.
  /// Separar ejes es lo que permite "deslizarse" pegado a una pared.
  void _moveAxis(double dx, double dz) {
    if (dx == 0 && dz == 0) return;
    final next = _position + Vector3(dx, 0, dz);
    if (canOccupy(footprintAt(next.x, next.z))) {
      distanceWalked += math.sqrt(dx * dx + dz * dz);
      _position = next;
    } else if (dx != 0) {
      _velocity.x = 0;
    } else {
      _velocity.z = 0;
    }
  }

  /// Cuadrado que ocupa el jugador en el suelo (x → left/right, z → top/bottom).
  Rect footprintAt(double x, double z) => Rect.fromCenter(
    center: Offset(x, z),
    width: config.playerRadius * 2,
    height: config.playerRadius * 2,
  );

  /// Gira [from] hacia [to] como mucho [maxStep] radianes, por el lado corto.
  static double _turnTowards(double from, double to, double maxStep) {
    var diff = (to - from) % (2 * math.pi);
    if (diff > math.pi) diff -= 2 * math.pi;
    if (diff.abs() <= maxStep) return to;
    return from + maxStep * diff.sign;
  }
}
