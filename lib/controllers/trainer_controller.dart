import 'package:flutter/foundation.dart';

import '../models/poke_ball.dart';
import '../models/pokemon.dart';

/// Un Pokémon ya capturado y con qué bola se atrapó.
class CapturedPokemon {
  const CapturedPokemon({required this.pokemon, required this.ball});

  final Pokemon pokemon;
  final PokeBallType ball;
}

/// CONTROLADOR del entrenador (a nivel de app): la BOLSA (Poké Balls y
/// bayas), qué tiene en la mano para lanzar y los Pokémon capturados.
///
/// En la mano va una bola ([selected]) o, si [berrySelected], una baya
/// (para lanzarla cerca de un Pokémon y distraerlo).
///
/// Vive mientras la app esté abierta: salir del mapa y volver a entrar
/// conserva las bolas y las capturas.
class TrainerController extends ChangeNotifier {
  TrainerController({Map<PokeBallType, int>? startingBag, this._berries = 0})
    : _bag = {
        for (final type in PokeBallType.values) type: 0,
        ...(startingBag ?? const {PokeBallType.poke: 5}),
      };

  final Map<PokeBallType, int> _bag;
  int _berries;
  bool _berrySelected = false;
  final List<CapturedPokemon> _captured = [];
  PokeBallType _selected = PokeBallType.poke;

  int count(PokeBallType type) => _bag[type]!;

  int get totalBalls => _bag.values.fold(0, (a, b) => a + b);

  /// Bayas en la bolsa (se recogen sacudiendo arbustos).
  int get berries => _berries;

  /// ¿Lleva una baya en la mano (en vez de una bola)?
  bool get berrySelected => _berrySelected;

  /// Mete [amount] bayas en la bolsa. Si no le queda ninguna bola, se
  /// pone la baya en la mano.
  void addBerries(int amount) {
    if (amount <= 0) return;
    _berries += amount;
    if (totalBalls == 0) _berrySelected = true;
    notifyListeners();
  }

  /// La bola elegida (la que se lanza si no lleva una baya en la mano).
  PokeBallType get selected => _selected;

  /// De la más reciente a la más antigua.
  List<CapturedPokemon> get captured => List.unmodifiable(_captured.reversed);

  /// Cuántas especies DISTINTAS se han capturado.
  int get speciesCaught => _captured.map((c) => c.pokemon.id).toSet().length;

  /// ¿Ya se capturó alguna vez esta especie?
  bool hasCaught(int pokemonId) =>
      _captured.any((c) => c.pokemon.id == pokemonId);

  /// Mete [amount] bolas en la bolsa (al recogerlas del suelo). Si no
  /// quedaba ninguna de la elegida, se elige la recién recogida (sin
  /// quitarle la baya de la mano si la lleva).
  void addBalls(PokeBallType type, int amount) {
    if (amount <= 0) return;
    _bag[type] = count(type) + amount;
    if (count(_selected) == 0) _selected = type;
    notifyListeners();
  }

  /// Pone en la mano la bola [type].
  void select(PokeBallType type) {
    if (_selected == type && !_berrySelected) return;
    _selected = type;
    _berrySelected = false;
    notifyListeners();
  }

  /// Pone una baya en la mano (si quedan).
  void selectBerry() {
    if (_berrySelected || _berries == 0) return;
    _berrySelected = true;
    notifyListeners();
  }

  /// Lo siguiente de la bolsa que tenga existencias (tecla R): Poké Ball →
  /// Super Ball → Ultra Ball → baya → Poké Ball…
  void selectNext() {
    final types = PokeBallType.values;
    final slots = types.length + 1; // las bolas y la baya
    final current = _berrySelected ? types.length : _selected.index;
    for (var i = 1; i <= slots; i++) {
      final next = (current + i) % slots;
      if (next == types.length) {
        if (_berries > 0) {
          selectBerry();
          return;
        }
      } else if (count(types[next]) > 0) {
        select(types[next]);
        return;
      }
    }
  }

  /// Elige la siguiente BOLA con existencias (al acabarse la elegida).
  void _selectNextBall() {
    final types = PokeBallType.values;
    for (var i = 1; i <= types.length; i++) {
      final next = types[(_selected.index + i) % types.length];
      if (count(next) > 0) {
        _selected = next;
        return;
      }
    }
  }

  /// Saca de la bolsa la bola elegida para lanzarla. Si se acabó, prueba
  /// con otra; devuelve null si no queda ninguna.
  PokeBallType? takeBall() {
    if (count(_selected) == 0) _selectNextBall();
    if (count(_selected) == 0) return null;
    _bag[_selected] = count(_selected) - 1;
    final thrown = _selected;
    if (count(_selected) == 0) _selectNextBall();
    notifyListeners();
    return thrown;
  }

  /// Saca una baya para lanzarla. Si era la última, vuelve a la bola.
  /// Devuelve false si no queda ninguna.
  bool takeBerry() {
    if (_berries == 0) return false;
    _berries--;
    if (_berries == 0) _berrySelected = false;
    notifyListeners();
    return true;
  }

  void registerCapture(Pokemon pokemon, PokeBallType ball) {
    _captured.add(CapturedPokemon(pokemon: pokemon, ball: ball));
    notifyListeners();
  }
}
