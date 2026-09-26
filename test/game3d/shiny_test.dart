// PRUEBAS de los VARIOCOLOR (shiny): salen con la probabilidad del mundo
// (1 de cada 100 por defecto) y sin tocar el azar del juego; se avisa UNA
// vez cuando se ve uno cerca (no escondido, no lejos); la captura guarda
// que era variocolor y el aviso lo dice. Solo es cosmético: la probabilidad
// de captura es la misma.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/field_controller.dart';
import 'package:pokemon_game/controllers/trainer_controller.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/capture_result.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:pokemon_game/models/pokemon_shiny.dart';
import 'package:pokemon_game/services/random_pokemon_picker.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

void main() {
  // Pradera de hierba alta de 30 x 10 casillas; el jugador a la izquierda.
  final layout = MapLayout.parse([
    'T' * 32,
    for (var row = 1; row < 11; row++) 'T${row == 5 ? '@' : '"'}${'"' * 29}T',
    'T' * 32,
  ]);

  void step(World3DSim s, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      s.update(1 / 60);
    }
  }

  Future<World3DSim> spawnSome(double shinyChance) async {
    var n = 0;
    final s = World3DSim(
      layout: layout,
      random: Random(1),
      maxFieldItems: 0,
      spawnWild: () async => (pokemon: fakePokemon(++n), captureRate: 45),
    )..shinyChance = shinyChance;
    for (var i = 0; i < 20 && s.wild.length < World3DSim.maxWild; i++) {
      step(s, 1);
      await pumpEventQueue();
    }
    return s;
  }

  test('the world decides: always, never, and 1 in 100 by default', () async {
    expect(World3DSim.defaultShinyChance, 0.01);
    final lucky = await spawnSome(1);
    expect(lucky.wild, isNotEmpty);
    expect(lucky.wild.every((w) => w.shiny), isTrue);
    final unlucky = await spawnSome(0);
    expect(unlucky.wild, isNotEmpty);
    expect(unlucky.wild.any((w) => w.shiny), isFalse);
  });

  test('being shiny does not change the rest of the game', () async {
    final a = await spawnSome(1);
    final b = await spawnSome(0);
    // Mismo azar del juego: aparecen en los mismos sitios.
    expect(
      a.wild.map((w) => w.position),
      orderedEquals(b.wild.map((w) => w.position)),
    );
  });

  group('spotting one', () {
    (World3DSim, List<World3DEvent>) world() {
      final events = <World3DEvent>[];
      final s = World3DSim(
        layout: layout,
        random: Random(1),
        maxFieldItems: 0,
        onEvent: events.add,
      );
      return (s, events);
    }

    WildPokemon add(
      World3DSim s,
      double dx, {
      bool shiny = true,
      bool hidden = false,
    }) {
      final w =
          WildPokemon(
              id: 'w${s.wild.length}',
              pokemon: fakePokemon(25),
              position: s.player.position + Vector3(dx, 0, 0),
              temperament: Temperament.curious,
              shiny: shiny,
            )
            ..idleTime = 1e9
            ..hidden = hidden;
      s.wild.add(w);
      return w;
    }

    test('seen nearby: one notice, once, with the moment it was seen', () {
      final (s, events) = world();
      final w = add(s, 12);
      add(s, 14, shiny: false);
      step(s, 0.5);
      step(s, 3);
      expect(events.whereType<ShinySpotted>().map((e) => e.wild), [w]);
      expect(w.shinySpotted, isTrue);
      expect(w.shinySpottedAt, closeTo(1 / 60, 1e-9));
    });

    test('too far or hidden in the grass: not yet', () {
      final (s, events) = world();
      add(s, World3DSim.markRange + 4);
      final hidden = add(s, 8, hidden: true);
      step(s, 1);
      expect(events.whereType<ShinySpotted>(), isEmpty);
      // Al salir de la hierba, sí.
      hidden.hidden = false;
      step(s, 0.1);
      expect(events.whereType<ShinySpotted>().map((e) => e.wild), [hidden]);
    });
  });

  test('its shiny art comes from PokeAPI by number', () {
    expect(
      fakePokemon(25).shinyImageUrl,
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/'
      'pokemon/other/official-artwork/shiny/25.png',
    );
  });

  group('FieldController', () {
    final repository = FakePokemonRepository(speciesCount: 30);
    FieldController field(TrainerController trainer) => FieldController(
      trainer: trainer,
      picker: RandomPokemonPicker(repository: repository),
      repository: repository,
    );
    WildPokemon wild({required bool shiny}) => WildPokemon(
      id: 'w',
      pokemon: fakePokemon(7),
      position: Vector3.zero(),
      shiny: shiny,
    );
    const caught = CaptureResult(chance: 0.3, shakes: 3, caught: true);

    test('spotting one posts a notice', () {
      final f = field(TrainerController())
        ..onWorldEvent(ShinySpotted(wild(shiny: true)));
      final notice = f.notices.single;
      expect(notice.kind, FieldNoticeKind.shinySpotted);
      expect(notice.pokemon!.id, 7);
      expect(notice.shiny, isTrue);
    });

    test('a shiny capture is kept as shiny (and its notice says so)', () {
      final trainer = TrainerController();
      final f = field(trainer)
        ..onWorldEvent(
          PokemonCaught(wild(shiny: true), PokeBallType.poke, caught),
        )
        ..onWorldEvent(
          PokemonCaught(wild(shiny: false), PokeBallType.poke, caught),
        );
      expect(trainer.captured.map((c) => c.shiny), [false, true]);
      expect(f.notices.map((n) => n.shiny), [true, false]);
    });
  });
}
