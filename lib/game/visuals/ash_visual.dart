import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

/// Hacia dónde mira el personaje.
enum Facing { up, down, left, right }

/// CONTRATO del aspecto de Ash.
///
/// AshComponent se ocupa de la posición, el movimiento y la hitbox, y solo
/// informa aquí del estado. Por eso se puede sustituir este dibujo por una
/// animación con sprites sin tocar lógica, controladores ni servicios.
abstract interface class AshVisual implements Component {
  void updateState({required Facing facing, required bool isMoving});
}

/// Dibujo provisional (placeholder): figuras de colores con gorra, ojos que
/// miran hacia donde anda y un pequeño rebote al caminar.
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

  /// Lo llama AshComponent en cada fotograma.
  @override
  void updateState({required Facing facing, required bool isMoving}) {
    _facing = facing;
    _isMoving = isMoving;
  }

  @override
  void update(double dt) {
    super.update(dt);
    // El reloj solo corre mientras anda: así el rebote se para al parar.
    _time = _isMoving ? _time + dt : 0;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    // sin() da un vaivén suave: el "bote" de caminar.
    final bob = _isMoving ? sin(_time * 16).abs() * -3 : 0.0;

    // Sombra en el suelo.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.1, h * 0.85, w * 0.8, h * 0.2),
      _shadowPaint,
    );
    canvas.save();
    canvas.translate(0, bob);

    // Cuerpo, cara y gorra.
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

    // Los ojos indican la dirección; de espaldas no se ven.
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
