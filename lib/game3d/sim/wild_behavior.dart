import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'wild_pokemon.dart';

/// Cuánto se deja notar el jugador ahora mismo (lo calcula la simulación
/// a partir de si está agachado, corriendo y dónde pisa).
enum PlayerStealth {
  /// Agachado en la hierba alta: casi invisible y silencioso.
  hidden,

  /// Agachado fuera de la hierba: se ve menos y apenas hace ruido.
  crouching,

  /// De pie, andando o quieto.
  normal,

  /// Corriendo: se le oye de lejos.
  noisy,
}

/// EL COMPORTAMIENTO de los Pokémon salvajes (Dart puro): qué perciben del
/// jugador (vista en cono y oído) y cómo reaccionan según su carácter:
///
///  - tranquilos: deambulan por la hierba alta; si sospechan ("?") se
///    paran y se giran hacia el ruido;
///  - al descubrirte ("!"): los asustadizos huyen (y, si se alejan mucho,
///    desaparecen), los curiosos se acercan a mirarte y los agresivos
///    cargan contra ti (si te alcanzan, empieza un encuentro).
///
/// No conoce el mapa: recibe funciones para saber qué se puede pisar.
class WildBehavior {
  WildBehavior({
    required this.random,
    required this.isWalkable,
    required this.isTallGrass,
    required this.nearbyGrass,
  });

  final math.Random random;

  /// ¿Se puede pisar este punto del suelo?
  final bool Function(Vector3 p) isWalkable;
  final bool Function(Vector3 p) isTallGrass;

  /// Un punto de hierba alta cerca de [p] (para pasear o volver a ella).
  final Vector3? Function(Vector3 p, int radiusCells) nearbyGrass;

  /// Distancia (m) a la que ve de pie, y medio ángulo de su cono de visión.
  static const sightRange = 13.0;
  static const sightHalfAngle = 1.05; // ≈ 60°

  /// Pegado a él, te nota aunque estés a su espalda.
  static const touchRange = 1.4;

  /// Segundos que sigue alerta tras perderte de vista y de oído.
  static const alertSeconds = 5.0;

  /// Los curiosos se quedan a esta distancia (m) mirándote.
  static const curiousDistance = 3.2;

  /// Un asustadizo que se aleja tanto (m) se pierde entre la hierba.
  static const fleeDespawnDistance = 24.0;

  /// Umbral de sospecha para enseñar "?" y pararse a mirar.
  static const suspiciousLevel = 0.35;

  /// Mientras come solo te oye si haces MUCHO ruido cerca: esta parte de
  /// lo que oiría normalmente. Y no te ve (salvo que lo toques).
  static const eatingHearing = 0.35;

  /// Se para a comer a esta distancia (m) de la baya.
  static const eatDistance = 0.5;

  /// Alcance de la vista según lo escondido que va el jugador.
  static double sightFor(PlayerStealth s) => switch (s) {
    PlayerStealth.hidden => sightRange * 0.2,
    PlayerStealth.crouching => sightRange * 0.6,
    PlayerStealth.normal || PlayerStealth.noisy => sightRange,
  };

  /// Hasta dónde se oye al jugador (0 = no hace ruido).
  static double noiseFor(PlayerStealth s, {required bool moving}) {
    if (!moving) return 0;
    return switch (s) {
      PlayerStealth.hidden => 1.2,
      PlayerStealth.crouching => 1.8,
      PlayerStealth.normal => 6,
      PlayerStealth.noisy => 14,
    };
  }

  /// ¿Ve [w] al jugador en [player]?
  static bool sees(WildPokemon w, Vector3 player, PlayerStealth stealth) {
    final to = player - w.position
      ..y = 0;
    final d = to.length;
    if (d < touchRange) return true;
    if (d > sightFor(stealth)) return false;
    return to.dot(w.facingDirection) / d > math.cos(sightHalfAngle);
  }

  /// Actualiza la sospecha de [w]. Devuelve true si ACABA de descubrir al
  /// jugador (pasa a alerta: "!").
  bool perceive(
    WildPokemon w, {
    required Vector3 player,
    required PlayerStealth stealth,
    required bool moving,
    required double dt,
  }) {
    final d = (Vector3(player.x, 0, player.z) - w.position).length;
    // Comiendo está distraído: no ve y casi no oye.
    final eating = w.isEating;
    final seen = eating ? d < touchRange : sees(w, player, stealth);
    final noise =
        noiseFor(stealth, moving: moving) * (eating ? eatingHearing : 1);
    final heard = d < noise;

    var gain = 0.0;
    if (seen) gain += 0.9 + 1.6 * (1 - d / sightRange).clamp(0.0, 1.0);
    if (heard) gain += 0.4 + 1.2 * (1 - d / noise);

    if (w.isAlert) {
      // Mientras te vea u oiga, sigue alerta.
      if (seen || heard) w.alertTime = math.max(w.alertTime, alertSeconds);
      w.awareness = 1;
      return false;
    }
    w.awareness = gain > 0
        ? math.min(1, w.awareness + gain * dt)
        : math.max(0, w.awareness - 0.2 * dt);
    if (w.awareness >= 1) {
      startle(w);
      return true;
    }
    return false;
  }

