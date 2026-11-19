// PRUEBAS de los VILANOS: siempre hay [SeedDrift.maxSeeds] flotando cerca
// del jugador, el viento los arrastra (más en ráfaga), aparecen y se van
// encogiendo, se quitan si quedan lejos, y al pasar corriendo entre ellos
// salen despedidos hacia arriba (caminando, no).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game3d/sim/seeds.dart';
import 'package:pokemon_game/game3d/sim/wind.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  SeedDrift drift() => SeedDrift(random: Random(3));

  /// Un instante con ráfaga fuerte ([strong]) o calma en el origen.
  double timeWith({required bool strong}) {
    for (var t = 0.0; t < 120; t += 0.05) {
      final g = Wind.gustAt(t, 0, 0);
      if (strong ? g > 0.8 : g < 0.05) return t;
    }
    throw StateError('no gust found');
  }

  test('siempre hay maxSeeds flotando a la distancia y altura previstas', () {
    final s = drift()..update(0.016, time: 0, player: Vector3.zero());
    expect(s.seeds, hasLength(SeedDrift.maxSeeds));
    for (final seed in s.seeds) {
      final d = Vector2(seed.position.x, seed.position.z).length;
      expect(d, inInclusiveRange(SeedDrift.nearest, SeedDrift.farthest));
      expect(
        seed.position.y,
        inInclusiveRange(SeedDrift.minHeight, SeedDrift.maxHeight),
      );
    }
  });

  test('aparecen pequeños, crecen y desaparecen al acabar su vida', () {
    final seed = FloatingSeed(
      position: Vector3.zero(),
      life: 10,
      phase: 0,
      spin: 1,
    );
    expect(seed.scale, 0);
    seed.age = 0.5;
    expect(seed.scale, closeTo(0.5, 1e-9));
    seed.age = 5;
    expect(seed.scale, 1);
    seed.age = 9.5;
    expect(seed.scale, closeTo(0.5, 1e-9));
    seed.age = 10;
    expect(seed.isDead, isTrue);
  });

  test('el viento los arrastra, y más deprisa en ráfaga', () {
    double travelled(double time) {
      final s = drift()..update(0.016, time: time, player: Vector3.zero());
      final seed = s.seeds.first;
      final start = seed.position.clone();
      for (var i = 0; i < 30; i++) {
        s.update(0.016, time: time, player: Vector3.zero());
      }
      final moved = seed.position - start
        ..y = 0;
      // Va en la dirección del viento.
      expect(moved.dot(Wind.direction), greaterThan(0));
      return moved.length;
    }

    final calm = travelled(timeWith(strong: false));
    final gust = travelled(timeWith(strong: true));
    expect(gust, greaterThan(calm * 2));
  });

  test('si el jugador se aleja, los lejanos se quitan y salen otros', () {
    final s = drift()..update(0.016, time: 0, player: Vector3.zero());
    final far = Vector3(100, 0, 0);
    s.update(0.016, time: 0, player: far);
    expect(s.seeds, hasLength(SeedDrift.maxSeeds));
    for (final seed in s.seeds) {
      final d = Vector2(seed.position.x - far.x, seed.position.z).length;
      expect(d, lessThanOrEqualTo(SeedDrift.range));
    }
  });

  group('al pasar entre ellos', () {
    /// Altura que gana el vilano más cercano en medio segundo.
    double rise({required bool running}) {
      final s = drift()..update(0.016, time: 0, player: Vector3.zero());
      final seed = s.seeds.first;
      final player = Vector3(
        seed.position.x + 0.5,
        seed.position.y - SeedDrift.chestHeight,
        seed.position.z,
      );
      final y0 = seed.position.y;
      for (var i = 0; i < 30; i++) {
        s.update(0.016, time: 0, player: player, running: running);
      }
      return seed.position.y - y0;
    }

    test('corriendo, salen despedidos hacia arriba', () {
      expect(rise(running: true), greaterThan(rise(running: false) + 0.2));
    });
  });
}
