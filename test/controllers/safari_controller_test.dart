// PRUEBAS del RETO SAFARI (controlador): 25 bolas propias que se acaban;
// cada bola lanzada termina de una sola manera (captura, escape o fallo);
// el reto acaba al terminar el tiempo, al resolverse la última bola o al
// abandonar; lo capturado se apunta; fuera del reto no cuenta nada.

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/safari_controller.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_events.dart';
import 'package:pokemon_game/models/capture_result.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

void main() {
  WildPokemon wild(int id) => WildPokemon(
    id: 'w$id',
    pokemon: fakePokemon(id),
    position: Vector3.zero(),
  );
  const caught = CaptureResult(chance: 0.5, shakes: 3, caught: true);
  const escaped = CaptureResult(chance: 0.5, shakes: 1, caught: false);

  test('off by default; starting gives 25 balls of its own', () {
    final safari = SafariController();
    expect(safari.phase, SafariPhase.off);
    expect(safari.takeBall(), isNull, reason: 'no challenge, no balls');
    safari.start();
    expect(safari.isRunning, isTrue);
    expect(safari.ballsLeft, SafariController.ballCount);
    expect(safari.takeBall(), SafariController.ball);
    expect(safari.ballsLeft, SafariController.ballCount - 1);
  });

  test('catches are kept; escapes and misses only use up the ball', () {
    final safari = SafariController()..start();
    for (var i = 0; i < 3; i++) {
      safari.takeBall();
    }
    safari
      ..onWorldEvent(PokemonCaught(wild(4), PokeBallType.poke, caught))
      ..onWorldEvent(PokemonBrokeFree(wild(5), PokeBallType.poke, escaped))
      ..onWorldEvent(const BallMissed(PokeBallType.poke, lost: true));
    expect(safari.isRunning, isTrue);
    expect(safari.catches.map((p) => p.id), [4]);
  });

  test('out of balls: it ends when the LAST ball is settled', () {
    final safari = SafariController()..start();
    for (var i = 0; i < SafariController.ballCount; i++) {
      expect(safari.takeBall(), isNotNull);
    }
    expect(safari.takeBall(), isNull);
    for (var i = 0; i < SafariController.ballCount - 1; i++) {
      safari.onWorldEvent(const BallMissed(PokeBallType.poke, lost: true));
    }
    expect(safari.isRunning, isTrue, reason: 'one still rolling');
    safari.onWorldEvent(PokemonCaught(wild(9), PokeBallType.poke, caught));
    expect(safari.phase, SafariPhase.finished);
    expect(safari.end, SafariEnd.outOfBalls);
    expect(safari.catches.map((p) => p.id), [9]);
  });

  test('time up and abandoning end it; closing goes back to free mode', () {
    final timed = SafariController()..start();
    timed.onWorldEvent(const SafariTimeUp());
    expect(timed.phase, SafariPhase.finished);
    expect(timed.end, SafariEnd.timeUp);
    timed.close();
    expect(timed.phase, SafariPhase.off);

    final quitter = SafariController()..start();
    quitter.abandon();
    expect(quitter.end, SafariEnd.abandoned);
    // Terminado, ya no cuenta nada ni da bolas.
    quitter.onWorldEvent(PokemonCaught(wild(1), PokeBallType.poke, caught));
    expect(quitter.catches, isEmpty);
    expect(quitter.takeBall(), isNull);
    // Otro reto empieza de cero.
    quitter
      ..close()
      ..start();
    expect(quitter.isRunning, isTrue);
    expect(quitter.ballsLeft, SafariController.ballCount);
    expect(quitter.end, isNull);
  });

  test('outside a challenge nothing counts', () {
    final safari = SafariController()
      ..onWorldEvent(PokemonCaught(wild(1), PokeBallType.poke, caught))
      ..onWorldEvent(const SafariTimeUp());
    expect(safari.phase, SafariPhase.off);
    expect(safari.catches, isEmpty);
  });
}
