// PRUEBAS del SONIDO: qué suena con cada cosa que pasa en el mundo
// (lanzar, golpear, sacudidas, capturado o escapado, recoger, arbustos) y
// los gritos de los Pokémon, sin saturar (enfriamientos). Más la URL del
// grito y el servicio silencioso.

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/controllers/capture/capture_calculator.dart';
import 'package:pokemon_game/controllers/sound_director.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_events.dart';
import 'package:pokemon_game/models/poke_ball.dart';
import 'package:pokemon_game/services/sound/sound_service.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

/// Apunta lo que se le pide: sonidos y gritos (por número de especie).
class _RecordingSound implements SoundService {
  final played = <GameSound>[];
  final cries = <int>[];

  @override
  bool muted = false;

  final volumes = <double>[];

  @override
  void play(GameSound sound, {double volume = 1}) {
    played.add(sound);
    volumes.add(volume);
  }

  @override
  void playCry(int pokemonId) => cries.add(pokemonId);
}

WildPokemon wild(String id, int species) => WildPokemon(
  id: id,
  pokemon: fakePokemon(species),
  position: Vector3.zero(),
);

void main() {
  late _RecordingSound sound;
  late double now;
  late SoundDirector director;

  setUp(() {
    sound = _RecordingSound();
    now = 0;
    director = SoundDirector(sound, clock: () => now);
  });

  const caught = CaptureResult(chance: 1, shakes: 3, caught: true);
  const critical = CaptureResult(
    chance: 1,
    shakes: 1,
    caught: true,
    critical: true,
  );
  const escaped = CaptureResult(chance: 0.1, shakes: 2, caught: false);

  test('each moment of a capture has its sound', () {
    final w = wild('a', 25);
    for (final event in [
      const ItemThrown(PokeBallType.poke),
      BallHit(w, ThrowQuality.none),
      const BallShook(1, critical: false),
      const BallShook(2, critical: false),
      PokemonCaught(w, PokeBallType.poke, caught),
    ]) {
      director.onWorldEvent(event);
    }
    expect(sound.played, [
      GameSound.throwBall,
      GameSound.hit,
      GameSound.shake,
      GameSound.shake,
      GameSound.caught,
    ]);
    expect(sound.cries, isEmpty);
  });

  test('a critical capture: stronger shake and sparkles', () {
    final w = wild('a', 25);
    director
      ..onWorldEvent(const BallShook(1, critical: true))
      ..onWorldEvent(PokemonCaught(w, PokeBallType.great, critical));
    expect(sound.played, [GameSound.criticalShake, GameSound.criticalCaught]);
  });

  test('breaking free pops and it cries (even right after crying)', () {
    final w = wild('a', 25);
    director
      ..onWorldEvent(PokemonNoticed(w))
      ..onWorldEvent(PokemonBrokeFree(w, PokeBallType.poke, escaped));
    expect(sound.played, [GameSound.brokeFree]);
    expect(sound.cries, [25, 25]);
  });

  test('berries, pick-ups and bushes', () {
    director
      ..onWorldEvent(const ItemThrown(null))
      ..onWorldEvent(const BallsPickedUp(PokeBallType.ultra, 2))
      ..onWorldEvent(const BerriesPickedUp(1))
      ..onWorldEvent(const BushShaken(3))
      ..onWorldEvent(const BallMissed(PokeBallType.poke))
      ..onWorldEvent(PokemonEating(wild('a', 1)));
    expect(sound.played, [
      GameSound.throwBerry,
      GameSound.pickUp,
      GameSound.pickUp,
      GameSound.bushRustle,
    ]);
  });

  test('it cries when it notices you or bursts out scared, not when it '
      'peeks', () {
    director
      ..onWorldEvent(PokemonNoticed(wild('a', 1)))
      ..onWorldEvent(PokemonRevealed(wild('b', 4), startled: false));
    now = 5;
    director.onWorldEvent(PokemonRevealed(wild('c', 7), startled: true));
    expect(sound.cries, [1, 7]);
  });

  test('no flood of cries: the same one waits, and any two are apart', () {
    final a = wild('a', 1);
    director.onWorldEvent(PokemonNoticed(a));
    now = 0.5;
    director.onWorldEvent(PokemonNoticed(wild('b', 4)));
    expect(sound.cries, [1], reason: 'too soon after the other one');
    now = 3;
    director.onWorldEvent(PokemonNoticed(a));
    expect(sound.cries, [1], reason: 'the same one, too soon');
    director.onWorldEvent(PokemonNoticed(wild('b', 4)));
    expect(sound.cries, [1, 4]);
    now = SoundDirector.cryCooldown + 0.1;
    director.onWorldEvent(PokemonNoticed(a));
    expect(sound.cries, [1, 4, 1]);
  });

  test('a shiny in sight sparkles', () {
    director.onWorldEvent(
      ShinySpotted(
        WildPokemon(
          id: 's',
          pokemon: fakePokemon(1),
          position: Vector3.zero(),
          shiny: true,
        ),
      ),
    );
    expect(sound.played, [GameSound.shiny]);
  });

  test('cry URL and the silent service', () {
    expect(
      pokemonCryUrl(25),
      'https://raw.githubusercontent.com/PokeAPI/cries/main/cries/pokemon/'
      'latest/25.ogg',
    );
    final silent = SilentSoundService()
      ..play(GameSound.caught)
      ..playCry(1);
    expect(silent.muted, isFalse);
    silent.muted = true;
    expect(silent.muted, isTrue);
  });

  test('footsteps sound by surface, as loud as you step', () {
    director
      ..onWorldEvent(const Footstep(GroundSurface.tallGrass, 1))
      ..onWorldEvent(const Footstep(GroundSurface.dirt, 0.5))
      ..onWorldEvent(const Footstep(GroundSurface.lawn, 0.15))
      ..onWorldEvent(const Footstep(GroundSurface.stone, 0.5));
    expect(sound.played, [
      GameSound.stepTallGrass,
      GameSound.stepDirt,
      GameSound.stepGrass,
      GameSound.stepStone,
    ]);
    expect(sound.volumes, [1, 0.5, 0.15, 0.5]);
  });
}
