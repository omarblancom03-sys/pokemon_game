// PRUEBAS de la CÁMARA DE CAPTURA: cuando una bola golpea, la cámara va a
// encuadrarla (desde el golpe hasta un poco después del resultado) y vuelve
// sola; en tiros cercanos apenas se mueve; el jugador la suelta al moverse
// (y sigue suelta para esa bola); otra bola que golpea la vuelve a llamar.
// También cómo mezcla OrbitCamera el encuadre, y el conjunto en el mundo:
// apuntar queda en suspenso mientras enseña la bola.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/capture/capture_calculator.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/capture_camera.dart';
import 'package:pokemon_game/game3d/sim/orbit_camera.dart';
import 'package:pokemon_game/game3d/sim/throwing.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

/// Random fijo: 0 = todas las comprobaciones de captura salen bien.
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
  /// Una bola que ya golpeó, en [at], en la fase [phase].
  ThrownBall hitBall(
    String id,
    Vector3 at, {
    BallPhase phase = BallPhase.shaking,
    double hitAge = 0,
  }) =>
      ThrownBall(
          id: id,
          ball: PokeBallType.poke,
          position: at,
          velocity: Vector3.zero(),
        )
        ..hitAge = hitAge
        ..setPhase(phase);

  void run(
    CaptureCamera cam,
    List<ThrownBall> balls,
    double seconds, {
    Vector3? player,
    bool interrupted = false,
  }) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      cam.update(
        1 / 60,
        balls: balls,
        player: player ?? Vector3.zero(),
        interrupted: interrupted,
      );
    }
  }

  group('CaptureCamera', () {
    test('nothing to show: it stays with the player', () {
      final cam = CaptureCamera();
      final flying = ThrownBall(
        id: 'b',
        ball: PokeBallType.poke,
        position: Vector3(10, 1, 0),
        velocity: Vector3(10, 0, 0),
      );
      run(cam, [flying], 1);
      expect(cam.focus, 0);
      expect(cam.engaged, isFalse);
    });

    test('a far hit is framed within a second, looking at the ball', () {
      final cam = CaptureCamera();
      final ball = hitBall('b', Vector3(10, ballRadius, 0));
      run(cam, [ball], 0.2);
      expect(cam.engaged, isTrue);
      expect(cam.focus, inInclusiveRange(0.3, 0.8), reason: 'on its way');
      run(cam, [ball], 1);
      expect(cam.focus, greaterThan(0.95));
      expect(
        cam.point.distanceTo(ball.position + Vector3(0, 0.2, 0)),
        lessThan(1e-6),
      );
    });

    test('a close hit barely moves it', () {
      final cam = CaptureCamera();
      run(cam, [hitBall('b', Vector3(2, ballRadius, 0))], 1.5);
      expect(cam.engaged, isTrue);
      expect(cam.focus, 0);
    });

    test('it lingers a little after the result and then goes back', () {
      final cam = CaptureCamera();
      final ball = hitBall('b', Vector3(10, ballRadius, 0));
      run(cam, [ball], 1.5);
      ball.setPhase(BallPhase.caught);
      ball.phaseTime = CaptureCamera.caughtLinger - 0.2;
      run(cam, [ball], 0.1);
      expect(cam.focus, greaterThan(0.9), reason: 'the stars');
      ball.phaseTime = CaptureCamera.caughtLinger + 0.1;
      run(cam, [ball], 2.5);
      expect(cam.focus, lessThan(0.01));
      expect(cam.engaged, isFalse);
    });

    test('moving lets go of this ball; another hit calls it back', () {
      final cam = CaptureCamera();
      final first = hitBall('a', Vector3(10, ballRadius, 0));
      run(cam, [first], 1);
      run(cam, [first], 1 / 60, interrupted: true);
      expect(cam.released, isTrue);
      run(cam, [first], 2);
      expect(cam.focus, lessThan(0.01), reason: 'stays released');

      final second = hitBall('b', Vector3(0, ballRadius, 10), hitAge: 5);
      run(cam, [first, second], 1.5);
      expect(cam.followedId, 'b');
      expect(cam.focus, greaterThan(0.95));
    });
  });

  group('OrbitCamera framing', () {
    test('focus 0 changes nothing; focus 1 looks at the point up close', () {
      final camera = OrbitCamera(pitch: 0.4, distance: 8);
      final feet = Vector3(1, 0, 2);
      final eye = camera.eyeFor(feet);
      camera.focusPoint = Vector3(0, 0.3, -10);
      expect(camera.eyeFor(feet).distanceTo(eye), lessThan(1e-9));

      camera.focus = 1;
      expect(
        camera.targetFor(feet).distanceTo(camera.focusPoint),
        lessThan(1e-9),
      );
      expect(
        camera.effectiveDistance,
        closeTo(OrbitCamera.focusDistance, 1e-9),
      );
      expect(camera.effectivePitch, closeTo(OrbitCamera.focusPitch, 1e-9));
      expect(
        camera.eyeFor(feet).distanceTo(camera.focusPoint),
        closeTo(OrbitCamera.focusDistance, 1e-5),
      );
      // A medias, entre las dos.
      camera.focus = 0.5;
      expect(
        camera.effectiveDistance,
        closeTo((8 + OrbitCamera.focusDistance) / 2, 1e-9),
      );
    });

    test('something tall behind the ball brings the framing closer', () {
      final camera = OrbitCamera(pitch: 0.4, distance: 8)
        ..focus = 1
        ..focusPoint = Vector3(0, 0.3, 0);
      // Un muro a 2 m detrás de la bola (del lado de la cámara, +Z).
      camera.avoidObstacles(
        Vector3(0, 0, 20),
        (x, z) => z > 2 && z < 2.5 ? 5 : 0,
        1 / 60,
      );
      expect(camera.effectiveDistance, lessThan(2.5));
    });
  });

  group('in the world', () {
    final open = MapLayout.parse(const [
      'TTTTTTTTTTTTTTTTTTTTTTTT',
      'T......................T',
      'T......................T',
      'T..@...................T',
      'T......................T',
      'T......................T',
      'TTTTTTTTTTTTTTTTTTTTTTTT',
    ]);

    (World3DSim, WildPokemon) world() {
      final s = World3DSim(
        layout: open,
        maxFieldItems: 0,
        calculator: CaptureCalculator(random: _FixedRandom(0)),
      )..camera.yaw = -pi / 2; // hacia +X
      final w = WildPokemon(
        id: 'w',
        pokemon: fakePokemon(25),
        position: s.player.position + Vector3(10, 0, 0),
        temperament: Temperament.curious,
        facing: pi / 2,
      )..idleTime = 1e9;
      s.wild.add(w);
      return (s, w);
    }

    void step(World3DSim s, double seconds) {
      for (var t = 0.0; t < seconds; t += 1 / 60) {
        s.update(1 / 60);
      }
    }

    test('aiming is on hold while the ball is shown, and comes back', () {
      final (s, _) = world();
      s.aiming = true;
      step(s, 0.5);
      expect(s.isAiming, isTrue);
      s.throwBall(PokeBallType.poke);
      step(s, 2);
      expect(s.balls.single.phase, BallPhase.shaking);
      expect(s.captureCam.engaged, isTrue);
      expect(s.isAiming, isFalse, reason: 'the camera shows the ball');
      expect(s.camera.focus, greaterThan(0.9));
      expect(s.aimPreview, isEmpty);
      // Tras el resultado vuelve sola; se sigue manteniendo apuntar.
      step(s, 8);
      expect(s.camera.focus, lessThan(0.01));
      expect(s.isAiming, isTrue);
    });

    test('pressing aim again or walking lets go of it', () {
      final (s, _) = world();
      s.throwBall(PokeBallType.poke);
      step(s, 1.5);
      expect(s.captureCam.engaged, isTrue);
      s.aiming = true; // pulsar apuntar de nuevo
      step(s, 1 / 60);
      expect(s.captureCam.released, isTrue);
      expect(s.isAiming, isTrue);

      final (t, _) = world();
      t.throwBall(PokeBallType.poke);
      step(t, 1.5);
      t.input.setKeyboardDirection(Vector2(1, 0));
      step(t, 1 / 60);
      expect(t.captureCam.released, isTrue);
    });
  });
}
