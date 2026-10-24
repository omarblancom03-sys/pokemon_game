import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'trees.dart';
import 'wind.dart';

/// Una hoja que cae de un árbol: baja despacio balanceándose de lado a
/// lado como un péndulo (se ladea en cada extremo y cae más deprisa al
/// pasar por el centro), el viento la arrastra y gira poco a poco. En el
/// suelo se queda plana un rato y luego se encoge hasta desaparecer.
class FallingLeaf {
  FallingLeaf({
    required Vector3 start,
    required Vector3 push,
    required this.from,
    required this.yaw,
    required this.spin,
    required this.swingPhase,
    required this.swingFrequency,
    required this.swingWidth,
    required this.fallSpeed,
    required this.size,
    required this.shade,
  }) : _center = start.clone(),
       _push = push.clone(),
       position = start.clone() {
    // El centro del vaivén se pone de forma que la hoja SALGA de [start]
    // (si no, en el primer paso daría un salto de hasta [swingWidth]).
    final off = swingWidth * math.sin(swingPhase);
    _center
      ..x -= math.cos(yaw) * off
      ..z += math.sin(yaw) * off;
    tilt = FallingLeafSystem.maxTilt * math.sin(swingPhase);
  }

  /// Tipo de árbol del que cayó (da el color: naranja o verde).
  final TreeKind from;

  /// Rumbo de la hoja (rad, en el suelo): se balancea a lo largo de su
  /// eje X local.
  double yaw;

  /// Giro lento sobre sí misma mientras cae (rad/s).
  final double spin;

  /// Fase del balanceo (rad), cuántos vaivenes da por segundo y cuánto se
  /// aparta (m) a cada lado.
  double swingPhase;
  final double swingFrequency;
  final double swingWidth;

  /// Velocidad media de caída (m/s).
  final double fallSpeed;

  /// Largo de la hoja (m).
  final double size;

  /// 0 … 1: variación de color (unas más rojas o claras que otras).
  final double shade;

  /// Centro del vaivén (por donde caería sin balancearse) y empujón de
  /// salida (al sacudir un árbol salen despedidas; se frena enseguida).
  final Vector3 _center;
  final Vector3 _push;

  /// Dónde está (el centro más el balanceo).
  final Vector3 position;

  /// Ladeo (rad) sobre su eje Z local: máximo en los extremos del vaivén.
  double tilt = 0;

  /// Segundos desde que se soltó.
  double age = 0;

  /// Segundos que lleva en el suelo (null = aún cae).
  double? landedFor;

  bool get landed => landedFor != null;

  /// Tamaño relativo para dibujarla: entera hasta que, tras [restTime] s
  /// en el suelo, se encoge en [shrinkTime] s (se va sin transparencias).
  double get scale {
    final t = landedFor;
    if (t == null || t <= FallingLeafSystem.restTime) return 1;
    return math.max(
      0,
      1 - (t - FallingLeafSystem.restTime) / FallingLeafSystem.shrinkTime,
    );
  }

  bool get isDead =>
      (landedFor ?? 0) >=
          FallingLeafSystem.restTime + FallingLeafSystem.shrinkTime ||
      age >= FallingLeafSystem.maxAge;
}

/// HOJAS QUE CAEN (Dart puro, decorado): los árboles otoñales cercanos al
/// jugador sueltan hojas sin parar, muchas más cuando pasa una ráfaga de
/// viento (la misma ola que mece las copas: [Wind.gustAt]), y
/// cualquier árbol de hojas (no el pino) suelta un puñado si le da una
/// Poké Ball. Solo es estado; el renderer las dibuja.
class FallingLeafSystem {
  FallingLeafSystem(TreeField field, {math.Random? random})
    : _random = random ?? math.Random(),
      _autumn = [
        for (final t in field.trees)
          if (t.kind == TreeKind.autumn) t,
      ];

  final math.Random _random;

  /// Los árboles otoñales (los únicos que sueltan hojas solos).
  final List<Tree> _autumn;

  final List<FallingLeaf> _leaves = [];

  List<FallingLeaf> get leaves => List.unmodifiable(_leaves);

  /// Cuántas hojas se han soltado desde el principio.
  int get dropped => _dropped;
  int _dropped = 0;

  /// Nunca más de estas a la vez (el renderer reserva este número).
  static const maxLeaves = 72;

  /// Solo sueltan hojas los árboles a menos de esto del jugador (m): las
  /// de más lejos apenas se verían.
  static const activeRadius = 30.0;

  /// Hojas por segundo de un árbol otoñal: siempre alguna y muchas más
  /// en una ráfaga fuerte.
  static const calmRate = 0.12;
  static const gustRate = 1.1;

  /// Arrastre del viento (m/s): un poco siempre y más en las ráfagas.
  static const calmDrift = 0.25;
  static const gustDrift = 1.4;

  /// Altura a la que se posan (justo sobre el suelo).
  static const groundY = 0.02;

  /// Lo que se quedan en el suelo antes de encogerse (s) y lo que tardan
  /// en encogerse del todo.
  static const restTime = 3.5;
  static const shrinkTime = 0.6;

  /// Por si algo la dejara flotando: nunca dura más de esto (s).
  static const maxAge = 20.0;

  /// Largo de las hojas (m). Más grandes que las de verdad, a propósito
  /// (como las mariposas): de tamaño real serían motitas de 4 píxeles.
  static const minSize = 0.26;
  static const maxSize = 0.34;

