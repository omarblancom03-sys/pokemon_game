import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../../game/map/map_layout.dart';
import '../../models/poke_ball.dart';
import 'world3d_events.dart';

/// Algo que se puede recoger del suelo: un puñado de Poké Balls.
class GroundItem {
  GroundItem({
    required this.id,
    required this.ball,
    required this.count,
    required Vector3 position,
    this.dropped = false,
  }) : position = position.clone();

  final String id;
  final PokeBallType ball;
  final int count;
  final Vector3 position;

  /// true si es una bola lanzada que falló (no cuenta para reaparecer).
  final bool dropped;

  /// Segundos desde que apareció (brillo y rebote visual).
  double age = 0;
}

/// LAS POKÉ BALLS DEL CAMPO: siempre hay unas cuantas repartidas por el
/// mapa para ir recogiéndolas (brillan para verlas de lejos). Al recoger
/// una, pasado un rato aparece otra en otro sitio. Las bolas lanzadas que
/// fallan también se quedan aquí hasta que el jugador las recoge.
class FieldItems {
  FieldItems({
    required this.layout,
    required this.tileSize,
    required this._random,
    this.maxItems = 6,
  }) : _cells = [
         for (final cell in layout.walkableCells)
           if (_canHoldItems(layout.tileAt(cell.col, cell.row)!)) cell,
       ];

  final MapLayout layout;
  final double tileSize;

  /// Cuántos puñados "del campo" hay a la vez (sin contar los fallados).
  final int maxItems;

  final math.Random _random;
  final List<({int col, int row})> _cells;
  final List<GroundItem> _items = [];
  double _respawnTimer = respawnSeconds;
  int _count = 0;

  /// Lo que hay ahora en el suelo.
  List<GroundItem> get items => List.unmodifiable(_items);

  /// Distancia (m) a la que el jugador recoge algo al pasar.
  static const pickupRadius = 1.1;

  /// Segundos hasta que aparece un puñado nuevo cuando faltan.
  static const respawnSeconds = 12.0;

  /// Nunca aparecen tan cerca del jugador (m): se verían "brotar".
  static const minPlayerDistance = 8.0;

  /// Separación mínima entre puñados (m), para repartirlos por el mapa.
  static const minSpacing = 6.0;

  /// En los caminos y el empedrado no: así invitan a explorar.
  static bool _canHoldItems(TileKind kind) =>
      kind != TileKind.path && kind != TileKind.stone;

  int get _fieldCount => _items.where((i) => !i.dropped).length;

  /// Llena el campo hasta el máximo (al empezar la partida).
  void fill(Vector3 player) {
    while (_fieldCount < maxItems) {
      if (spawnOne(player) == null) return;
    }
  }

  /// Qué contiene un puñado nuevo: casi siempre Poké Balls; a veces Super
  /// Balls y, rara vez, una Ultra Ball.
  static ({PokeBallType ball, int count}) lootFor(double roll, double extra) {
    if (roll < 0.62) {
      return (ball: PokeBallType.poke, count: extra < 0.5 ? 2 : 3);
    }
    if (roll < 0.9) {
      return (ball: PokeBallType.great, count: extra < 0.6 ? 1 : 2);
    }
    return (ball: PokeBallType.ultra, count: 1);
  }

  /// Coloca un puñado al azar lejos del jugador y de los demás. Devuelve
  /// null si no queda sitio.
  GroundItem? spawnOne(Vector3 player) {
    final spots =
        [
          for (final c in _cells)
            Vector3((c.col + 0.5) * tileSize, 0, (c.row + 0.5) * tileSize),
        ]..removeWhere(
          (p) =>
              p.distanceTo(player) < minPlayerDistance ||
              _items.any((i) => i.position.distanceTo(p) < minSpacing),
        );
    if (spots.isEmpty) return null;
    final spot = spots[_random.nextInt(spots.length)];
    final loot = lootFor(_random.nextDouble(), _random.nextDouble());
    final item = GroundItem(
      id: 'item-${_count++}',
      ball: loot.ball,
      count: loot.count,
      position: spot,
    );
    _items.add(item);
    return item;
  }

  /// Deja en el suelo una bola lanzada que no dio a nadie.
  GroundItem drop(PokeBallType ball, Vector3 at) {
    final item = GroundItem(
      id: 'item-${_count++}',
      ball: ball,
      count: 1,
      position: Vector3(at.x, 0, at.z),
      dropped: true,
    );
    _items.add(item);
    return item;
  }

  /// Avanza [dt] segundos: recoge lo que el jugador pisa y repone el
  /// campo poco a poco.
  void update(double dt, Vector3 player, void Function(World3DEvent) emit) {
    for (final item in _items) {
      item.age += dt;
    }
    final flatPlayer = Vector3(player.x, 0, player.z);
    final picked = _items
        .where((i) => i.position.distanceTo(flatPlayer) < pickupRadius)
        .toList();
    for (final item in picked) {
      _items.remove(item);
      emit(BallsPickedUp(item.ball, item.count));
    }

    if (_fieldCount >= maxItems) {
      _respawnTimer = respawnSeconds;
      return;
    }
    _respawnTimer -= dt;
    if (_respawnTimer <= 0) {
      _respawnTimer = respawnSeconds;
      spawnOne(player);
    }
  }
}
