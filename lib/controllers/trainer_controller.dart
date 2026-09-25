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
/// bayas), cuál está elegida para lanzar y los Pokémon capturados.
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
  final List<CapturedPokemon> _captured = [];
  PokeBallType _selected = PokeBallType.poke;

  int count(PokeBallType type) => _bag[type]!;

  int get totalBalls => _bag.values.fold(0, (a, b) => a + b);

  /// Bayas en la bolsa (se recogen sacudiendo arbustos).
  int get berries => _berries;

  /// Mete [amount] bayas en la bolsa.
  void addBerries(int amount) {
    if (amount <= 0) return;
    _berries += amount;
    notifyListeners();
  }

  PokeBallType get selected => _selected;

  /// De la más reciente a la más antigua.
  List<CapturedPokemon> get captured => List.unmodifiable(_captured.reversed);

  /// Cuántas especies DISTINTAS se han capturado.
  int get speciesCaught => _captured.map((c) => c.pokemon.id).toSet().length;

  /// ¿Ya se capturó alguna vez esta especie?
  bool hasCaught(int pokemonId) =>
      _captured.any((c) => c.pokemon.id == pokemonId);

  /// Mete [amount] bolas en la bolsa (al recogerlas del suelo). Si no
  /// quedaba ninguna de la elegida, se elige la recién recogida.
  void addBalls(PokeBallType type, int amount) {
    if (amount <= 0) return;
    _bag[type] = count(type) + amount;
    if (count(_selected) == 0) _selected = type;
    notifyListeners();
  }

  void select(PokeBallType type) {
    if (_selected == type) return;
    _selected = type;
    notifyListeners();
  }

  /// Elige la siguiente bola que tenga existencias (tecla/rueda).
  void selectNext() {
    final types = PokeBallType.values;
    for (var i = 1; i <= types.length; i++) {
      final next = types[(_selected.index + i) % types.length];
      if (count(next) > 0) {
        select(next);
        return;
      }
    }
  }

  /// Saca de la bolsa la bola elegida para lanzarla. Si se acabó, prueba
  /// con otra; devuelve null si no queda ninguna.
  PokeBallType? takeBall() {
    if (count(_selected) == 0) selectNext();
    if (count(_selected) == 0) return null;
    _bag[_selected] = count(_selected) - 1;
    final thrown = _selected;
    if (count(_selected) == 0) selectNext();
    notifyListeners();
    return thrown;
  }

  void registerCapture(Pokemon pokemon, PokeBallType ball) {
    _captured.add(CapturedPokemon(pokemon: pokemon, ball: ball));
    notifyListeners();
  }
}
