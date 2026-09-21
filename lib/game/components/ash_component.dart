import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../input/movement_input.dart';
import '../visuals/ash_visual.dart';

/// El personaje: lee [MovementInput], se mueve a [speed] y no sale de
/// [bounds]. Solo LÓGICA; el dibujo lo hace su hijo [AshVisual], que se
/// puede cambiar por sprites sin tocar esta clase.
class AshComponent extends PositionComponent {
  AshComponent({
    required this.input,
    required this.bounds,
    required this.speed,
    required Vector2 position,
    required Vector2 size,
    AshVisual? visual,
  }) : _visual = visual ?? AshPlaceholderVisual(size: size),
       // anchor center: la posición es el centro del personaje.
       super(position: position, size: size, anchor: Anchor.center);

  final MovementInput input;

  /// Tamaño del mundo: Ash se mantiene dentro de (0,0)..bounds.
  final Vector2 bounds;

  /// Píxeles por segundo.
  final double speed;

  final AshVisual _visual;

  Facing _facing = Facing.down;
  bool _isMoving = false;

  Facing get facing => _facing;

  bool get isMoving => _isMoving;

  /// onLoad: se ejecuta una vez, cuando el componente entra en el juego.
  @override
  Future<void> onLoad() async {
    await addAll([
      // La caja de colisión cubre solo la mitad inferior: se toca el humo
      // "con los pies", como en los Pokémon clásicos.
      RectangleHitbox(
        position: Vector2(size.x * 0.1, size.y * 0.4),
        size: Vector2(size.x * 0.8, size.y * 0.6),
      ),
      _visual,
    ]);
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
      position.add(direction..scale(speed * dt));
      _clampToBounds();
      // Mira hacia el eje en el que más se mueve.
      _facing = direction.x.abs() > direction.y.abs()
          ? (direction.x > 0 ? Facing.right : Facing.left)
          : (direction.y > 0 ? Facing.down : Facing.up);
    }
    // Se le pasa el estado al dibujo (él decide cómo pintarlo).
    _visual.updateState(facing: _facing, isMoving: _isMoving);
  }

  // Recorta la posición para no salirse del mapa. Como el ancla está en el
  // centro, hay que descontar media anchura y media altura.
  void _clampToBounds() {
    final half = size / 2;
    position.clamp(half, bounds - half);
  }
}
