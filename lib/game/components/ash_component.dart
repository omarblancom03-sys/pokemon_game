import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../input/movement_input.dart';
import '../visuals/ash_visual.dart';

/// Pregunta al mapa: "¿pueden estar los pies de Ash en este rectángulo?".
typedef CanOccupy = bool Function(Rect feet);

/// El personaje: lee [MovementInput], se mueve a [speed], no sale de
/// [bounds] y no atraviesa obstáculos ([canOccupy]). Solo LÓGICA; el dibujo
/// lo hace su hijo [AshVisual], que se puede cambiar sin tocar esta clase.
class AshComponent extends PositionComponent {
  AshComponent({
    required this.input,
    required this.bounds,
    required this.speed,
    required Vector2 position,
    required Vector2 size,
    AshVisual? visual,
    CanOccupy? canOccupy,
  }) : _visual = visual ?? AshPlaceholderVisual(size: size),
       // Sin mapa (en algunos tests) se puede pisar todo.
       _canOccupy = canOccupy ?? ((_) => true),
       // anchor center: la posición es el centro del personaje.
       super(position: position, size: size, anchor: Anchor.center);

  final MovementInput input;

  /// Tamaño del mundo: Ash se mantiene dentro de (0,0)..bounds.
  final Vector2 bounds;

  /// Píxeles por segundo.
  final double speed;

  final AshVisual _visual;
  final CanOccupy _canOccupy;

  Facing _facing = Facing.down;
  bool _isMoving = false;

  Facing get facing => _facing;

  bool get isMoving => _isMoving;

  /// Los PIES de Ash en coordenadas del mundo: una franja estrecha abajo.
  /// Solo los pies chocan con árboles y casas; la cabeza puede "taparse"
  /// con la copa de un árbol, como en los Pokémon clásicos.
  Rect get feet => Rect.fromLTWH(
    position.x - size.x * 0.3,
    position.y + size.y * 0.5 - size.y * 0.2,
    size.x * 0.6,
    size.y * 0.2,
  );

  /// onLoad: se ejecuta una vez, cuando el componente entra en el juego.
  @override
  Future<void> onLoad() async {
    await addAll([
      // La caja de colisión con el humo cubre la parte baja: se toca el
      // humo "con los pies", como en los Pokémon clásicos.
      RectangleHitbox(
        position: Vector2(size.x * 0.1, size.y * 0.4),
        size: Vector2(size.x * 0.8, size.y * 0.6),
      ),
      _visual,
    ]);
    _updatePriority();
  }

  /// update: lo llama el bucle del juego ~60 veces por segundo.
  /// dt = segundos desde el fotograma anterior.
  @override
  void update(double dt) {
    super.update(dt);
    final direction = input.direction;
    _isMoving = !direction.isZero();

    if (_isMoving) {
      // speed * dt = la misma distancia por segundo en un PC rápido o lento.
      final step = direction..scale(speed * dt);
      // Se prueba cada eje por separado: si choca de frente con un árbol
      // pero se mueve en diagonal, sigue deslizándose por el otro eje.
      _tryMove(step.x, 0);
      _tryMove(0, step.y);
      _clampToBounds();
      // Mira hacia el eje en el que más se mueve (según la tecla, aunque
      // esté chocando: así "empuja" la pared mirándola).
      _facing = direction.x.abs() > direction.y.abs()
          ? (direction.x > 0 ? Facing.right : Facing.left)
          : (direction.y > 0 ? Facing.down : Facing.up);
      _updatePriority();
    }
    // Se le pasa el estado al dibujo (él decide cómo pintarlo).
    _visual.updateState(facing: _facing, isMoving: _isMoving);
  }

  void _tryMove(double dx, double dy) {
    if (dx == 0 && dy == 0) return;
    position.add(Vector2(dx, dy));
    if (!_canOccupy(feet)) position.sub(Vector2(dx, dy));
  }

  // Recorta la posición para no salirse del mapa. Como el ancla está en el
  // centro, hay que descontar media anchura y media altura.
  void _clampToBounds() {
    final half = size / 2;
    position.clamp(half, bounds - half);
  }

  /// Y-sorting: cuanto más abajo están los pies, más "delante" se pinta.
  void _updatePriority() {
    final bottom = (position.y + size.y / 2).round();
    if (priority != bottom) priority = bottom;
  }
}
