import '../../models/capture_result.dart';
import '../../models/poke_ball.dart';
import '../../models/throw_quality.dart';
import 'wild_pokemon.dart';

/// Lo que la simulación 3D cuenta hacia fuera (a la pantalla, que lo pasa
/// a los controladores). `sealed`: quien los reciba con un `switch` sabe
/// que no se le escapa ningún caso.
sealed class World3DEvent {
  const World3DEvent();
}

/// El jugador recogió Poké Balls del suelo.
class BallsPickedUp extends World3DEvent {
  const BallsPickedUp(this.ball, this.count);

  final PokeBallType ball;
  final int count;
}

/// Una bola lanzada no dio a nadie y se quedó en el suelo (se puede
/// volver a recoger).
class BallMissed extends World3DEvent {
  const BallMissed(this.ball);

  final PokeBallType ball;
}

/// ¡Capturado! [wild] ya no está en el mundo.
class PokemonCaught extends World3DEvent {
  const PokemonCaught(this.wild, this.ball, this.result);

  final WildPokemon wild;
  final PokeBallType ball;
  final CaptureResult result;
}

/// El Pokémon se escapó de la bola (la bola se pierde).
class PokemonBrokeFree extends World3DEvent {
  const PokemonBrokeFree(this.wild, this.ball, this.result);

  final WildPokemon wild;
  final PokeBallType ball;
  final CaptureResult result;
}

/// El jugador sacudió un arbusto; soltó [berries] bayas (0 = no le
/// quedaba ninguna).
class BushShaken extends World3DEvent {
  const BushShaken(this.berries);

  final int berries;
}

/// El jugador recogió bayas del suelo.
class BerriesPickedUp extends World3DEvent {
  const BerriesPickedUp(this.count);

  final int count;
}

/// Un Pokémon escondido en la hierba alta salió de ella. [startled]: salió
/// asustado (te oyó llegar o cayó una bola cerca); si no, se asomó sin
/// verte (te acercaste con sigilo).
class PokemonRevealed extends World3DEvent {
  const PokemonRevealed(this.wild, {required this.startled});

  final WildPokemon wild;
  final bool startled;
}

/// Un Pokémon empezó a comerse una baya del suelo (mientras come está
/// distraído: no te ve y es más fácil de capturar).
class PokemonEating extends World3DEvent {
  const PokemonEating(this.wild);

  final WildPokemon wild;
}

/// El jugador lanzó algo: la mano soltó una Poké Ball ([ball]) o una baya
/// ([ball] null).
class ItemThrown extends World3DEvent {
  const ItemThrown(this.ball);

  final PokeBallType? ball;
}

/// Una Poké Ball le dio a [wild]: empieza a absorberlo.
class BallHit extends World3DEvent {
  const BallHit(this.wild, this.quality);

  final WildPokemon wild;

  /// Calidad del tiro (el aro al lanzar).
  final ThrowQuality quality;
}

/// La bola con un Pokémon dentro se sacudió: la sacudida número [count]
/// (1, 2 o 3). [critical]: es la única y fuerte de una captura crítica.
class BallShook extends World3DEvent {
  const BallShook(this.count, {required this.critical});

  final int count;
  final bool critical;
}

/// Un Pokémon acaba de descubrir al jugador ("!").
class PokemonNoticed extends World3DEvent {
  const PokemonNoticed(this.wild);

  final WildPokemon wild;
}

/// El jugador tiene cerca, a la vista, un Pokémon VARIOCOLOR (se avisa una
/// vez por Pokémon).
class ShinySpotted extends World3DEvent {
  const ShinySpotted(this.wild);

  final WildPokemon wild;
}
