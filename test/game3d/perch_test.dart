// PRUEBAS de los POKÉMON EN LOS ÁRBOLES: algunos aparecen escondidos en la
// copa de un árbol de hojas del mapa (nunca en un pino ni en el bosque del
// borde): no se ven ni se pueden fijar, y la copa se agita a ratos y suelta
// hojas (se oye si estás cerca). Una bola contra el árbol o una voltereta
// contra el tronco lo hace caer, del lado del jugador y de espaldas a él, y
// queda aturdido: la ocasión de capturarlo. Si nadie lo tira, se va.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/capture/capture_calculator.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

void main() {
  // Borde de pinos (no sirven) y UN árbol redondo a 22 m del inicio.
  final grove = MapLayout.parse(const [
    'PPPPPPPPPPPPPPPP',
    'P..............P',
    'P.@..........T.P',
    'P..............P',
    'P..""""""""""..P',
    'PPPPPPPPPPPPPPPP',
  ]);

  World3DSim sim({List<World3DEvent>? events, MapLayout? layout}) => World3DSim(
    layout: layout ?? grove,
    maxFieldItems: 0,
    calculator: CaptureCalculator(random: Random(1)),
    onEvent: events?.add,
  );

  void step(World3DSim s, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60);
    }
  }

  /// Pone al jugador a 8 m del árbol, mirándolo (hacia +X).
  void faceTheTree(World3DSim s) {
    s.player.teleport(Vector3(19, 0, 5));
    s.camera.yaw = -pi / 2;
  }

  group('where they hide', () {
    test('in a leafy tree of the map: hidden, not targetable, no grass '
        'rustling', () {
      final s = sim();
      expect(s.perchTrees.map((t) => (t.col, t.row)), [(13, 2)]);
      final w = s.spawn(fakePokemon(1), perch: true)!;
      expect(w.isPerched, isTrue);
      expect(w.hidden, isTrue);
      expect(w.asleep, isFalse);
      expect(w.perch!.kind, TreeKind.round);
      expect(w.position, Vector3(27, 0, 5));
      expect(s.grassRustlers, isEmpty);
      expect(s.visibleWildNearby, isEmpty);
      // Un árbol, un Pokémon: el segundo va a la hierba como siempre.
      final other = s.spawn(fakePokemon(2), perch: true)!;
      expect(other.isPerched, isFalse);
      expect(s.isTallGrass(other.position), isTrue);
    });

    test('without a free leafy tree, it goes to the grass as always', () {
      final s = sim(
        layout: MapLayout.parse(const [
          'PPPPPPPPPPPPPPPP',
          'P.@............P',
          'P..""""""""""..P',
          'PPPPPPPPPPPPPPPP',
        ]),
      );
      expect(s.perchTrees, isEmpty);
      final w = s.spawn(fakePokemon(1), perch: true)!;
      expect(w.isPerched, isFalse);
      expect(w.hidden, isFalse);
    });

    test(
      'the spawner puts some in trees (and none if perchChance is 0)',
      () async {
        Future<List<WildPokemon>> spawned(double chance) async {
          var n = 0;
          final s =
              World3DSim(
                  layout: grove,
                  random: Random(5),
                  maxFieldItems: 0,
                  spawnWild: () async =>
                      (pokemon: fakePokemon(++n), captureRate: 45),
                )
                ..perchChance = chance
                ..herdChance = 0;
          for (var i = 0; i < 20 && s.wild.length < World3DSim.maxWild; i++) {
            step(s, 1);
            await pumpEventQueue();
          }
          return s.wild;
        }

        expect(World3DSim.defaultPerchChance, 0.15);
        expect((await spawned(1)).where((w) => w.isPerched), hasLength(1));
        expect((await spawned(0)).any((w) => w.isPerched), isFalse);
      },
    );
  });

  group('up in the tree', () {
    test('the canopy rustles now and then and drops leaves; it is heard '
        'only from nearby', () {
      final events = <World3DEvent>[];
      final s = sim(events: events);
      final w = s.spawn(fakePokemon(1), perch: true)!;
      // Lejos (22 m): se agita y caen hojas, pero no se oye.
      step(s, 20);
      expect(s.fallingLeaves.dropped, greaterThan(0));
      expect(events.whereType<TreeRustled>(), isEmpty);
      expect(w.isPerched, isTrue);
      // Cerca (5 m): el doble de a menudo, y se oye.
      s.player.teleport(Vector3(22, 0, 5));
      step(s, 20);
      final heard = events.whereType<TreeRustled>().toList();
      expect(heard.length, greaterThanOrEqualTo(6));
      for (final e in heard) {
        expect(e.tree, w.perch);
        expect(e.loudness, inExclusiveRange(0, 1));
      }
    });

    test('a ball landing nearby does not bring it down (it only rustles)', () {
      final s = sim();
      final w = s.spawn(fakePokemon(1), perch: true)!;
      faceTheTree(s);
      s.camera.yaw = -pi / 2 + 0.35; // de lado: no da en el árbol, cae cerca
      s.throwBall(PokeBallType.poke);
      step(s, 3);
      expect(w.isPerched, isTrue);
    });

    test('if nobody knocks it down, it leaves', () {
      final s = sim();
      final w = s.spawn(fakePokemon(1), perch: true)!;
      step(s, World3DSim.perchLifetime - 1);
      expect(s.wild, contains(w));
      step(s, 2);
      expect(s.wild, isNot(contains(w)));
    });
  });

  group('knocked down', () {
    test('a ball against the tree brings it down: dazed, on your side and '
        'with its back to you', () {
      final events = <World3DEvent>[];
      final s = sim(events: events);
      final w = s.spawn(fakePokemon(1), perch: true)!;
      final tree = w.perch!;
      faceTheTree(s);
      s.throwBall(PokeBallType.poke);
      step(s, 2);
      expect(events.whereType<PokemonFellFromTree>().single.wild, w);
      expect(events.whereType<BallHit>(), isEmpty, reason: 'hit the tree');
      expect(w.isPerched, isFalse);
      expect(w.hidden, isFalse);
      // Cae fuera del tronco, del lado del jugador, en suelo pisable.
      final base = Vector3(tree.x, 0, tree.z);
      expect(
        w.position.distanceTo(base),
        closeTo(World3DSim.fallDistance, 1e-6),
      );
      expect(w.position.x, lessThan(tree.x));
      final c = s.cellAt(w.position);
      expect(grove.isWalkable(c.col, c.row), isTrue);
      // Aturdido (sin enterarse de nada) y de espaldas al jugador.
      expect(w.isFalling, isFalse);
      expect(w.isDazed, isTrue);
      expect(w.dazeLength, WildPokemon.fallDazeSeconds);
      expect(w.isAlert, isFalse);
      expect(w.awareness, 0);
      final toPlayer = s.player.position - w.position
        ..y = 0;
      expect(w.facingDirection.dot(toPlayer.normalized()), lessThan(-0.9));
      // Y ya se ve: se le puede apuntar.
      expect(s.visibleWildNearby, contains(w));
      // Se le pasa a los 3,5 s.
      step(s, WildPokemon.fallDazeSeconds);
      expect(w.isDazed, isFalse);
    });

    test('it falls from the canopy height to the ground', () {
      final s = sim();
      final w = s.spawn(fakePokemon(1), perch: true)!;
      faceTheTree(s);
      s.throwBall(PokeBallType.poke);
      var highest = 0.0;
      var fell = false;
      for (var t = 0.0; t < 1.5; t += 1 / 60) {
        s.update(1 / 60);
        if (w.isFalling) {
          fell = true;
          highest = max(highest, w.fallHeight);
        }
      }
      expect(fell, isTrue);
      expect(highest, greaterThan(1));
      expect(w.fallHeight, 0);
    });

    test('rolling into the trunk also brings it down', () {
      final events = <World3DEvent>[];
      final s = sim(events: events);
      final w = s.spawn(fakePokemon(1), perch: true)!;
      // Junto al árbol, rodando hacia él (+X).
      s.player.teleport(Vector3(24.5, 0, 5));
      s.camera.yaw = -pi / 2;
      s.input.setKeyboardDirection(Vector2.zero());
      s.player.facing = pi / 2;
      expect(s.roll(), isTrue);
      step(s, 0.6);
      expect(events.whereType<TreeShaken>(), hasLength(1));
      expect(events.whereType<PokemonFellFromTree>(), hasLength(1));
      expect(w.isPerched, isFalse);
    });
  });
}
