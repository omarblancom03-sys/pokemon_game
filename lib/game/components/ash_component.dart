import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../input/movement_input.dart';
import '../visuals/ash_visual.dart';

/// Player character logic: reads [MovementInput], moves at [speed] and stays
/// inside [bounds]. Rendering is delegated to an [AshVisual] child.
class AshComponent extends PositionComponent {
  AshComponent({
    required this.input,
    required this.bounds,
    required this.speed,
    required Vector2 position,
    required Vector2 size,
    AshVisual? visual,
  }) : _visual = visual ?? AshPlaceholderVisual(size: size),
       super(position: position, size: size, anchor: Anchor.center);

  final MovementInput input;

  /// World size; Ash's whole body is kept within `(0,0)..bounds`.
  final Vector2 bounds;

  /// Pixels per second.
  final double speed;

  final AshVisual _visual;

  Facing _facing = Facing.down;
  bool _isMoving = false;

  Facing get facing => _facing;

  bool get isMoving => _isMoving;

  @override
  Future<void> onLoad() async {
    // Hitbox covers the lower body so touching a smoke "with the feet" counts.
    await addAll([
      RectangleHitbox(
        position: Vector2(size.x * 0.1, size.y * 0.4),
        size: Vector2(size.x * 0.8, size.y * 0.6),
      ),
      _visual,
    ]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final direction = input.direction;
    _isMoving = !direction.isZero();

    if (_isMoving) {
      position.add(direction..scale(speed * dt));
      _clampToBounds();
      _facing = direction.x.abs() > direction.y.abs()
          ? (direction.x > 0 ? Facing.right : Facing.left)
          : (direction.y > 0 ? Facing.down : Facing.up);
    }
    _visual.updateState(facing: _facing, isMoving: _isMoving);
  }

  void _clampToBounds() {
    final half = size / 2;
    position.clamp(half, bounds - half);
  }
}
