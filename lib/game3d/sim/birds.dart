import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../../game/map/map_layout.dart';
import 'wild_behavior.dart' show PlayerStealth;

/// Un pájaro de una bandada: en el suelo picotea y da saltitos; en el aire
/// aletea (y a ratos planea) siguiendo a su bandada.
class Bird {
  Bird({
    required Vector3 position,
    required Vector3 offset,
    required this.colorIndex,
    this.flapPhase = 0,
  }) : position = position.clone(),
       offset = offset.clone();

  final Vector3 position;
  final Vector3 velocity = Vector3.zero();

  /// Su sitio dentro de la bandada (en el suelo, respecto al centro).
  final Vector3 offset;

  /// Qué plumaje tiene (el renderer elige la paleta).
  final int colorIndex;

  /// Hacia dónde mira (0 = +Z), como el jugador.
  double heading = 0;

  /// Fase del aleteo (radianes).
  double flapPhase;

  bool flying = false;

  /// Segundos que espera antes de despegar (no salen todos a la vez).
  double takeoffDelay = 0;

  /// Segundos hasta lo siguiente que haga en el suelo.
  double idleTimer = 0;

  /// Picoteo: 1 = cabeza abajo, 0 = arriba.
  double peck = 0;
  double _peckTime = 0;

  /// Saltito en curso: de dónde a dónde y cuánto lleva (0..1).
  Vector3? _hopFrom;
  Vector3? _hopTo;
  double _hopT = 0;

  /// Planeando (alas quietas y abiertas) en vez de aleteando.
  bool gliding = false;

  /// Ángulo de las alas (rad): en el suelo, plegadas junto al cuerpo;
  /// volando, suben y bajan; planeando, abiertas.
  double get wingAngle {
    if (!flying) return -1.25;
    if (gliding) return 0.1;
    return -0.35 + 0.95 * (0.5 + 0.5 * math.sin(flapPhase));
  }
}

/// Una bandada: dónde está posada (o adónde va) y si vuela.
class BirdFlock {
  BirdFlock(this.birds, Vector3 spot) : spot = spot.clone();

  final List<Bird> birds;

  /// Centro del sitio donde está posada o donde se va a posar.
  Vector3 spot;

  /// Punto alto por el que pasa al irse (null = ya va a posarse).
  Vector3? cruise;

  bool get flying => birds.any((b) => b.flying || b.takeoffDelay > 0);
}

/// PÁJAROS (Dart puro): bandadas que se posan en el campo abierto, picotean
/// y dan saltitos. Si te acercas salen volando todos (desde más lejos si
/// corres; agachado te acercas mucho) o si cae una Poké Ball cerca; suben,
/// cruzan el cielo y se posan en otro sitio lejos de ti. Es decorado: usa
/// su propio azar.
class BirdSystem {
  BirdSystem({
    required this.spots,
    required Vector3 player,
    math.Random? random,
    int flocks = 2,
    int perFlock = 5,
  }) : _random = random ?? math.Random() {
    for (var i = 0; i < flocks && spots.isNotEmpty; i++) {
      final spot = _pickSpot(player, minFromPlayer: 15);
      this.flocks.add(
        BirdFlock([
          for (var j = 0; j < perFlock; j++) _newBird(spot, j, perFlock),
        ], spot),
      );
    }
  }

  /// Sitios donde se pueden posar: el centro de cada casilla abierta (ni
  /// hierba alta ni obstáculos) cuyas vecinas también se pisan, para que
  /// la bandada entera quepa.
  factory BirdSystem.fromLayout(
    MapLayout layout,
    double tileSize, {
    required Vector3 player,
    math.Random? random,
  }) {
    bool open(int col, int row) =>
        layout.isWalkable(col, row) &&
        layout.tileAt(col, row) != TileKind.tallGrass;
    return BirdSystem(
      spots: [
        for (var row = 1; row < layout.rows - 1; row++)
          for (var col = 1; col < layout.columns - 1; col++)
            if (open(col, row) &&
                open(col + 1, row) &&
                open(col - 1, row) &&
                open(col, row + 1) &&
                open(col, row - 1))
              Vector3((col + 0.5) * tileSize, 0, (row + 0.5) * tileSize),
      ],
      player: player,
      random: random,
    );
  }

  final List<Vector3> spots;
  final math.Random _random;
  final List<BirdFlock> flocks = [];

