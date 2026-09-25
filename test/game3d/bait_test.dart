// PRUEBAS de las BAYAS PARA DISTRAER: un Pokémon tranquilo huele una baya
// del suelo, va a por ella y se la come (avisa al empezar); nadie más va a
// por la misma y el jugador ya no la recoge; mientras come no te ve y casi
// no te oye; si te descubre la deja (a medio comer) para otro; una baya que
// cae junto a un escondido lo hace asomarse; a uno que sospechaba se le
// olvida; si no llega, se rinde; y capturarlo mientras come es más fácil.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/capture/capture_calculator.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/wild_behavior.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

void main() {
  // Pradera abierta de 30 x 9 casillas (casillas de 2 m).
  final layout = MapLayout.parse([
    'T' * 30,
    for (var row = 1; row < 8; row++)
      row == 4 ? 'T..@${'.' * 25}T' : 'T${'.' * 28}T',
    'T' * 30,
  ]);

  World3DSim world({List<World3DEvent>? events}) {
    final s = World3DSim(
      layout: layout,
      random: Random(8),
      maxFieldItems: 0,
      onEvent: events?.add,
    );
    s.player.teleport(s.cellCenter(3, 4));
    return s;
  }

  void step(World3DSim s, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60);
    }
  }

  /// Un Pokémon tranquilo en [at] mirando hacia +X (de espaldas al jugador).
  WildPokemon addWild(World3DSim s, Vector3 at, {String id = 'w'}) {
    final w = WildPokemon(
      id: id,
      pokemon: fakePokemon(25),
      position: at,
      temperament: Temperament.skittish,
      facing: pi / 2,
    )..idleTime = 1e9; // no pasea por su cuenta
    s.wild.add(w);
    return w;
  }

  /// Deja caer una baya en [at] (se posa en el siguiente paso).
  LooseBerry dropBerry(World3DSim s, Vector3 at) =>
      s.berries.throwBerry(Vector3(at.x, 0.13, at.z), Vector3.zero());

  test('a calm Pokémon smells a berry, goes to it and eats it', () {
    final events = <World3DEvent>[];
    final s = world(events: events);
    final w = addWild(s, s.cellCenter(14, 4));
    final berry = dropBerry(s, w.position + Vector3(3, 0, 0));

    step(s, 0.1);
    expect(w.bait, same(berry));
    expect(berry.claimedBy, w.id);

    step(s, 2);
    expect(w.isEating, isTrue);
    expect(events.whereType<PokemonEating>().single.wild, same(w));
    final flat = berry.position - w.position
      ..y = 0;
    expect(flat.length, lessThanOrEqualTo(WildBehavior.eatDistance + 0.05));

    step(s, WildPokemon.eatSeconds / 2);
    expect(berry.eaten, inInclusiveRange(0.3, 0.9), reason: 'bite by bite');
    expect(berry.scale, lessThan(1));

    step(s, WildPokemon.eatSeconds / 2 + 0.2);
    expect(s.berries.loose, isEmpty);
    expect(w.isEating, isFalse);
    expect(w.bait, isNull);
  });

  test('too far away, it does not smell it', () {
    final s = world();
    final w = addWild(s, s.cellCenter(14, 4));
    dropBerry(s, w.position + Vector3(World3DSim.baitRange + 1, 0, 0));
    step(s, 0.5);
    expect(w.bait, isNull);
  });

  test('berries right next to the player are not for Pokémon (the ones a '
      'bush drops at your feet are yours)', () {
    final s = world();
    final w = addWild(s, s.player.position + Vector3(8, 0, 0));
    dropBerry(s, s.player.position + Vector3(1, 0, 0));
    step(s, 0.1);
    expect(w.bait, isNull);
  });

  test('one berry, one Pokémon; a claimed berry is not picked up', () {
    final events = <World3DEvent>[];
    final s = world(events: events);
    final a = addWild(s, s.cellCenter(14, 3), id: 'a');
    final b = addWild(s, s.cellCenter(14, 5), id: 'b');
    final berry = dropBerry(s, s.cellCenter(16, 4));
    step(s, 0.1);
    expect([a.bait, b.bait].where((x) => x != null), [same(berry)]);

    // El jugador pasa por encima: esa baya ya es de alguien.
    s.berries.update(
      1 / 60,
      Vector3(berry.position.x, 0, berry.position.z),
      events.add,
    );
    expect(events.whereType<BerriesPickedUp>(), isEmpty);
    expect(s.berries.loose, [same(berry)]);
  });

  group('while eating', () {
    WildBehavior behavior() => WildBehavior(
      random: Random(1),
      isWalkable: (_) => true,
      isTallGrass: (_) => false,
      nearbyGrass: (_, _) => null,
    );

    /// Pokémon en el origen mirando hacia +X; el jugador delante, a [d] m.
    double awarenessAfter({
      required bool eating,
      required double d,
      PlayerStealth stealth = PlayerStealth.normal,
      bool moving = false,
    }) {
      final w = WildPokemon(
        id: 'w',
        pokemon: fakePokemon(1),
        position: Vector3.zero(),
        facing: pi / 2,
      )..eatingFor = eating ? 0 : null;
      final b = behavior();
      for (var i = 0; i < 180; i++) {
        b.perceive(
          w,
          player: Vector3(d, 0, 0),
          stealth: stealth,
          moving: moving,
          dt: 1 / 60,
        );
      }
      return w.awareness;
    }

    test('it does not see you right in front of it', () {
      expect(awarenessAfter(eating: false, d: 4), 1, reason: 'seen');
      expect(awarenessAfter(eating: true, d: 4), 0);
    });

    test('it hardly hears you: walking nearby no, running close yes', () {
      expect(
        awarenessAfter(eating: true, d: 3, moving: true),
        lessThan(WildBehavior.suspiciousLevel),
      );
      expect(
        awarenessAfter(
          eating: true,
          d: 3,
          stealth: PlayerStealth.noisy,
          moving: true,
        ),
        1,
      );
      expect(
        awarenessAfter(
          eating: true,
          d: 7,
          stealth: PlayerStealth.noisy,
          moving: true,
        ),
        0,
        reason: 'far enough',
      );
    });

    test('touching it still gives you away', () {
      expect(awarenessAfter(eating: true, d: 1), 1);
    });
  });

  test('if it notices you, it leaves the half-eaten berry for another', () {
    final s = world();
    final w = addWild(s, s.cellCenter(14, 4));
    final berry = dropBerry(s, w.position + Vector3(2, 0, 0));
    step(s, 3);
    expect(w.isEating, isTrue);

    s.behavior.startle(w);
    step(s, 1 / 60);
    expect(w.isEating, isFalse);
    expect(w.bait, isNull);
    expect(berry.claimedBy, isNull);
    expect(berry.eaten, greaterThan(0));
    expect(s.berries.loose, [same(berry)]);
  });

  test('a berry landing by a hidden Pokémon makes it peek out and come', () {
    final events = <World3DEvent>[];
    final s = world(events: events);
    final w = addWild(s, s.cellCenter(20, 4))..hidden = true;
    dropBerry(s, w.position + Vector3(2, 0, 1));
    step(s, 0.1);
    expect(w.hidden, isFalse);
    expect(events.whereType<PokemonRevealed>().single.startled, isFalse);
    expect(w.isAlert, isFalse);
    expect(w.bait, isNotNull);
  });

  test('a suspicious Pokémon forgets you when it smells a berry', () {
    final s = world();
    final w = addWild(s, s.cellCenter(20, 4))..awareness = 0.6;
    expect(w.isSuspicious, isTrue);
    dropBerry(s, w.position + Vector3(3, 0, 0));
    step(s, 0.1);
    expect(w.bait, isNotNull);
    expect(w.isSuspicious, isFalse);
  });

  test('alert Pokémon ignore berries; one that cannot reach it gives up', () {
    final s = world();
    final alert = addWild(s, s.cellCenter(20, 4));
    s.behavior.startle(alert);
    dropBerry(s, alert.position + Vector3(2, 0, 0));
    step(s, 0.1);
    expect(alert.bait, isNull);

    final stuck = addWild(s, s.cellCenter(14, 2), id: 'stuck');
    final berry = dropBerry(s, stuck.position + Vector3(4, 0, 0));
    step(s, 0.1);
    expect(stuck.bait, same(berry));
    stuck.baitTime = World3DSim.baitPatience + 1;
    step(s, 1 / 60);
    expect(stuck.bait, isNull);
    expect(berry.claimedBy, isNull);
  });

  test('eating makes it easier to catch (×1,5, on top of stealth)', () {
    double chance({required bool eating, bool unaware = true}) =>
        CaptureCalculator.chance(
          captureRate: 45,
          ball: PokeBallType.poke,
          unaware: unaware,
          fromBehind: false,
          eating: eating,
        );
    expect(
      chance(eating: true),
      closeTo(chance(eating: false) * CaptureCalculator.eatingBonus, 1e-12),
    );

    // Con una bola en la mano, el % del anillo ya lo cuenta.
    final s = world();
    final w = addWild(s, s.player.position + Vector3(6, 0, 0));
    s.camera.yaw = -pi / 2; // mirando hacia +X
    s.aiming = true;
    step(s, 0.1);
    final before = s.lockedChance!;
    w.eatingFor = 1;
    expect(
      s.lockedChance,
      closeTo(before * CaptureCalculator.eatingBonus, 1e-9),
    );
  });

  test('a ball that hits it while eating says so; inside the ball it stops '
      'eating', () {
    final s = world();
    final w = addWild(s, s.cellCenter(14, 4));
    final berry = dropBerry(s, w.position + Vector3(2, 0, 0));
    step(s, 3);
    expect(w.isEating, isTrue);

    final from = w.position + Vector3(-3, 1, 0);
    s.ballSystem.launch(PokeBallType.poke, from, Vector3(12, 0, 0));
    step(s, 0.4);
    final ball = s.balls.single;
    expect(ball.hit?.eating, isTrue);
    expect(w.isFree, isFalse);
    expect(w.bait, isNull);
    expect(berry.claimedBy, isNull);
  });

  test('the whole plan: a berry behind it, it turns its back to eat it and '
      'the ball hits with every bonus', () {
    final s = world();
    // De lado (mirando hacia +Z): el jugador, a su izquierda, no se ve.
    final w = addWild(s, s.player.position + Vector3(7, 0, 0))..facing = 0;
    s
      ..berryReady = true
      ..aiming = true
      ..camera.yaw = -pi / 2; // mirando hacia +X
    step(s, 0.1);
    expect(s.throwBerry(), isTrue);
    step(s, 3);
    expect(w.isEating, isTrue);
    expect(w.isAlert, isFalse);
    expect(w.facingDirection.x, greaterThan(0.9), reason: 'its back to you');

    s.berryReady = false;
    step(s, 0.1);
    expect(s.throwBall(PokeBallType.poke), isTrue);
    step(s, 1.2);
    expect(s.balls.single.hit, (unaware: true, fromBehind: true, eating: true));
  });
}
