// PRUEBAS del lanzamiento de Poké Balls en el mundo 3D: el tiro parabólico
// llega a su destino, la mira fija al Pokémon más centrado, la bola sale de
// la mano al final del gesto, golpea, absorbe, cae, se sacude y termina en
// captura o en huida; si no da a nadie rebota (también contra árboles) y
// queda en el suelo para recogerla.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/capture/capture_calculator.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/aiming.dart';
import 'package:pokemon_game/game3d/sim/throwing.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

/// Random que siempre devuelve lo mismo: 0 = todas las comprobaciones de
/// captura salen bien; 0.999 = todas salen mal.
class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => (value * max).floor().clamp(0, max - 1);

  @override
  bool nextBool() => value >= 0.5;
}

void main() {
  // Campo abierto de 24x7 casillas (48 x 14 m), jugador a la izquierda.
  final open = MapLayout.parse(const [
    'TTTTTTTTTTTTTTTTTTTTTTTT',
    'T......................T',
    'T......................T',
    'T..@...................T',
    'T......................T',
    'T......................T',
    'TTTTTTTTTTTTTTTTTTTTTTTT',
  ]);

  /// Mundo sin bolas en el suelo; la cámara mira hacia +X.
  World3DSim world({
    MapLayout? layout,
    double roll = 0,
    List<World3DEvent>? events,
  }) {
    final s = World3DSim(
      layout: layout ?? open,
      maxFieldItems: 0,
      calculator: CaptureCalculator(random: _FixedRandom(roll)),
      onEvent: events?.add,
    );
    s.camera.yaw = -pi / 2; // forward = +X
    return s;
  }

  WildPokemon addWild(
    World3DSim s,
    Vector3 at, {
    int captureRate = 45,
    Temperament temperament = Temperament.curious,
  }) {
    final w = WildPokemon(
      id: 'w${s.wild.length}',
      pokemon: fakePokemon(25),
      position: at,
      captureRate: captureRate,
      temperament: temperament,
      facing: pi / 2, // mira hacia +X (de espaldas al jugador)
    )..idleTime = 1e9; // que no se mueva
    s.wild.add(w);
    return w;
  }

  void step(World3DSim s, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60);
    }
  }

  group('ballistics', () {
    test('the low arc passes through the target', () {
      final from = Vector3(0, 1.5, 0);
      final to = Vector3(10, 0.5, 4);
      final v = ballisticVelocity(from, to)!;
      expect(v.length, closeTo(throwSpeed, 1e-6));

      // Integrar a mano y comprobar que pasa cerca del objetivo.
      final p = from.clone();
      final vel = v.clone();
      var closest = double.infinity;
      for (var i = 0; i < 400; i++) {
        vel.y -= gravity / 200;
        p.add(vel / 200);
        closest = min(closest, p.distanceTo(to));
      }
      expect(closest, lessThan(0.1));
    });

    test('out of range gives null', () {
      expect(ballisticVelocity(Vector3.zero(), Vector3(40, 0, 0)), isNull);
    });

    test('obstacles have heights; walkable ground has none', () {
      expect(obstacleHeight(TileKind.grass), 0);
      expect(obstacleHeight(TileKind.fence), lessThan(1.5));
      expect(obstacleHeight(TileKind.tree), greaterThan(3));
      expect(obstacleHeight(null), greaterThan(5), reason: 'outer forest');
    });
  });

  group('aiming', () {
    test('locks the most centered free Pokémon in range', () {
      final s = world();
      final p = s.player.position;
      final centered = addWild(s, p + Vector3(10, 0, 0.3));
      addWild(s, p + Vector3(6, 0, 2.5)); // ~23°: fuera del cono
      final behind = addWild(s, p + Vector3(-5, 0, 0));
      addWild(s, p + Vector3(maxLockDistance + 3, 0, 0)); // demasiado lejos

      expect(
        findLockTarget(player: p, forward: Vector3(1, 0, 0), wild: s.wild),
        centered,
      );
      expect(
        findLockTarget(player: p, forward: Vector3(-1, 0, 0), wild: s.wild),
        behind,
      );
      centered.capturedBy = 'ball-x';
      expect(
        findLockTarget(player: p, forward: Vector3(1, 0, 0), wild: s.wild),
        isNull,
        reason: 'inside a ball: not a target',
      );
    });

    test('aiming brings the camera to the shoulder and shows the arc', () {
      final s = world();
      final w = addWild(s, s.player.position + Vector3(9, 0, 0));
      expect(s.aimPreview, isEmpty, reason: 'not aiming');

      s.aiming = true;
      step(s, 0.5);
      expect(s.camera.aim, greaterThan(0.9));
      expect(s.lockedTarget, w);
      final arc = s.aimPreview;
      expect(arc.length, greaterThan(5));
      expect(arc.last.distanceTo(w.position), lessThan(w.hitRadius + 0.6));

      s.aiming = false;
      step(s, 0.5);
      expect(s.camera.aim, lessThan(0.1));
    });

    test('while aiming the body turns towards the target', () {
      final s = world();
      addWild(s, s.player.position + Vector3(0, 0, 8)); // a +Z
      s.camera.yaw = pi; // forward = +Z
      s.aiming = true;
      step(s, 0.6);
      expect(s.player.facing, closeTo(0, 0.05)); // 0 = mirando a +Z
    });
  });

  group('throwing', () {
    test('the ball leaves the hand at the release moment, one at a time', () {
      final s = world();
      expect(s.throwBall(PokeBallType.poke), isTrue);
      expect(s.throwBall(PokeBallType.poke), isFalse, reason: 'mid-throw');
      expect(s.throwProgress, 0);
      s.update(World3DSim.releaseTime * 0.5);
      expect(s.balls, isEmpty);
      s.update(World3DSim.releaseTime);
      expect(s.balls, hasLength(1));
      expect(s.balls.single.position.y, greaterThan(1));
      step(s, World3DSim.throwDuration);
      expect(s.throwProgress, isNull);
      expect(s.canThrow, isTrue);
    });

    test('the held ball and the chance follow the ready ball', () {
      final s = world();
      addWild(s, s.player.position + Vector3(8, 0, 0), captureRate: 51);
      step(s, 0.1);
      expect(s.heldBall, isNull, reason: 'not aiming');

      s.aiming = true;
      expect(s.heldBall, PokeBallType.poke);
      // Por la espalda y sin ser visto: 0,2 × 2.
      expect(s.lockedChance, closeTo(0.4, 1e-9));
      s.readyBall = PokeBallType.ultra;
      expect(s.lockedChance, closeTo(0.8, 1e-9));

      s.readyBall = null; // bolsa vacía
      expect(s.heldBall, isNull);
      expect(s.lockedChance, isNull);
      expect(s.aimPreview, isEmpty);

      s.throwBall(PokeBallType.great);
      expect(s.heldBall, PokeBallType.great, reason: 'in hand until release');
      step(s, World3DSim.releaseTime + 0.05);
      expect(s.heldBall, isNull);
    });

    test('no throwing while paused', () {
      final s = world()..setPaused(true);
      expect(s.throwBall(PokeBallType.poke), isFalse);
    });

    test('hit → absorb → fall → 3 shakes → caught', () {
      final events = <World3DEvent>[];
      final s = world(events: events);
      final w = addWild(s, s.player.position + Vector3(9, 0, 0));
      step(s, 0.1);
      expect(s.lockedTarget, w);
      s.throwBall(PokeBallType.great);

      // Vuela hasta golpearlo.
      var guard = 0;
      while (s.balls.isEmpty || s.balls.single.phase == BallPhase.flying) {
        s.update(1 / 60);
        expect(++guard, lessThan(200), reason: 'should hit within ~3 s');
      }
      final ball = s.balls.single;
      expect(ball.phase, BallPhase.absorbing);
      expect(ball.target, w);
      expect(w.capturedBy, ball.id);
      expect(w.isFree, isFalse);
      expect(ball.velocity.y, greaterThan(0), reason: 'pops up');

      // Absorbe, cae y se sacude.
      step(s, ThrownBall.absorbTime + 0.8);
      expect(ball.phase, BallPhase.shaking);
      expect(ball.position.y, closeTo(ballRadius, 1e-6));

      var sawWobble = false;
      while (ball.phase == BallPhase.shaking) {
        s.update(1 / 60);
        sawWobble |= ball.wobble.abs() > 0.1;
      }
      expect(sawWobble, isTrue);
      expect(ball.shakesDone, 3);
      expect(ball.phase, BallPhase.caught);
      expect(s.wild, isEmpty, reason: 'caught: gone from the world');
      final caught = events.whereType<PokemonCaught>().single;
      expect(caught.wild, w);
      expect(caught.ball, PokeBallType.great);
      expect(caught.result.caught, isTrue);

      step(s, ThrownBall.caughtTime + 0.1);
      expect(s.balls, isEmpty);
    });

    test('a critical capture shakes once, harder, and is caught', () {
      final events = <World3DEvent>[];
      final s = world(events: events)..criticalChance = 1;
      addWild(s, s.player.position + Vector3(9, 0, 0));
      step(s, 0.1);
      s.throwBall(PokeBallType.poke);
      while (s.balls.isEmpty || s.balls.single.phase == BallPhase.flying) {
        s.update(1 / 60);
      }
      final ball = s.balls.single;
      expect(ball.result!.critical, isTrue);
      expect(
        ball.shakingDuration,
        ThrownBall.shakeSettle + ThrownBall.shakeCycle,
      );

      var maxWobble = 0.0;
      while (ball.phase != BallPhase.caught) {
        s.update(1 / 60);
        maxWobble = max(maxWobble, ball.wobble.abs());
      }
      expect(ball.shakesDone, 1);
      expect(
        maxWobble,
        greaterThan(0.45),
        reason: 'stronger than a normal one',
      );
      expect(events.whereType<PokemonCaught>().single.result.critical, isTrue);
    });

    test('all checks fail → no shakes, it breaks free and is alert', () {
      final events = <World3DEvent>[];
      final s = world(roll: 0.999, events: events);
      final w = addWild(s, s.player.position + Vector3(7, 0, 0));
      step(s, 0.1);
      s.throwBall(PokeBallType.poke);
      step(s, 4);

      final escaped = events.whereType<PokemonBrokeFree>().single;
      expect(escaped.result.shakes, 0);
      expect(w.isFree, isTrue);
      expect(w.isAlert, isTrue);
      expect(s.wild, contains(w));
      expect(s.balls, isEmpty, reason: 'the ball is lost');
      expect(s.fieldItems.items, isEmpty);
    });

    test('hitting its back gives the stealth bonus', () {
      final events = <World3DEvent>[];
      final s = world(events: events);
      // Ratio 51 → 0,2. Sin ser visto ×1,5 = 0,3; por la espalda ×2 = 0,4.
      final w = addWild(
        s,
        s.player.position + Vector3(8, 0, 0),
        captureRate: 51,
      );
      step(s, 0.1);
      s.throwBall(PokeBallType.poke);
      // Justo tras el golpe la bola cuenta cómo fue (para enseñarlo).
      while (s.balls.isEmpty || s.balls.single.phase == BallPhase.flying) {
        s.update(1 / 60);
      }
      final ball = s.balls.single;
      expect(ball.hit, (unaware: true, fromBehind: true, eating: false));
      expect(ball.sinceHit, closeTo(0, 0.02));
      step(s, 0.5);
      expect(ball.sinceHit, closeTo(0.5, 0.03));
      step(s, 5.5);
      expect(
        events.whereType<PokemonCaught>().single.result.chance,
        closeTo(0.4, 1e-9),
      );

      // De frente y ya alerta: sin bonus. (Curioso y a 3 m: se queda
      // quieto mirándote.)
      events.clear();
      final front =
          addWild(s, s.player.position + Vector3(3, 0, 0), captureRate: 51)
            ..facing = -pi / 2
            ..alertTime = 30;
      step(s, 0.1);
      expect(s.lockedTarget, front);
      s.throwBall(PokeBallType.poke);
      step(s, 0.6);
      expect(s.balls.single.hit, (
        unaware: false,
        fromBehind: false,
        eating: false,
      ));
      step(s, 5.4);
      expect(
        events.whereType<PokemonCaught>().single.result.chance,
        closeTo(0.2, 1e-9),
      );
      expect(w.capturedBy, isNotNull);
    });

    test('a miss bounces, rolls, and stays on the ground to pick up', () {
      final events = <World3DEvent>[];
      final s = world(events: events);
      s.throwBall(PokeBallType.ultra);
      step(s, 0.3);
      final ball = s.balls.single;
      var maxY = 0.0;
      for (var i = 0; i < 600 && s.balls.isNotEmpty; i++) {
        s.update(1 / 60);
        maxY = max(maxY, ball.position.y);
        if (ball.bounces > 0) expect(ball.phase, BallPhase.missed);
      }
      expect(s.balls, isEmpty);
      expect(ball.bounces, greaterThan(0));
      expect(events.whereType<BallMissed>().single.ball, PokeBallType.ultra);

      final item = s.fieldItems.items.single;
      expect(item.dropped, isTrue);
      expect(item.ball, PokeBallType.ultra);
      expect(
        open.isWalkable(
          s.cellAt(item.position).col,
          s.cellAt(item.position).row,
        ),
        isTrue,
      );

      // Se recoge al pasar.
      events.clear();
      s.player.teleport(item.position);
      s.update(1 / 60);
      expect(events.whereType<BallsPickedUp>().single.ball, PokeBallType.ultra);
    });

    test('trees stop the ball: it never goes through them', () {
      final wall = MapLayout.parse(const [
        'TTTTTTTTTTTTTTTT',
        'T.......T......T',
        'T.......T......T',
        'T..@....T......T',
        'T.......T......T',
        'T.......T......T',
        'TTTTTTTTTTTTTTTT',
      ]);
      final s = world(layout: wall);
      s.camera.pitch = 0.3; // tiro tenso, a la altura del árbol
      s.throwBall(PokeBallType.poke);
      step(s, 0.3);
      final ball = s.balls.single;
      var bounced = false;
      for (var i = 0; i < 900 && s.balls.isNotEmpty; i++) {
        s.update(1 / 60);
        final inTree = ball.position.x >= 16 && ball.position.x < 18;
        if (inTree) expect(ball.position.y, greaterThanOrEqualTo(4.5));
        expect(ball.position.x, lessThan(18), reason: 'never past the tree');
        bounced |= ball.velocity.x < 0;
      }
      expect(bounced, isTrue);
      expect(s.fieldItems.items.single.position.x, lessThan(16));
    });

    test('a Pokémon inside a ball does not move nor push the grass', () {
      final s = world();
      final w = addWild(s, s.player.position + Vector3(6, 0, 0))
        ..capturedBy = 'ball-9'
        ..target = s.player.position + Vector3(8, 0, 0);
      final start = w.position;
      step(s, 1);
      expect(w.position, start);
      expect(s.grassPushers, hasLength(1), reason: 'only the player');
    });
  });

  test('wobble only during the shakes that the result allows', () {
    final ball =
        ThrownBall(
            id: 'b',
            ball: PokeBallType.poke,
            position: Vector3.zero(),
            velocity: Vector3.zero(),
          )
          ..result = const CaptureResult(chance: 0.5, shakes: 1, caught: false)
          ..setPhase(BallPhase.shaking);
    expect(
      ball.shakingDuration,
      ThrownBall.shakeSettle + ThrownBall.shakeCycle,
    );
    ball.phaseTime = ThrownBall.shakeSettle + ThrownBall.shakeTime * 0.25;
    expect(ball.wobble.abs(), greaterThan(0.1));
    ball.phaseTime = ThrownBall.shakeSettle + ThrownBall.shakeCycle * 1.2;
    expect(ball.wobble, 0, reason: 'second shake is not in the result');
  });

  test('the button glows red with each shake and clicks white when caught', () {
    final ball =
        ThrownBall(
            id: 'b',
            ball: PokeBallType.poke,
            position: Vector3.zero(),
            velocity: Vector3.zero(),
          )
          ..result = const CaptureResult(chance: 0.5, shakes: 2, caught: true)
          ..setPhase(BallPhase.shaking);
    expect(ball.buttonGlow, 0, reason: 'settling after the fall');
    ball.phaseTime = ThrownBall.shakeSettle + ThrownBall.shakeTime / 2;
    expect(ball.buttonGlow, closeTo(1, 1e-9), reason: 'middle of shake 1');
    ball.phaseTime = ThrownBall.shakeSettle + ThrownBall.shakeTime + 0.1;
    expect(ball.buttonGlow, 0, reason: 'pause between shakes');
    ball.phaseTime =
        ThrownBall.shakeSettle +
        ThrownBall.shakeCycle +
        ThrownBall.shakeTime / 2;
    expect(ball.buttonGlow, closeTo(1, 1e-9), reason: 'middle of shake 2');
    ball.phaseTime = ThrownBall.shakeSettle + ThrownBall.shakeCycle * 2.5;
    expect(ball.buttonGlow, 0, reason: 'no third shake');
    expect(ball.clickFlash, 0);

    ball.setPhase(BallPhase.caught);
    expect(ball.clickFlash, 1);
    expect(ball.buttonGlow, 0);
    ball.phaseTime = ThrownBall.clickTime;
    expect(ball.clickFlash, 0);
  });

  test('a flying ball leaves a short trail that fades once it lands', () {
    final system = BallSystem(
      layout: MapLayout.parse(['T' * 20, 'T@${'.' * 17}T', 'T' * 20]),
      tileSize: 2,
      calculator: CaptureCalculator(random: Random(1)),
    );
    final ball = system.launch(
      PokeBallType.great,
      Vector3(3, 1.5, 3),
      Vector3(12, 3, 0),
    );
    void update() => system.update(
      1 / 60,
      wild: const [],
      drop: (_, _) {},
      remove: (_) {},
      emit: (_) {},
    );

    for (var i = 0; i < 20; i++) {
      update();
    }
    expect(ball.trail.length, greaterThan(3));
    expect(ball.trail.length, lessThanOrEqualTo(ThrownBall.trailLength));
    // Todos los puntos quedan detrás de la bola (va hacia +X).
    for (final p in ball.trail) {
      expect(p.x, lessThanOrEqualTo(ball.position.x));
    }
    for (var i = 1; i < ball.trail.length; i++) {
      expect(
        ball.trail[i].distanceTo(ball.trail[i - 1]),
        greaterThanOrEqualTo(ThrownBall.trailSpacing - 1e-6),
      );
    }

    // Tras el primer bote ya no vuela: la estela se acorta hasta desaparecer.
    while (ball.phase == BallPhase.flying) {
      update();
    }
    for (var i = 0; i < ThrownBall.trailLength; i++) {
      update();
    }
    expect(ball.trail, isEmpty);
  });
}
