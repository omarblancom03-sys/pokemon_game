import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../visuals/smoke_visual.dart';
import 'ash_component.dart';

/// El humo: el sitio donde se esconde un Pokémon salvaje.
///
/// Solo avisa de que Ash ha entrado; QUÉ pasa después lo decide el
/// controlador (el juego no sabe nada de Pokémon ni de internet).
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

  /// Callback: función que le pasan para avisar cuando Ash entra.
  final void Function(String smokeId) onAshReached;
  final Component _visual;

  @override
  Future<void> onLoad() async {
    await addAll([
      // passive: el humo no busca colisiones, solo las recibe.
      // isSolid: SIN esto, el círculo cuenta solo como borde; al quedar Ash
      // entero dentro se perdía la colisión y al cruzarlo se disparaba DOS
      // veces el encuentro.
      CircleHitbox(collisionType: CollisionType.passive, isSolid: true),
      _visual,
    ]);
  }

  /// Lo llama Flame cuando dos hitboxes empiezan a tocarse.
  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is AshComponent) onAshReached(id);
  }
}
