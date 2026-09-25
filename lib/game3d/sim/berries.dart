import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../../game/map/map_layout.dart';
import 'cell_noise.dart';
import 'reach.dart';
import 'world3d_events.dart';

/// Una bola de hojas del arbusto: centro y radios en una casilla "unidad"
/// (de -1 a 1 en X y Z; se escala a la mitad del tamaño de la casilla).
typedef LeafBall = ({
  double x,
  double y,
  double z,
  double rx,
  double ry,
  double rz,
});

/// FORMA del arbusto: tres bolas de hojas. La usan la malla (props) y el
/// cálculo de dónde cuelgan las bayas, así nunca quedan dentro de las hojas.
const bushLeafBalls = <LeafBall>[
  (x: 0, y: 0.45, z: 0, rx: 0.75, ry: 0.55, rz: 0.75),
  (x: 0.4, y: 0.4, z: 0.2, rx: 0.45, ry: 0.4, rz: 0.45),
  (x: -0.35, y: 0.35, z: -0.2, rx: 0.45, ry: 0.38, rz: 0.45),
];

/// Un arbusto con bayas del mapa (casilla `b`): cuántas le quedan, cuándo
/// le crece otra y si se está balanceando porque lo acaban de sacudir.
class BerryBush {
  BerryBush({required this.cell, required this.center, required this.slots})
    : berries = slots.length;

  final MapCell cell;

  /// Centro de su casilla, en el suelo.
  final Vector3 center;

  /// Dónde cuelga cada baya (posiciones del mundo). Las que hay ocupan los
  /// primeros huecos.
  final List<Vector3> slots;

  /// Bayas que le quedan colgando.
  int berries;

  /// Segundos acumulados para que crezca la siguiente.
  double growth = 0;

  /// Segundos desde que creció la última (para que "brote"); null = hecho.
  double? grownFor;

  /// Segundos desde que lo sacudieron (null = quieto).
  double? shakenFor;

  /// Hacia dónde lo empujaron (rad en el suelo, 0 = +Z, como `facing`).
  double shakeHeading = 0;

  bool get isShaking => shakenFor != null;

  /// Inclinación (rad) hacia [shakeHeading] ahora mismo: un vaivén rápido
  /// que se va apagando.
  double get sway {
    final t = shakenFor;
    if (t == null) return 0;
    final fade = 1 - t / BerrySystem.shakeDuration;
    return 0.18 * math.sin(t * 26) * fade * fade;
  }

  /// Tamaño (0..1) de la baya del hueco [i]: 0 si no está; la recién
  /// crecida aparece con un pequeño rebote.
  double berryScale(int i) {
    if (i >= berries) return 0;
    final t = grownFor;
    if (t == null || i != berries - 1) return 1;
    final s = math.min(1.0, t / BerrySystem.growPopTime) - 1;
    // "easeOutBack": crece hasta pasarse un poco (≈1,1) y vuelve a 1.
    const c = 1.70158;
    return 1 + (c + 1) * s * s * s + c * s * s;
  }
}

/// Una baya suelta: saltando de un arbusto o en el suelo (se recoge al
/// pasar por encima, como las Poké Balls).
class LooseBerry {
  LooseBerry({
    required this.id,
    required Vector3 position,
    required Vector3 velocity,
  }) : position = position.clone(),
       velocity = velocity.clone();

  final String id;
  final Vector3 position;
  final Vector3 velocity;

  /// Segundos desde que salió.
  double age = 0;

  /// Segundos que lleva quieta en el suelo (null = en el aire o botando).
  double? landedFor;

  /// Giro acumulado (rad) mientras vuela, para que ruede en el aire.
  double spin = 0;

  bool get landed => landedFor != null;

  /// Tamaño relativo para dibujarla: al final de su vida en el suelo se
  /// encoge hasta desaparecer.
  double get scale {
    final t = landedFor;
    if (t == null) return 1;
    final left = BerrySystem.groundLifetime - t;
    return (left / 0.5).clamp(0.0, 1.0);
  }
}

/// ARBUSTOS CON BAYAS (Dart puro): el jugador se pone delante de uno y lo
/// sacude; las bayas que tenga saltan y caen a sus pies, y se recogen al
/// pisarlas (van a la bolsa). Al arbusto le vuelven a crecer poco a poco.
class BerrySystem {
  BerrySystem({
    required this.bushes,
    required this.tileSize,
    required this.isWalkable,
    math.Random? random,
  }) : _random = random ?? math.Random();

