import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

/// Dibujo provisional del humo donde se esconde un Pokémon: cinco nubecillas
/// grises que giran y laten. Para usar sprites basta con pasar otro
/// componente como `visual` de SmokeComponent.
class SmokePlaceholderVisual extends PositionComponent {
  SmokePlaceholderVisual({required Vector2 size}) : super(size: size);

  static final _puffPaint = Paint()..color = const Color(0xAAE0E0E0);
  static final _corePaint = Paint()..color = const Color(0xCCBDBDBD);

  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt; // reloj para animar
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final r = size.x / 2;
    // Cinco nubes repartidas en círculo (2*pi / 5) que giran con el tiempo.
    for (var i = 0; i < 5; i++) {
      final angle = _time * 1.5 + i * 2 * pi / 5;
      final pulse = 0.35 + 0.1 * sin(_time * 3 + i); // laten
      canvas.drawCircle(
        center + Offset(cos(angle), sin(angle)) * r * 0.45,
        r * pulse,
        _puffPaint,
      );
    }
    // Núcleo central, también latiendo.
    canvas.drawCircle(center, r * (0.4 + 0.05 * sin(_time * 4)), _corePaint);
  }
}