  /// Le da un susto (lo descubre de golpe): un ruido, una bola que cae al
  /// lado, que le toquen...
  void startle(WildPokemon w) {
    w
      ..awareness = 1
      ..alertTime = math.max(w.alertTime, alertSeconds)
      ..target = null;
  }

  /// Corre lejos de [player] a toda prisa, sea cual sea su carácter (se va
  /// para siempre). Si está justo encima, hacia donde mira. Devuelve true
  /// cuando ya está tan lejos que debe desaparecer.
  bool runAway(WildPokemon w, Vector3 player, double dt) {
    final away = w.position - player
      ..y = 0;
    final d = away.length;
    _move(w, d < 1e-3 ? w.facingDirection : away, WildPokemon.fleeSpeed, dt);
    return d > fleeDespawnDistance;
  }

  /// Mueve a [w] según su estado y carácter. Devuelve true si se ha
  /// alejado tanto huyendo que debe desaparecer.
  bool act(WildPokemon w, Vector3 player, double dt) {
    final to = player - w.position
      ..y = 0;
    final d = to.length;
    if (w.isAlert) {
      switch (w.temperament) {
        case Temperament.skittish:
          _move(w, -to, WildPokemon.fleeSpeed, dt);
          return d > fleeDespawnDistance;
        case Temperament.curious:
          if (d > curiousDistance) {
            _move(w, to, WildPokemon.wanderSpeed * 1.5, dt);
          } else {
            w.target = null;
            _turnTowards(w, to, dt);
          }
        case Temperament.aggressive:
          _move(w, to, WildPokemon.chargeSpeed, dt);
      }
      return false;
    }
    if (w.awareness > suspiciousLevel) {
      // "?": se para y se gira hacia ti, despacio.
      w.target = null;
      _turnTowards(w, to, dt, speed: 1.6);
      return false;
    }
    _wander(w, dt);
    return false;
  }

  /// Va hacia su baya ([WildPokemon.bait]) y, al llegar, se la come: quieto
  /// y mirándola, a mordiscos, durante [WildPokemon.eatSeconds]. Qué baya
  /// le toca y qué pasa al terminar lo decide la simulación.
  void feed(WildPokemon w, double dt) {
    final bait = w.bait;
    if (bait == null) return;
    final to = bait.position - w.position
      ..y = 0;
    final eating = w.eatingFor;
    if (eating != null) {
      w
        ..eatingFor = eating + dt
        ..target = null;
      bait.eaten = math.min(1, (eating + dt) / WildPokemon.eatSeconds);
      _turnTowards(w, to, dt);
      return;
    }
    w.baitTime += dt;
    if (to.length <= eatDistance) {
      w
        ..eatingFor = 0
        ..target = null;
      return;
    }
    _move(w, to, WildPokemon.baitSpeed, dt);
  }

  /// Anda hacia [dir] a [speed]. Si hay un obstáculo, prueba a desviarse
  /// cada vez más (como quien rodea un árbol).
  void _move(WildPokemon w, Vector3 dir, double speed, double dt) {
    if (dir.length2 < 1e-9) return;
    final base = math.atan2(dir.x, dir.z);
    for (final turn in const [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6]) {
      final a = base + turn;
      final step = Vector3(math.sin(a), 0, math.cos(a))..scale(speed * dt);
      final next = w.position + step;
      if (!isWalkable(next)) continue;
      w
        ..position = next
        ..distanceMoved += step.length
        ..facing = a
        // Un destino "de mentira" para que se vean los saltitos al moverse.
        ..target = next + step;
      return;
    }
    w.target = null; // acorralado
  }

  void _turnTowards(WildPokemon w, Vector3 dir, double dt, {double speed = 6}) {
    if (dir.length2 < 1e-9) return;
    final desired = math.atan2(dir.x, dir.z);
    var diff = (desired - w.facing) % (2 * math.pi);
    if (diff > math.pi) diff -= 2 * math.pi;
    final maxStep = speed * dt;
    w.facing += diff.abs() <= maxStep ? diff : maxStep * diff.sign;
  }

  /// Paseo tranquilo por la hierba alta. Si está fuera (tras huir), vuelve
  /// a ella por cualquier sitio pisable.
  void _wander(WildPokemon w, double dt) {
    final target = w.target;
    if (target == null) {
      w.idleTime -= dt;
      if (w.idleTime <= 0) {
        final inGrass = isTallGrass(w.position);
        w.target = nearbyGrass(w.position, inGrass ? 3 : 8);
        if (w.target == null) w.idleTime = 1;
      }
      return;
    }
    final toTarget = target - w.position
      ..y = 0;
    final dist = toTarget.length;
    if (dist < 0.1) {
      w
        ..target = null
        ..idleTime = 1 + random.nextDouble() * 2.5;
      return;
    }
    final step = math.min(dist, WildPokemon.wanderSpeed * dt);
    final next = w.position + toTarget.normalized() * step;
    // Dentro de la hierba no sale de ella; fuera, solo evita obstáculos.
    final allowed = isTallGrass(w.position)
        ? isTallGrass(next)
        : isWalkable(next);
    if (!allowed) {
      w
        ..target = null
        ..idleTime = 0.5;
      return;
    }
    w
      ..position = next
      ..distanceMoved += step
      ..facing = math.atan2(toTarget.x, toTarget.z);
  }
}