  /// Todos los arbustos (`b`) de [layout], llenos de bayas.
  factory BerrySystem.fromLayout(
    MapLayout layout,
    double tileSize, {
    math.Random? random,
  }) => BerrySystem(
    bushes: [
      for (var row = 0; row < layout.rows; row++)
        for (var col = 0; col < layout.columns; col++)
          if (layout.tileAt(col, row) == TileKind.bush)
            BerryBush(
              cell: (col: col, row: row),
              center: cellCenterOf((col: col, row: row), tileSize),
              slots: slotsFor((col: col, row: row), tileSize),
            ),
    ],
    tileSize: tileSize,
    isWalkable: (p) =>
        layout.isWalkable((p.x / tileSize).floor(), (p.z / tileSize).floor()),
    random: random,
  );

  final List<BerryBush> bushes;
  final double tileSize;

  /// ¿Se puede pisar este punto? (las bayas no caen dentro de un arbusto
  /// ni de una valla).
  final bool Function(Vector3 p) isWalkable;

  final math.Random _random;
  final List<LooseBerry> _loose = [];
  int _count = 0;

  /// Bayas sueltas (saltando o en el suelo).
  List<LooseBerry> get loose => List.unmodifiable(_loose);

  /// Bayas que caben en un arbusto.
  static const maxBerries = 3;

  /// Segundos para que le crezca UNA baya a un arbusto que no está lleno.
  static const regrowSeconds = 40.0;

  /// Lo que tarda en "brotar" una baya nueva (animación).
  static const growPopTime = 0.35;

  /// Lo que dura el balanceo de una sacudida (no se puede volver a
  /// sacudir hasta que para).
  static const shakeDuration = 0.7;

  /// Se sacude desde esta distancia (m, al centro de su casilla), como los
  /// carteles: pegado a él y mirándolo.
  static const reach = 2.6;

  /// Radio de una baya (m).
  static const radius = 0.12;

  /// Lo que tarda una baya en caer desde el arbusto hasta el suelo (s).
  static const flightTime = 0.55;
  static const gravity = 9.8;

  /// Una baya en el suelo se recoge al pasar a menos de esto (m), pero
  /// solo cuando ya ha dejado de botar y lleva [settleTime] s quieta (así
  /// se ve caer antes de ir a la bolsa).
  static const pickupRadius = 1.1;
  static const settleTime = 0.25;

  /// Una baya que nadie recoge se pudre y desaparece (s en el suelo).
  static const groundLifetime = 120.0;

  /// Dónde cuelgan las bayas de un arbusto: repartidas alrededor (cada
  /// arbusto con su propio giro), a distintas alturas y justo por fuera de
  /// las hojas.
  static List<Vector3> slotsFor(MapCell cell, double tileSize) {
    final center = cellCenterOf(cell, tileSize);
    final unit = tileSize / 2;
    final turn = cellNoise(cell.col, cell.row, 5) * 2 * math.pi;
    return [
      for (var i = 0; i < maxBerries; i++)
        () {
          final a = turn + i * 2 * math.pi / maxBerries;
          final y = 0.5 + 0.13 * i;
          var r = 0.0;
          while (_insideLeaves(math.sin(a) * r, y, math.cos(a) * r)) {
            r += 0.01;
          }
          r += radius / unit * 0.35; // asoma algo más de la mitad
          return center + Vector3(math.sin(a) * r, y, math.cos(a) * r) * unit;
        }(),
    ];
  }

  static bool _insideLeaves(double x, double y, double z) {
    for (final b in bushLeafBalls) {
      final dx = (x - b.x) / b.rx;
      final dy = (y - b.y) / b.ry;
      final dz = (z - b.z) / b.rz;
      if (dx * dx + dy * dy + dz * dz < 1) return true;
    }
    return false;
  }

  /// El arbusto que el jugador en [player], mirando hacia [facing], tiene
  /// a mano para sacudirlo (null si ninguno).
  BerryBush? reachable(Vector3 player, double facing) {
    final cell = nearestInReach(
      bushes.map((b) => b.cell),
      player,
      facing,
      tileSize: tileSize,
      range: reach,
    );
    if (cell == null) return null;
    return bushes.firstWhere((b) => b.cell == cell);
  }