  Iterable<Bird> get birds => flocks.expand((f) => f.birds);

  /// Salen volando si el jugador está a menos de esto (m), según el ruido.
  /// Quieto solo si está pegado.
  static double scareDistance(PlayerStealth stealth, {required bool moving}) {
    if (!moving) return 1.2;
    return switch (stealth) {
      PlayerStealth.noisy => 8,
      PlayerStealth.normal => 5,
      PlayerStealth.crouching || PlayerStealth.hidden => 2.2,
    };
  }

  /// Una Poké Ball que cae a menos de esto (m) los espanta.
  static const ballScareDistance = 5.0;

  /// En el suelo no se alejan más que esto (m) del centro de la bandada.
  static const maxWander = 1.4;

  /// Nunca se posan a menos de esto del jugador (m).
  static const landFarFromPlayer = 16.0;

  /// Altura (m) y velocidad (m/s) al cruzar el cielo; aceleración máxima.
  static const cruiseHeight = 10.0;
  static const cruiseSpeed = 7.0;
  static const steering = 14.0;

  Bird _newBird(Vector3 spot, int index, int count) {
    // En corro, a 0,4–1,1 m del centro.
    final a = index * 2 * math.pi / count + _random.nextDouble() * 0.6;
    final r = 0.4 + _random.nextDouble() * 0.7;
    final offset = Vector3(math.sin(a) * r, 0, math.cos(a) * r);
    return Bird(
        position: spot + offset,
        offset: offset,
        colorIndex: _random.nextInt(1 << 16),
        flapPhase: _random.nextDouble() * 2 * math.pi,
      )
      ..heading = _random.nextDouble() * 2 * math.pi
      ..idleTimer = _random.nextDouble() * 1.5;
  }

