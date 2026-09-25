// PRUEBAS de los pájaros: empiezan posados en campo abierto y lejos del
// jugador; picotean y saltan sin alejarse de su bandada; si te acercas
// salen volando TODOS (desde más lejos corriendo, agachado te acercas
// mucho), suben, se alejan y se posan en otro sitio lejos de ti; una Poké
// Ball que cae cerca también los espanta; las alas van plegadas en el
// suelo y aletean en el aire; y en pausa no se mueven.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/mesh/bird_mesh.dart';
import 'package:pokemon_game/game3d/mesh/mesh_builder.dart';
import 'package:pokemon_game/game3d/sim/birds.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  // Pradera grande con un poco de hierba alta y árboles sueltos.
  final layout = MapLayout.parse([
    'T' * 30,
    for (var i = 0; i < 16; i++)
      'T${i == 8 ? '@' : '.'}${i == 3 ? '"' * 6 : '.' * 6}'
          '${i == 10 ? 'T' : '.'}${'.' * 20}T',
    'T' * 30,
  ]);
  const tile = 2.0;

  BirdSystem system({Vector3? player, int seed = 1}) => BirdSystem.fromLayout(
    layout,
    tile,
    player: player ?? Vector3(3, 0, 17),
    random: Random(seed),
  );

  /// El pájaro está en una casilla abierta (ni hierba alta ni árbol).
  bool onOpenGround(Vector3 p) {
    final col = (p.x / tile).floor();
    final row = (p.z / tile).floor();
    return layout.isWalkable(col, row) &&
        layout.tileAt(col, row) != TileKind.tallGrass;
  }

  void run(
    BirdSystem s,
    Vector3 player,
    double seconds, {
    PlayerStealth stealth = PlayerStealth.normal,
    bool moving = true,
  }) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60, player, stealth: stealth, moving: moving);
    }
  }

  test('they start on open ground, together and away from the player', () {
    final s = system();
    expect(s.flocks, hasLength(2));
    for (final flock in s.flocks) {
      expect(flock.birds, hasLength(5));
      expect(flock.spot.distanceTo(Vector3(3, 0, 17)), greaterThan(15));
      for (final b in flock.birds) {
        expect(b.flying, isFalse);
        expect(onOpenGround(b.position), isTrue);
        expect(b.position.distanceTo(flock.spot), lessThan(1.2));
      }
    }
  });

  test('on the ground they peck and hop, but stay with their flock', () {
    final s = system();
    final far = Vector3(-100, 0, -100); // nadie cerca
    var pecked = false;
    var hopped = false;
    final start = [for (final b in s.birds) b.position.clone()];
    for (var t = 0.0; t < 20; t += 1 / 60) {
      s.update(1 / 60, far, stealth: PlayerStealth.normal, moving: false);
      for (final flock in s.flocks) {
        for (final b in flock.birds) {
          pecked |= b.peck > 0.5;
          expect(b.flying, isFalse);
          expect(
            (b.position.clone()..y = 0).distanceTo(flock.spot),
            lessThanOrEqualTo(BirdSystem.maxWander + 0.3),
          );
          expect(b.position.y, lessThan(0.15));
        }
      }
    }
    final moved = s.birds.toList();
    for (var i = 0; i < moved.length; i++) {
      hopped |= moved[i].position.distanceTo(start[i]) > 0.1;
    }
    expect(pecked, isTrue);
    expect(hopped, isTrue);
  });

  test('walking up scares the whole flock: up, away, and down far off', () {
    final s = system();
    final flock = s.flocks.first;
    final oldSpot = flock.spot.clone();
    // El jugador aparece a 4 m (andando se espantan a 5 m).
    final player = oldSpot + Vector3(4, 0, 0);
    s.update(1 / 60, player, stealth: PlayerStealth.normal, moving: true);
    expect(flock.flying, isTrue);
    run(s, player, 0.5, moving: false);
    expect(flock.birds.every((b) => b.flying), isTrue);

    var maxHeight = 0.0;
    var guard = 0;
    while (flock.flying) {
      s.update(1 / 60, player, stealth: PlayerStealth.normal, moving: false);
      for (final b in flock.birds) {
        maxHeight = max(maxHeight, b.position.y);
        if (b.flying) {
          expect(b.wingAngle, greaterThan(-0.5), reason: 'open in flight');
        }
      }
      expect(++guard, lessThan(60 * 30), reason: 'lands within 30 s');
    }
    expect(maxHeight, greaterThan(BirdSystem.cruiseHeight * 0.7));
    expect(
      flock.spot.distanceTo(player),
      greaterThan(BirdSystem.landFarFromPlayer),
    );
    for (final b in flock.birds) {
      expect(b.position.y, 0);
      expect(onOpenGround(b.position), isTrue);
      expect(b.wingAngle, lessThan(-1), reason: 'wings folded');
    }
  });

  test('running scares them from further; crouched you get close', () {
    double d(PlayerStealth s) => BirdSystem.scareDistance(s, moving: true);
    expect(d(PlayerStealth.noisy), greaterThan(d(PlayerStealth.normal)));
    expect(d(PlayerStealth.normal), greaterThan(d(PlayerStealth.crouching)));
    expect(
      BirdSystem.scareDistance(PlayerStealth.noisy, moving: false),
      lessThan(d(PlayerStealth.crouching)),
    );

    final s = system();
    final flock = s.flocks.first;
    final player = flock.spot + Vector3(3.5, 0, 0);
    run(s, player, 1, stealth: PlayerStealth.crouching);
    expect(flock.flying, isFalse, reason: 'crouched at 3.5 m');
    s.update(1 / 60, player, stealth: PlayerStealth.noisy, moving: true);
    expect(flock.flying, isTrue, reason: 'running at 3.5 m');
  });

  test('a ball landing close by scares them; far away it does not', () {
    final s = system();
    final flock = s.flocks.first;
    final player = Vector3(3, 0, 17);
    s.startle(flock.spot + Vector3(12, 0, 0), player);
    expect(flock.flying, isFalse);
    s.startle(flock.spot + Vector3(3, 0, 0), player);
    expect(flock.flying, isTrue);
  });

  test('the bird body stands on its feet with the beak towards +Z', () {
    final body = buildBirdBody();
    var minY = double.infinity;
    var maxZ = -double.infinity;
    for (var i = 0; i < body.vertexCount; i++) {
      minY = min(minY, body.positions[i * 3 + 1]);
      maxZ = max(maxZ, body.positions[i * 3 + 2]);
    }
    expect(minY, closeTo(0.09 - 0.052, 0.01));
    expect(maxZ, greaterThan(0.13), reason: 'beak sticks out in front');
    final right = buildBirdWing();
    final left = buildBirdWing(left: true);
    double maxX(MeshBuffers m) {
      var r = -double.infinity;
      for (var i = 0; i < m.vertexCount; i++) {
        r = max(r, m.positions[i * 3]);
      }
      return r;
    }

    expect(maxX(right), greaterThan(0.15));
    expect(maxX(left), lessThanOrEqualTo(1e-6));
  });

  group('in the world', () {
    World3DSim world() =>
        World3DSim(layout: layout, random: Random(2), maxFieldItems: 0);

    test('they are there and freeze with the world', () {
      final s = world();
      expect(s.birds.birds, isNotEmpty);
      final b = s.birds.flocks.first.birds.first;
      // Espantarlos y congelar el mundo en pleno vuelo.
      s.birds.startle(b.position, s.player.position);
      for (var i = 0; i < 60; i++) {
        s.update(1 / 60);
      }
      expect(b.flying, isTrue);
      s.setPaused(true);
      final frozen = b.position.clone();
      s.update(1);
      expect(b.position, frozen);
    });

    test('a thrown ball landing next to them scares them', () {
      final s = world();
      final flock = s.birds.flocks.first;
      s.ballSystem.launch(
        PokeBallType.poke,
        flock.spot + Vector3(1.5, 2, 0),
        Vector3(0, -2, 0),
      );
      for (var i = 0; i < 90; i++) {
        s.update(1 / 60);
      }
      expect(flock.flying, isTrue);
    });
  });
}