  /// Sacude [bush] desde [player]: se balancea y suelta TODAS sus bayas,
  /// que saltan y caen a los pies del jugador, repartidas. Devuelve
  /// cuántas soltó (0 si no le quedaba ninguna) o null si aún se estaba
  /// balanceando de la sacudida anterior.
  int? shake(BerryBush bush, Vector3 player) {
    if (bush.isShaking) return null;
    final toBush = bush.center - player
      ..y = 0;
    if (toBush.length2 < 1e-9) toBush.setValues(0, 0, -1);
    toBush.normalize();
    bush
      ..shakenFor = 0
      ..shakeHeading = math.atan2(toBush.x, toBush.z);
    final count = bush.berries;
    final right = Vector3(-toBush.z, 0, toBush.x);
    for (var i = 0; i < count; i++) {
      final from = bush.slots[i];
      // Caen entre el jugador y el arbusto, repartidas de lado a lado (el
      // bote final las acerca un poco más al jugador).
      final side = (i - (count - 1) / 2) * 0.45 + _jitter(0.08);
      var target = player + toBush * (0.75 + _jitter(0.1)) + right * side;
      // Nunca dentro del arbusto: se acercan al jugador hasta suelo libre.
      for (var step = 0; step < 10 && !isWalkable(target); step++) {
        target = target + (player - target) * 0.2;
      }
      _loose.add(
        LooseBerry(
          id: 'berry-${_count++}',
          position: from,
          velocity: Vector3(
            (target.x - from.x) / flightTime,
            (radius - from.y + 0.5 * gravity * flightTime * flightTime) /
                flightTime,
            (target.z - from.z) / flightTime,
          ),
        ),
      );
    }
    bush
      ..berries = 0
      ..growth = 0
      ..grownFor = null;
    return count;
  }

  double _jitter(double amount) => (_random.nextDouble() - 0.5) * 2 * amount;

  /// Avanza [dt] segundos: balanceo y crecimiento de los arbustos, bayas
  /// que caen y botan, y las que el jugador en [player] recoge (se cuentan
  /// con [emit]).
  void update(double dt, Vector3 player, void Function(World3DEvent) emit) {
    for (final bush in bushes) {
      _updateBush(bush, dt);
    }
    final flatPlayer = Vector3(player.x, 0, player.z);
    var picked = 0;
    for (final berry in _loose.toList()) {
      berry.age += dt;
      final landed = berry.landedFor;
      if (landed == null) {
        _fly(berry, dt);
        continue;
      }
      berry.landedFor = landed + dt;
      if (berry.landedFor! >= groundLifetime) {
        _loose.remove(berry);
        continue;
      }
      final flat = Vector3(berry.position.x, 0, berry.position.z);
      if (landed >= settleTime && flat.distanceTo(flatPlayer) < pickupRadius) {
        _loose.remove(berry);
        picked++;
      }
    }
    if (picked > 0) emit(BerriesPickedUp(picked));
  }

  void _updateBush(BerryBush bush, double dt) {
    final shaken = bush.shakenFor;
    if (shaken != null) {
      bush.shakenFor = shaken + dt >= shakeDuration ? null : shaken + dt;
    }
    final grown = bush.grownFor;
    if (grown != null) {
      bush.grownFor = grown + dt >= growPopTime ? null : grown + dt;
    }
    if (bush.berries >= maxBerries) {
      bush.growth = 0;
      return;
    }
    bush.growth += dt;
    if (bush.growth >= regrowSeconds) {
      bush
        ..growth = 0
        ..berries += 1
        ..grownFor = 0;
    }
  }

  /// Vuelo con gravedad; al tocar el suelo bota (cada vez menos) hasta
  /// quedarse quieta.
  void _fly(LooseBerry berry, double dt) {
    berry.velocity.y -= gravity * dt;
    berry.position.addScaled(berry.velocity, dt);
    berry.spin += dt * 9;
    if (berry.position.y > radius) return;
    berry.position.y = radius;
    if (berry.velocity.y < -1.2) {
      berry.velocity
        ..y = -berry.velocity.y * 0.35
        ..x *= 0.3
        ..z *= 0.3;
      return;
    }
    berry.velocity.setZero();
    berry.landedFor = 0;
  }
}
