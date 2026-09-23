import '../../models/capture_result.dart';
import '../../models/poke_ball.dart';
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
