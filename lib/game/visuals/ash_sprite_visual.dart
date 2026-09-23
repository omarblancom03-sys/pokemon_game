import 'dart:ui';

import 'package:flame/components.dart';

import '../art/game_art.dart';
import 'ash_visual.dart';

/// Estado de la animación: hacia dónde mira y si camina. Es un "record":
/// dos valores iguales cuentan como la misma clave del mapa de animaciones.
typedef AshPose = ({Facing facing, bool moving});

/// Ash con SPRITES: 4 direcciones x (quieto / caminando). Cumple el mismo
/// contrato [AshVisual] que el dibujo provisional, así que AshComponent no
/// nota el cambio.
class AshSpriteVisual extends SpriteAnimationGroupComponent<AshPose>
    implements AshVisual {
  AshSpriteVisual({required GameArt art, required Vector2 size})
    : super(size: size, animations: _buildAnimations(art), current: _idleDown);

  static const AshPose _idleDown = (facing: Facing.down, moving: false);

  /// Orden de las filas en ash.png.
  static const _rows = [Facing.down, Facing.left, Facing.right, Facing.up];

  static final _shadowPaint = Paint()..color = const Color(0x40000000);

  static Map<AshPose, SpriteAnimation> _buildAnimations(GameArt art) {
    const frame = GameArt.ashFramePixels;
    Sprite frameAt(int row, int col) => Sprite(
      art.ashSheet,
      srcPosition: Vector2(col * frame.width, row * frame.height),
      srcSize: Vector2(frame.width, frame.height),
    );

    return {
      for (final (row, facing) in _rows.indexed) ...{
        // Quieto: el primer paso, fijo.
        (facing: facing, moving: false): SpriteAnimation.spriteList([
          frameAt(row, 0),
        ], stepTime: 1),
        // Caminando: los 6 pasos en bucle, 0.1 s cada uno.
        (facing: facing, moving: true): SpriteAnimation.spriteList([
          for (var col = 0; col < GameArt.ashFramesPerRow; col++)
            frameAt(row, col),
        ], stepTime: 0.1),
      },
    };
  }

  @override
  void updateState({required Facing facing, required bool isMoving}) {
    final pose = (facing: facing, moving: isMoving);
    // Solo se cambia si es distinto: si no, la animación se reiniciaría en
    // cada fotograma y parecería congelada.
    if (current != pose) current = pose;
  }

  @override
  void render(Canvas canvas) {
    // Sombra ovalada a los pies, antes del sprite para que quede debajo.
    canvas.drawOval(
      Rect.fromLTWH(size.x * 0.12, size.y * 0.86, size.x * 0.76, size.y * 0.16),
      _shadowPaint,
    );
    super.render(canvas);
  }
}
