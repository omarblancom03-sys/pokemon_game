import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../../models/pokemon.dart';

/// Un Pokémon salvaje VISIBLE en el mundo 3D (estilo Leyendas/Escarlata):
/// deambula por la hierba alta dando saltitos; si el jugador lo toca,
/// empieza el encuentro.
class WildPokemon {
  WildPokemon({
    required this.id,
    required this.pokemon,
    required Vector3 position,
    this.facing = 0,
  }) : _position = position.clone();

  final String id;
  final Pokemon pokemon;

  Vector3 _position;
  Vector3 get position => _position.clone();
  set position(Vector3 value) => _position = value.clone();

  /// Hacia dónde mira (0 = +Z), como el jugador.
  double facing;

  /// Punto al que se dirige, o null si está parado.
  Vector3? target;

  /// Segundos que le quedan de descanso antes de elegir otro destino.
  double idleTime = 0;

  /// Metros recorridos: marca el ritmo de los saltitos.
  double distanceMoved = 0;

  /// Segundos desde que apareció (para la animación de entrada).
  double age = 0;

  /// Ya disparó su encuentro: no vuelve a dispararlo.
  bool engaged = false;

  /// Metros por segundo al deambular.
  static const wanderSpeed = 1.3;

  /// Altura del dibujo en metros, a partir de la altura real del Pokémon
  /// (PokeAPI la da en decímetros). Se exagera un poco y se limita: un
  /// Pikachu de 0,4 m quedaría escondido en la hierba alta.
  double get displayHeight =>
      (pokemon.height / 10 * 1.3 + 0.5).clamp(1.1, 3.2).toDouble();

  /// Distancia (m) a la que el jugador "lo toca".
  double get contactRadius => 0.55 + displayHeight * 0.2;

  /// Altura del saltito ahora mismo (0 cuando está parado).
  double get hopHeight =>
      target == null ? 0 : (math.sin(distanceMoved * 5).abs() * 0.18);
}
