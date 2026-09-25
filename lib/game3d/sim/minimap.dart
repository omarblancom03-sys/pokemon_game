import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'wild_pokemon.dart';
import 'world3d_sim.dart';

/// Qué se marca en el minimapa.
enum MinimapMark {
  /// Poké Balls en el suelo para recoger.
  ball,

  /// Pokémon tranquilo.
  calm,

  /// Pokémon que sospecha ("?").
  suspicious,

  /// Pokémon que te ha descubierto ("!").
  alert,

  /// Pokémon agresivo que te ha descubierto: viene a por ti.
  hostile;

  /// La marca de un Pokémon según lo que sabe de ti.
  static MinimapMark forWild(WildPokemon w) {
    if (w.isAlert) {
      return w.temperament == Temperament.aggressive ? hostile : alert;
    }
    return w.isSuspicious ? suspicious : calm;
  }
}

/// Un punto del minimapa: [x] e [y] van de -1 a 1 (x a la derecha, y hacia
/// ABAJO, como en la pantalla); (0, 0) es el jugador.
typedef MinimapMarker = ({MinimapMark mark, double x, double y});

/// CÓMO SE VE EL MUNDO EN EL MINIMAPA (Dart puro): centrado en el jugador y
/// girado con la cámara, de modo que "arriba" es siempre hacia donde mira
/// la cámara (igual que "adelante" en el teclado). Del centro al borde hay
/// [radius] metros.
class MinimapView {
  const MinimapView({
    required this.center,
    required this.yaw,
    this.radius = defaultRadius,
  });

  /// La vista de la simulación ahora mismo.
  factory MinimapView.of(World3DSim sim) =>
      MinimapView(center: sim.player.position, yaw: sim.camera.yaw);

  /// Metros del centro al borde por defecto.
  static const defaultRadius = 26.0;

  final Vector3 center;

  /// El yaw de la cámara (ver OrbitCamera).
  final double yaw;
  final double radius;

  /// Punto del mundo → minimapa. Es un giro de [yaw] en el plano del suelo
  /// (x, z) seguido de una escala: por eso quien pinte el mapa de casillas
  /// puede hacer lo mismo con el lienzo (`rotate(yaw)`).
  ({double x, double y}) project(Vector3 world) {
    final dx = world.x - center.x;
    final dz = world.z - center.z;
    final c = math.cos(yaw);
    final s = math.sin(yaw);
    return (x: (dx * c - dz * s) / radius, y: (dx * s + dz * c) / radius);
  }

  /// ¿Cae dentro del círculo?
  static bool inside(({double x, double y}) p) => p.x * p.x + p.y * p.y <= 1;

  /// Ángulo en pantalla (rad; 0 = arriba, sentido horario) de algo que mira
  /// hacia [facing] (0 = +Z, como el jugador y los Pokémon).
  double screenAngle(double facing) => math.pi - facing + yaw;

  /// Hacia dónde queda el norte del mapa (−Z, la fila 0) en el borde.
  double get northAngle => screenAngle(math.pi);

  /// Bolas en el suelo y Pokémon libres que caen dentro del círculo.
  List<MinimapMarker> markers(World3DSim sim) {
    final out = <MinimapMarker>[];
    void add(MinimapMark mark, Vector3 at) {
      final p = project(at);
      if (inside(p)) out.add((mark: mark, x: p.x, y: p.y));
    }

    for (final item in sim.fieldItems.items) {
      add(MinimapMark.ball, item.position);
    }
    for (final w in sim.wild) {
      // Los escondidos no salen: hay que buscarlos por la hierba que se agita.
      if (w.isFree && !w.hidden) add(MinimapMark.forWild(w), w.position);
    }
    return out;
  }
}
