import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

/// Free placeholder for the "Pokémon here" smoke: pulsing grey puffs.
/// Replace with a sprite animation by passing another component as the
/// `visual` of `SmokeComponent`.
class SmokePlaceholderVisual extends PositionComponent {
  SmokePlaceholderVisual({required Vector2 size}) : super(size: size);

  static final _puffPaint = Paint()..color = const Color(0xAAE0E0E0);
  static final _corePaint = Paint()..color = const Color(0xCCBDBDBD);

  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final r = size.x / 2;
    for (var i = 0; i < 5; i++) {
      final angle = _time * 1.5 + i * 2 * pi / 5;
      final pulse = 0.35 + 0.1 * sin(_time * 3 + i);
      canvas.drawCircle(
        center + Offset(cos(angle), sin(angle)) * r * 0.45,
        r * pulse,
        _puffPaint,
      );
    }
    canvas.drawCircle(center, r * (0.4 + 0.05 * sin(_time * 4)), _corePaint);
  }
}