  /// Un sitio para posarse a más de [minFromPlayer] m del jugador (y, si
  /// se da [awayFrom], hacia el lado contrario al jugador).
  Vector3 _pickSpot(
    Vector3 player, {
    required double minFromPlayer,
    Vector3? awayFrom,
  }) {
    final far = spots
        .where(
          (s) => s.distanceTo(Vector3(player.x, 0, player.z)) > minFromPlayer,
        )
        .toList();
    final pool = far.isEmpty ? spots : far;
    if (awayFrom == null) return pool[_random.nextInt(pool.length)].clone();
    // De 6 al azar, el que queda más al lado contrario del jugador.
    final away = Vector3(awayFrom.x - player.x, 0, awayFrom.z - player.z);
    if (away.length2 > 1e-6) away.normalize();
    Vector3? best;
    var bestScore = -double.infinity;
    for (var i = 0; i < 6; i++) {
      final s = pool[_random.nextInt(pool.length)];
      final score = (s - awayFrom).dot(away);
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    return best!.clone();
  }

  /// Avanza [dt] segundos con el jugador en [player] y moviéndose con el
  /// sigilo [stealth].
  void update(
    double dt,
    Vector3 player, {
    required PlayerStealth stealth,
    required bool moving,
  }) {
    final reach = scareDistance(stealth, moving: moving);
    for (final flock in flocks) {
      if (!flock.flying) {
        final near = flock.birds.any(
          (b) => b.position.distanceTo(Vector3(player.x, 0, player.z)) < reach,
        );
        if (near) _takeOff(flock, player);
      }
      for (final b in flock.birds) {
        if (b.takeoffDelay > 0) {
          b.takeoffDelay = math.max(0, b.takeoffDelay - dt);
          if (b.takeoffDelay == 0) {
            b
              ..flying = true
              ..peck = 0;
          }
        }
        if (b.flying) {
          _fly(flock, b, dt);
        } else if (b.takeoffDelay == 0) {
          _idle(b, flock.spot, dt);
        }
      }
      // Cuando todas han pasado por el punto alto, a posarse.
      final cruise = flock.cruise;
      if (cruise != null &&
          flock.birds.every(
            (b) => b.position.distanceTo(cruise + b.offset) < 4,
          )) {
        flock.cruise = null;
      }
    }
  }

  /// Una Poké Ball cayó en [at]: la bandada que esté cerca sale volando.
  void startle(Vector3 at, Vector3 player) {
    for (final flock in flocks) {
      if (flock.flying) continue;
      final near = flock.birds.any(
        (b) =>
            b.position.distanceTo(Vector3(at.x, 0, at.z)) < ballScareDistance,
      );
      if (near) _takeOff(flock, player);
    }
  }

  /// Todos arriba (cada uno con un pequeño retraso), hacia un sitio lejos
  /// del jugador, pasando por un punto alto a medio camino.
  void _takeOff(BirdFlock flock, Vector3 player) {
    final from = flock.spot;
    final to = _pickSpot(
      player,
      minFromPlayer: landFarFromPlayer,
      awayFrom: from,
    );
    flock
      ..spot = to
      ..cruise = (from + to) * 0.5 + Vector3(0, cruiseHeight, 0);
    for (final b in flock.birds) {
      // Lo que estuviera haciendo en el suelo se queda a medias.
      b
        ..takeoffDelay = 0.01 + _random.nextDouble() * 0.35
        .._hopFrom = null
        .._hopTo = null
        .._peckTime = 0
        ..peck = 0;
    }
  }

  /// En el aire: se dirige al punto alto y luego a su sitio en la bandada;
  /// frena al acercarse al suelo y se posa.
  void _fly(BirdFlock flock, Bird b, double dt) {
    final cruise = flock.cruise;
    final landing = flock.spot + b.offset;
    final target = cruise == null ? landing : cruise + b.offset;
    final to = target - b.position;
    final d = to.length;
    if (cruise == null && d < 0.25) {
      b
        ..position.setFrom(landing)
        ..velocity.setZero()
        ..flying = false
        ..gliding = false
        ..idleTimer = 0.3 + _random.nextDouble();
      return;
    }
    // Al posarse frena cuanto más cerca está.
    final speed = cruise == null
        ? math.min(cruiseSpeed, 0.8 + d * 1.3)
        : cruiseSpeed;
    final desired = d > 1e-6 ? to * (speed / d) : Vector3.zero();
    final change = desired - b.velocity;
    final maxChange = steering * dt;
    if (change.length > maxChange) change.scale(maxChange / change.length);
    b.velocity.add(change);
    b.position.addScaled(b.velocity, dt);
    if (b.position.y < 0) b.position.y = 0;
    if (b.velocity.x * b.velocity.x + b.velocity.z * b.velocity.z > 0.01) {
      b.heading = math.atan2(b.velocity.x, b.velocity.z);
    }
    // Sube aleteando deprisa; arriba alterna aletear y planear.
    final climbing = b.velocity.y > 0.5;
    b.gliding =
        !climbing && cruise != null && math.sin(b.flapPhase * 0.18) > 0.3;
    b.flapPhase += dt * (climbing ? 30 : 20);
  }

  /// En el suelo: picotea o da un saltito cerca de su sitio en la bandada
  /// posada en [spot].
  void _idle(Bird b, Vector3 spot, double dt) {
    final from = b._hopFrom;
    final to = b._hopTo;
    if (from != null && to != null) {
      b._hopT = math.min(1, b._hopT + dt / 0.22);
      final p = from + (to - from) * b._hopT;
      b.position
        ..setFrom(p)
        ..y = 4 * b._hopT * (1 - b._hopT) * 0.1;
      if (b._hopT >= 1) {
        b
          .._hopFrom = null
          .._hopTo = null
          ..position.y = 0;
      }
      return;
    }
    if (b._peckTime > 0) {
      b._peckTime = math.max(0, b._peckTime - dt);
      b.peck = math.sin(b._peckTime / 0.35 * math.pi).abs();
      return;
    }
    b.idleTimer -= dt;
    if (b.idleTimer > 0) return;
    b.idleTimer = 0.4 + _random.nextDouble() * 1.2;
    if (_random.nextDouble() < 0.55) {
      b._peckTime = 0.35;
      return;
    }
    // Saltito de 0,25 m hacia un lado; si se aleja demasiado de la
    // bandada, hacia su sitio en ella.
    final home = b.position.clone()..y = 0;
    final a = _random.nextDouble() * 2 * math.pi;
    var next = home + Vector3(math.sin(a), 0, math.cos(a)) * 0.25;
    if (next.distanceTo(spot) > maxWander) {
      next = home + (spot + b.offset - home) * 0.5;
    }
    b
      .._hopFrom = home
      .._hopTo = next
      .._hopT = 0
      ..heading = math.atan2(next.x - home.x, next.z - home.z);
  }
}
