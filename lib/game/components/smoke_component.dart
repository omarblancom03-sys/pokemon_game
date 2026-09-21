import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../visuals/smoke_visual.dart';
import 'ash_component.dart';

/// A spot where a wild Pokémon hides. Reports when Ash enters it; deciding
/// what happens next is the controller's job.
class SmokeComponent extends PositionComponent with CollisionCallbacks {
  SmokeComponent({
    required this.id,
    required Vector2 position,
    required double radius,
    required this.onAshReached,
    Component? visual,
  }) : _visual =
           visual ?? SmokePlaceholderVisual(size: Vector2.all(radius * 2)),
       super(
         position: position,
         size: Vector2.all(radius * 2),
         anchor: Anchor.center,
       );

  final String id;
  final void Function(String smokeId) onAshReached;
  final Component _visual;

  @override
  Future<void> onLoad() async {
    await addAll([
      // Solid: otherwise Ash's hitbox being fully inside the circle counts as
      // "no collision" and crossing the smoke would trigger it twice.
      CircleHitbox(collisionType: CollisionType.passive, isSolid: true),
      _visual,
    ]);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is AshComponent) onAshReached(id);
  }
}
