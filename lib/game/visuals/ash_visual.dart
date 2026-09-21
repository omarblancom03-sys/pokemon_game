import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

/// Direction the character is looking at.
enum Facing { up, down, left, right }

/// Appearance of Ash. `AshComponent` owns position, movement and hitbox and
/// only reports state here, so a sprite-sheet implementation (e.g. a
/// `SpriteAnimationGroupComponent` keyed by facing/moving) can replace the
/// placeholder without touching logic, controllers or services.
abstract interface class AshVisual implements Component {
  void updateState({required Facing facing, required bool isMoving});
}

/// Free placeholder: coloured rectangles with a facing indicator and a small
/// walking bob.
class AshPlaceholderVisual extends PositionComponent implements AshVisual {
  AshPlaceholderVisual({required Vector2 size}) : super(size: size);

  static final _bodyPaint = Paint()..color = const Color(0xFF2B59C3);
  static final _capPaint = Paint()..color = const Color(0xFFE3350D);
  static final _facePaint = Paint()..color = const Color(0xFFF6D7B0);
  static final _eyePaint = Paint()..color = const Color(0xFF1B1B1B);
  static final _shadowPaint = Paint()..color = const Color(0x55000000);

  Facing _facing = Facing.down;
  bool _isMoving = false;
  double _time = 0;

  @override
  void updateState({required Facing facing, required bool isMoving}) {
    _facing = facing;
    _isMoving = isMoving;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time = _isMoving ? _time + dt : 0;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final bob = _isMoving ? sin(_time * 16).abs() * -3 : 0.0;

    canvas.drawOval(
      Rect.fromLTWH(w * 0.1, h * 0.85, w * 0.8, h * 0.2),
      _shadowPaint,
    );
    canvas.save();
    canvas.translate(0, bob);

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.15, h * 0.45, w * 0.7, h * 0.5),
      const Radius.circular(4),
    );
    canvas.drawRRect(body, _bodyPaint);
    canvas.drawCircle(Offset(w / 2, h * 0.35), w * 0.3, _facePaint);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.18, h * 0.05, w * 0.64, h * 0.18),
      _capPaint,
    );

    // Eyes show where Ash is looking; hidden when facing away.
    final eyeY = h * 0.36;
    switch (_facing) {
      case Facing.down:
        canvas.drawCircle(Offset(w * 0.4, eyeY), 2, _eyePaint);
        canvas.drawCircle(Offset(w * 0.6, eyeY), 2, _eyePaint);
      case Facing.left:
        canvas.drawCircle(Offset(w * 0.3, eyeY), 2, _eyePaint);
      case Facing.right:
        canvas.drawCircle(Offset(w * 0.7, eyeY), 2, _eyePaint);
      case Facing.up:
        canvas.drawRect(
          Rect.fromLTWH(w * 0.2, h * 0.2, w * 0.6, h * 0.12),
          _capPaint,
        );
    }
    canvas.restore();
  }
}
