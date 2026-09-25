import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

/// Una brizna de hierba suelta: sale despedida hacia arriba, da vueltas
/// sobre sí misma y cae planeando hasta el suelo, donde se queda un
/// momento y se encoge hasta desaparecer.
class GrassBlade {
  GrassBlade({
    required Vector3 position,
    required Vector3 velocity,
    required this.heading,
    required this.spin,
    required this.size,
    required this.shade,
  }) : position = position.clone(),
       velocity = velocity.clone();

  final Vector3 position;
  final Vector3 velocity;

  /// Rumbo del eje sobre el que gira (rad, en el suelo).
  final double heading;

  /// Velocidad de giro (rad/s); [angle] es el giro acumulado.
  final double spin;
  double angle = 0;

  /// Largo de la brizna (m).
  final double size;

  /// 0 = verde oscuro … 1 = verde claro (así no son todas iguales).
  final double shade;

  /// Segundos desde que salió.
  double age = 0;

  /// Segundos que lleva en el suelo (null = aún en el aire).
  double? landedFor;

  /// Lo que tarda en encogerse del todo una vez en el suelo (s).
  static const restTime = 0.4;

  /// Por si algo la dejara flotando: nunca dura más de esto (s).
  static const maxAge = 4.0;

  /// Tamaño relativo para dibujarla: entera en el aire; en el suelo se
  /// encoge (así se va sin necesidad de transparencias).
  double get scale {
    final t = landedFor;
    return t == null ? 1 : math.max(0, 1 - t / restTime);
  }

  bool get isDead => (landedFor ?? 0) >= restTime || age >= maxAge;
}

