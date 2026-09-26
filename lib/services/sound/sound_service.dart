import 'sound_factory_stub.dart'
    if (dart.library.js_interop) 'sound_factory_web.dart';

/// Los sonidos del juego (los efectos; los gritos van aparte, por especie).
enum GameSound {
  /// "¡Fiu!" al lanzar una Poké Ball.
  throwBall,

  /// Una baya lanzada (más flojo).
  throwBerry,

  /// La bola golpea al Pokémon y lo absorbe.
  hit,

  /// Una sacudida de la bola en el suelo.
  shake,

  /// La única sacudida, fuerte, de una captura crítica.
  criticalShake,

  /// "¡Clic!" y fanfarria: capturado.
  caught,

  /// Igual, con destellos: captura crítica.
  criticalCaught,

  /// "¡Pop!": se escapa de la bola.
  brokeFree,

  /// Recoger Poké Balls o bayas del suelo.
  pickUp,

  /// Sacudir un arbusto.
  bushRustle,

  /// Destellos: se ve un Pokémon variocolor.
  shiny,

  /// "¡Zas!": un Pokémon esquiva la bola de un salto (o ruedas tú).
  dodge,

  /// "Uiuiui": un Pokémon que te embestía se queda aturdido.
  dazed,
}

/// SONIDO (solo I/O): hace sonar lo que le piden. Qué sonido toca en cada
/// momento lo decide SoundDirector. En la web se sintetiza con Web Audio;
/// en el resto (y en los tests) no suena nada.
abstract interface class SoundService {
  /// El de esta plataforma.
  factory SoundService.create() => createPlatformSoundService();

  /// Suena [sound] (si no está silenciado).
  void play(GameSound sound);

  /// El grito de la especie [pokemonId] (los de PokeAPI).
  void playCry(int pokemonId);

  bool get muted;
  set muted(bool value);
}

/// No suena nada (plataformas sin sonido y tests). Recuerda si está
/// silenciado para que el botón funcione igual.
class SilentSoundService implements SoundService {
  @override
  bool muted = false;

  @override
  void play(GameSound sound) {}

  @override
  void playCry(int pokemonId) {}
}

/// Grito de la especie [pokemonId]: los de PokeAPI (los mismos que da
/// `cries.latest` en /pokemon/{id}; se deduce del número para no tener que
/// guardarlo en el modelo).
String pokemonCryUrl(int pokemonId) =>
    'https://raw.githubusercontent.com/PokeAPI/cries/main/cries/pokemon/latest/'
    '$pokemonId.ogg';
