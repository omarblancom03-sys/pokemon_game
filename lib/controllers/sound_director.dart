import '../game3d/sim/wild_pokemon.dart';
import '../game3d/sim/world3d_events.dart';
import '../services/sound/sound_service.dart';

/// QUÉ SUENA Y CUÁNDO en el mundo 3D: escucha los eventos de la simulación
/// y se lo pide al [SoundService] (que solo sabe hacer sonar).
///
///  - Lanzar ("¡fiu!"), golpear (la bola lo absorbe), cada sacudida ("toc";
///    la de una crítica, más fuerte y con destellos), capturado ("¡clic!" y
///    fanfarria) o se escapa ("¡pop!" y su grito).
///  - Recoger bolas o bayas, sacudir un arbusto.
///  - Un destello al ver un variocolor.
///  - El GRITO de la especie cuando un Pokémon te descubre ("!"), sale de
///    la hierba asustado o le despiertas. Para no saturar: el mismo Pokémon
///    no vuelve a gritar en [cryCooldown] s y entre dos gritos cualesquiera
///    pasan al menos [cryGap] s.
class SoundDirector {
  SoundDirector(this.sound, {required this._clock});

  final SoundService sound;

  /// Segundos del juego (para los enfriamientos de los gritos).
  final double Function() _clock;

  static const cryCooldown = 10.0;
  static const cryGap = 1.2;

  final Map<String, double> _lastCry = {};
  double? _lastAnyCry;

  void onWorldEvent(World3DEvent event) {
    switch (event) {
      case ItemThrown(:final ball):
        sound.play(ball == null ? GameSound.throwBerry : GameSound.throwBall);
      case BallHit():
        sound.play(GameSound.hit);
      case BallShook(:final critical):
        sound.play(critical ? GameSound.criticalShake : GameSound.shake);
      case PokemonCaught(:final result):
        sound.play(
          result.critical ? GameSound.criticalCaught : GameSound.caught,
        );
      case PokemonBrokeFree(:final wild):
        sound.play(GameSound.brokeFree);
        // Al salir de la bola grita (como en los juegos), aunque acabara de
        // hacerlo.
        _cry(wild, force: true);
      case BallsPickedUp() || BerriesPickedUp():
        sound.play(GameSound.pickUp);
      case BushShaken():
        sound.play(GameSound.bushRustle);
      case PokemonNoticed(:final wild):
        _cry(wild);
      case PokemonRevealed(:final wild, :final startled):
        // Si se asoma sin verte, no grita (no sabe que estás ahí).
        if (startled) _cry(wild);
      case PokemonWoke(:final wild, :final startled):
        // Despertado de golpe, grita; si se despierta solo, no.
        if (startled) _cry(wild);
      case ShinySpotted():
        sound.play(GameSound.shiny);
      case PokemonDodged() || PlayerRolled():
        sound.play(GameSound.dodge);
      case PokemonDazed():
        sound.play(GameSound.dazed);
      case Footstep(:final surface, :final loudness):
        sound.play(switch (surface) {
          GroundSurface.dirt => GameSound.stepDirt,
          GroundSurface.stone => GameSound.stepStone,
          GroundSurface.lawn => GameSound.stepGrass,
          GroundSurface.tallGrass => GameSound.stepTallGrass,
        }, volume: loudness);
      case BallMissed() || PokemonEating() || SafariTimeUp():
        break;
    }
  }

  void _cry(WildPokemon wild, {bool force = false}) {
    final now = _clock();
    if (!force) {
      final any = _lastAnyCry;
      if (any != null && now - any < cryGap) return;
      final last = _lastCry[wild.id];
      if (last != null && now - last < cryCooldown) return;
    }
    _lastCry[wild.id] = now;
    _lastAnyCry = now;
    sound.playCry(wild.pokemon.id);
  }
}
