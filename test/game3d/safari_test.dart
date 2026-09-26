// PRUEBAS de las REGLAS DEL SAFARI en el mundo: al empezar no hay Poké
// Balls en el suelo (ni se ven, ni se recogen, ni aparecen), el reloj solo
// corre con el mundo en marcha y avisa UNA vez al llegar a cero, las bolas
// falladas se pierden (y el aviso lo dice), y al terminar todo vuelve a
// estar donde estaba.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/poke_ball.dart';

void main() {
  final open = MapLayout.parse(const [
    'TTTTTTTTTTTTTTTTTTTTTTTT',
    'T......................T',
    'T......................T',
    'T..@...................T',
    'T......................T',
    'T......................T',
    'TTTTTTTTTTTTTTTTTTTTTTTT',
  ]);

  (World3DSim, List<World3DEvent>) world({int items = 3}) {
    final events = <World3DEvent>[];
    final s = World3DSim(
      layout: open,
      random: Random(5),
      maxFieldItems: items,
      onEvent: events.add,
    )..camera.yaw = -pi / 2; // mirando hacia +X
    return (s, events);
  }

  void step(World3DSim s, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60);
    }
  }

  test('no balls on the ground during the challenge; back afterwards', () {
    final (s, events) = world();
    final before = s.fieldItems.items.map((i) => i.id).toList();
    expect(before, hasLength(3));
    final spot = s.fieldItems.items.first.position;
    s.startSafari(60);
    expect(s.safariActive, isTrue);
    expect(s.fieldItems.items, isEmpty);
    // Aunque se ponga encima de una, no la recoge (ni aparecen más).
    s.player.teleport(spot);
    step(s, 20);
    expect(events.whereType<BallsPickedUp>(), isEmpty);
    s.endSafari();
    expect(s.safariActive, isFalse);
    expect(s.fieldItems.items.map((i) => i.id), before);
  });

  test('the clock runs only while the world runs, and rings once', () {
    final (s, events) = world(items: 0);
    s.startSafari(2);
    step(s, 1);
    expect(s.safariTimeLeft, closeTo(1, 0.02));
    s.setPaused(true);
    step(s, 5);
    expect(s.safariTimeLeft, closeTo(1, 0.02), reason: 'paused');
    s.setPaused(false);
    step(s, 3);
    expect(s.safariTimeLeft, 0);
    expect(events.whereType<SafariTimeUp>(), hasLength(1));
  });

  test('a missed ball is lost in the challenge (and only there)', () {
    final (s, events) = world(items: 0);
    // Tiro a ojo hacia +X: cae en el campo sin dar a nadie.
    s.startSafari(60);
    s.throwBall(PokeBallType.poke);
    step(s, 6);
    expect(events.whereType<BallMissed>().single.lost, isTrue);
    expect(s.fieldItems.items, isEmpty);
    s.endSafari();
    expect(s.fieldItems.items, isEmpty, reason: 'it was never dropped');

    s.throwBall(PokeBallType.poke);
    step(s, 6);
    expect(events.whereType<BallMissed>().last.lost, isFalse);
    expect(s.fieldItems.items.single.dropped, isTrue);
  });
}