  /// Ladeo máximo en los extremos del vaivén (rad).
  static const maxTilt = 0.7;

  /// Un golpe con la fuerza máxima ([TreeField.maxKnock]) suelta tantas
  /// hojas; uno flojo, al menos [minKnockLeaves].
  static const knockLeaves = 12;
  static const minKnockLeaves = 3;

  /// Suelta una hoja del BORDE de la copa de [tree] (por fuera y en su
  /// mitad de abajo: si saliera de dentro, la copa la taparía un buen
  /// rato), hacia el lado [angle] (rad; al azar si no se da) y con un
  /// empujón inicial [push].
  void _drop(Tree tree, {double? angle, Vector3? push}) {
    if (_leaves.length >= maxLeaves) _leaves.removeAt(0); // la más vieja
    _dropped++;
    final crown = tree.crown;
    final r = tree.crownRadius;
    final a = angle ?? _random.nextDouble() * 2 * math.pi;
    final d = r * (0.95 + 0.25 * _random.nextDouble());
    _leaves.add(
      FallingLeaf(
        start: Vector3(
          crown.x + math.sin(a) * d,
          crown.y - r * (0.2 + 0.7 * _random.nextDouble()),
          crown.z + math.cos(a) * d,
        ),
        push: push ?? Vector3.zero(),
        from: tree.kind,
        yaw: _random.nextDouble() * 2 * math.pi,
        spin:
            (0.3 + _random.nextDouble() * 0.6) * (_random.nextBool() ? 1 : -1),
        swingPhase: _random.nextDouble() * 2 * math.pi,
        swingFrequency: 0.45 + _random.nextDouble() * 0.3,
        swingWidth: 0.25 + _random.nextDouble() * 0.25,
        fallSpeed: 0.55 + _random.nextDouble() * 0.3,
        size: minSize + _random.nextDouble() * (maxSize - minSize),
        shade: _random.nextDouble(),
      ),
    );
  }

  /// [tree] se sacudió con fuerza [strength] (rad, ver [TreeField.knock]):
  /// suelta un puñado de hojas (más cuanto más fuerte) que salen hacia
  /// fuera y caen balanceándose. El pino no suelta nada.
  ///
  /// Devuelve cuántas soltó.
  int shake(Tree tree, double strength) {
    if (tree.kind.isPine || strength <= 0) return 0;
    final count = math.max(
      minKnockLeaves,
      (strength / TreeField.maxKnock * knockLeaves).round(),
    );
    for (var i = 0; i < count; i++) {
      final a = _random.nextDouble() * 2 * math.pi;
      final speed = 0.8 + _random.nextDouble() * 1.2;
      _drop(
        tree,
        angle: a,
        push: Vector3(
          math.sin(a) * speed,
          0.6 + _random.nextDouble() * 0.8,
          math.cos(a) * speed,
        ),
      );
    }
    return count;
  }

  /// Hojas por segundo que suelta un árbol otoñal con una ráfaga de fuerza
  /// [gust] (0 = calma … 1 = ráfaga fuerte).
  static double dropRate(double gust) => calmRate + gustRate * gust;

  /// Avanza [dt] segundos: los otoñales a menos de [activeRadius] m de
  /// [player] sueltan hojas según la ráfaga que les llega en [time]; las
  /// que caen se balancean, el viento las arrastra y, en el suelo, se
  /// quedan quietas hasta encogerse.
  void update(double dt, {required double time, required Vector3 player}) {
    for (final t in _autumn) {
      final dx = t.x - player.x;
      final dz = t.z - player.z;
      if (dx * dx + dz * dz > activeRadius * activeRadius) continue;
      final gust = Wind.gustAt(time, t.x, t.z);
      if (_random.nextDouble() < dropRate(gust) * dt) _drop(t);
    }

    final wind = Wind.direction;
    for (final leaf in _leaves) {
      leaf.age += dt;
      final landed = leaf.landedFor;
      if (landed != null) {
        leaf.landedFor = landed + dt;
        continue;
      }
      final gust = Wind.gustAt(time, leaf.position.x, leaf.position.z);
      final drift = calmDrift + gustDrift * gust;
      leaf
        ..swingPhase += 2 * math.pi * leaf.swingFrequency * dt
        ..yaw += leaf.spin * dt;
      final s = math.sin(leaf.swingPhase);
      // Como un péndulo: más deprisa al pasar por el centro del vaivén.
      final fall =
          leaf.fallSpeed * (0.45 + 0.85 * math.cos(leaf.swingPhase).abs());
      leaf._center
        ..x += (wind.x * drift + leaf._push.x) * dt
        ..y += (leaf._push.y - fall) * dt
        ..z += (wind.z * drift + leaf._push.z) * dt;
      leaf._push.scale(math.exp(-3 * dt));
      // Se aparta a lo largo de su eje X local (rotado con su rumbo).
      final off = leaf.swingWidth * s;
      leaf.position.setValues(
        leaf._center.x + math.cos(leaf.yaw) * off,
        leaf._center.y,
        leaf._center.z - math.sin(leaf.yaw) * off,
      );
      leaf.tilt = maxTilt * s;
      if (leaf.position.y <= groundY) {
        leaf
          ..position.y = groundY
          ..tilt = 0
          ..landedFor = 0;
      }
    }
    _leaves.removeWhere((l) => l.isDead);
  }
}