/// BRIZNAS DE HIERBA (Dart puro): las que saltan al pisar la hierba alta
/// (más si corres; ninguna agachado: se ve el ruido que haces), las que
/// escupe a ratos la hierba que se agita sobre un Pokémon escondido y el
/// puñado que sale cuando uno salta fuera. Solo es estado; el renderer
/// las dibuja.
class GrassBladeSystem {
  GrassBladeSystem({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;
  final List<GrassBlade> _blades = [];

  List<GrassBlade> get blades => List.unmodifiable(_blades);

  /// Nunca más de estas a la vez (el renderer reserva este número).
  static const maxBlades = 48;

  /// Gravedad (m/s²) y rozamiento del aire (1/s): poco al subir (salen
  /// disparadas por encima de la hierba) y mucho al bajar (caen
  /// planeando, a 2 m/s como mucho).
  static const gravity = 6.0;
  static const dragUp = 0.8;
  static const dragDown = 3.0;

  /// Altura de la hierba alta (m): las briznas salen de sus puntas.
  static const grassTop = 0.6;

  /// Briznas por segundo que suelta una mata agitándose del todo.
  static const rustleRate = 14.0;

  /// Largo de las briznas (m): las de los pies, pequeñas; las de la
  /// hierba que se agita y las del surtidor, más grandes (tienen que
  /// verse de lejos: son la pista de dónde se esconde un Pokémon).
  static const footBladeSize = 0.2;
  static const bigBladeSize = 0.34;

  double _jitter(double amount) => (_random.nextDouble() - 0.5) * 2 * amount;

  /// Añade una brizna de unos [size] m (±20 %). Las grandes, además, son
  /// más claras (resaltan sobre la hierba oscura).
  void _add({
    required Vector3 position,
    required Vector3 velocity,
    double size = footBladeSize,
  }) {
    final big = size > footBladeSize;
    if (_blades.length >= maxBlades) _blades.removeAt(0); // la más vieja
    _blades.add(
      GrassBlade(
        position: position,
        velocity: velocity,
        heading: _random.nextDouble() * 2 * math.pi,
        spin: (4 + _random.nextDouble() * 6) * (_random.nextBool() ? 1 : -1),
        size: size * (0.8 + _random.nextDouble() * 0.4),
        shade: big ? 0.6 + 0.4 * _random.nextDouble() : _random.nextDouble(),
      ),
    );
  }

  /// Un pie que pisa la hierba alta en [foot], moviéndose con [velocity].
  /// Corriendo salen tres briznas que suben por encima de la hierba;
  /// andando, una que apenas asoma.
  void footstep(Vector3 foot, Vector3 velocity, {required bool running}) {
    final count = running ? 3 : 1;
    final up = running ? 3.2 : 1.8;
    // Salen hacia delante y a los lados (las patea el pie).
    final kick = Vector3(velocity.x, 0, velocity.z)..scale(0.25);
    for (var i = 0; i < count; i++) {
      _add(
        position: Vector3(
          foot.x + _jitter(0.2),
          grassTop * 0.8,
          foot.z + _jitter(0.2),
        ),
        velocity:
            kick +
            Vector3(
              _jitter(0.9),
              up * (0.8 + _random.nextDouble() * 0.4),
              _jitter(0.9),
            ),
      );
    }
  }

  /// Hierba agitándose sobre un Pokémon escondido en [at] con fuerza
  /// [burst] (0..1) durante [dt] segundos: de vez en cuando escupe una
  /// brizna hacia arriba (más cuanto más fuerte se agita).
  void rustle(Vector3 at, double burst, double dt) {
    if (burst <= 0) return;
    if (_random.nextDouble() >= rustleRate * burst * dt) return;
    _add(
      position: Vector3(at.x + _jitter(0.5), grassTop, at.z + _jitter(0.5)),
      velocity: Vector3(
        _jitter(0.7),
        2 + _random.nextDouble() * 1.2,
        _jitter(0.7),
      ),
      size: bigBladeSize,
    );
  }

  /// Un Pokémon escondido salta fuera en [at]: un surtidor de briznas en
  /// todas direcciones.
  void burst(Vector3 at) {
    const count = 12;
    final start = _random.nextDouble() * 2 * math.pi;
    for (var i = 0; i < count; i++) {
      final a = start + i * 2 * math.pi / count;
      final speed = 1 + _random.nextDouble() * 1.2;
      _add(
        position: Vector3(at.x, grassTop * 0.8, at.z),
        velocity: Vector3(
          math.sin(a) * speed,
          2.6 + _random.nextDouble() * 1.4,
          math.cos(a) * speed,
        ),
        size: bigBladeSize,
      );
    }
  }

  /// Un arbusto sacudido en [at] (de [top] m de alto): se le caen unas
  /// hojitas desde arriba, que salen hacia los lados y bajan planeando.
  void leaves(Vector3 at, {double top = 1}) {
    const count = 6;
    for (var i = 0; i < count; i++) {
      final a = _random.nextDouble() * 2 * math.pi;
      _add(
        position: Vector3(
          at.x + math.sin(a) * 0.5,
          top * (0.6 + _random.nextDouble() * 0.4),
          at.z + math.cos(a) * 0.5,
        ),
        velocity: Vector3(
          math.sin(a) * (0.6 + _random.nextDouble()),
          1 + _random.nextDouble() * 1.2,
          math.cos(a) * (0.6 + _random.nextDouble()),
        ),
      );
    }
  }

  /// Altura a la que se posan (justo sobre el suelo).
  static const groundY = 0.02;

  /// Envejece, mueve (caen planeando) y retira las que ya terminaron.
  /// Al tocar el suelo se quedan quietas mientras se encogen.
  void update(double dt) {
    for (final b in _blades) {
      b.age += dt;
      final landed = b.landedFor;
      if (landed != null) {
        b.landedFor = landed + dt;
        continue;
      }
      final k = b.velocity.y > 0 ? dragUp : dragDown;
      b.velocity
        ..y -= gravity * dt
        ..scale(math.exp(-k * dt));
      b.position.addScaled(b.velocity, dt);
      b.angle += b.spin * dt;
      if (b.position.y <= groundY) {
        b.position.y = groundY;
        b.velocity.setZero();
        b.landedFor = 0;
      }
    }
    _blades.removeWhere((b) => b.isDead);
  }
}
