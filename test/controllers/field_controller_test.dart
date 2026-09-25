// PRUEBAS del controlador del campo 3D: recoger bolas llena la bolsa, una
// captura se apunta en el entrenador, cada suceso deja su aviso (como mucho
// tres a la vez; también cuando un Pokémon sale de la hierba) y sin bolas no
// se lanza nada.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/field_controller.dart';
import 'package:pokemon_game/controllers/trainer_controller.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_events.dart';
import 'package:pokemon_game/models/capture_result.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:pokemon_game/services/poke_api_exception.dart';
import 'package:pokemon_game/services/random_pokemon_picker.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

void main() {
  late FakePokemonRepository repository;
  setUp(() => repository = FakePokemonRepository(speciesCount: 30));

  FieldController newField(TrainerController trainer) => FieldController(
    trainer: trainer,
    picker: RandomPokemonPicker(repository: repository, random: Random(4)),
    repository: repository,
  );

  WildPokemon wild(int id) => WildPokemon(
    id: 'w$id',
    pokemon: fakePokemon(id),
    position: Vector3.zero(),
  );

  const escaped = CaptureResult(chance: 0.3, shakes: 2, caught: false);
  const caught = CaptureResult(chance: 0.3, shakes: 3, caught: true);

  test('picking up balls fills the bag and posts a notice', () {
    final trainer = TrainerController(startingBag: const {});
    final field = newField(trainer)
      ..onWorldEvent(const BallsPickedUp(PokeBallType.great, 2));

    expect(trainer.count(PokeBallType.great), 2);
    expect(trainer.selected, PokeBallType.great);
    final notice = field.notices.single;
    expect(notice.kind, FieldNoticeKind.pickedUp);
    expect(notice.ball, PokeBallType.great);
    expect(notice.count, 2);
  });

  test('a capture is registered in the trainer; an escape is not', () {
    final trainer = TrainerController();
    final field = newField(trainer)
      ..onWorldEvent(PokemonBrokeFree(wild(4), PokeBallType.poke, escaped))
      ..onWorldEvent(PokemonCaught(wild(7), PokeBallType.ultra, caught));

    expect(trainer.captured.single.pokemon.id, 7);
    expect(trainer.captured.single.ball, PokeBallType.ultra);
    expect(field.notices.map((n) => n.kind), [
      FieldNoticeKind.brokeFree,
      FieldNoticeKind.caught,
    ]);
    expect(field.notices.first.shakes, 2);
  });

  test('a capture says whether the species is new for the trainer', () {
    final trainer = TrainerController();
    final field = newField(trainer)
      ..onWorldEvent(PokemonCaught(wild(7), PokeBallType.poke, caught))
      ..onWorldEvent(PokemonCaught(wild(7), PokeBallType.great, caught))
      ..onWorldEvent(PokemonCaught(wild(9), PokeBallType.poke, caught));

    expect(field.notices.map((n) => n.isNew), [true, false, true]);
    expect(trainer.captured, hasLength(3));
  });

  test('a critical capture is flagged in its notice', () {
    const critical = CaptureResult(
      chance: 0.3,
      shakes: 1,
      caught: true,
      critical: true,
    );
    final field = newField(TrainerController())
      ..onWorldEvent(PokemonCaught(wild(3), PokeBallType.poke, critical))
      ..onWorldEvent(PokemonCaught(wild(4), PokeBallType.poke, caught));
    expect(field.notices.map((n) => n.critical), [true, false]);
  });

  test('a Pokémon coming out of the grass says how it came out', () {
    final field = newField(TrainerController())
      ..onWorldEvent(PokemonRevealed(wild(5), startled: true))
      ..onWorldEvent(PokemonRevealed(wild(6), startled: false));
    expect(field.notices.map((n) => n.kind), [
      FieldNoticeKind.burstOut,
      FieldNoticeKind.peeked,
    ]);
    expect(field.notices.map((n) => n.pokemon?.id), [5, 6]);
  });

  test('only the newest notices are kept; dismiss removes one', () {
    final field = newField(TrainerController());
    for (var i = 0; i < 5; i++) {
      field.onWorldEvent(const BallMissed(PokeBallType.poke));
    }
    expect(field.notices, hasLength(FieldController.maxNotices));
    expect(field.notices.first.id, 2);

    var notified = 0;
    field
      ..addListener(() => notified++)
      ..dismiss(3)
      ..dismiss(99); // ya no está: no avisa
    expect(field.notices.map((n) => n.id), [2, 4]);
    expect(notified, 1);
  });

  test('taking a ball spends it; with an empty bag it warns', () {
    final trainer = TrainerController(
      startingBag: const {PokeBallType.poke: 1},
    );
    final field = newField(trainer);

    expect(field.takeBallToThrow(), PokeBallType.poke);
    expect(field.notices, isEmpty);
    expect(field.takeBallToThrow(), isNull);
    expect(field.notices.single.kind, FieldNoticeKind.noBalls);
  });

  test('wild spawns come with their real capture rate', () async {
    repository.captureRate = 120;
    final spawn = (await newField(TrainerController()).pickWildSpawn())!;
    expect(spawn.captureRate, 120);
  });

  test('no network: no spawn; only the rate failing: default rate', () async {
    final f = newField(TrainerController());
    repository.failNext = const PokeApiNetworkException('offline');
    expect(await f.pickWildSpawn(), isNull);

    repository.failCaptureRate = true;
    final spawn = (await f.pickWildSpawn())!;
    expect(spawn.captureRate, FieldController.fallbackCaptureRate);
  });
}
