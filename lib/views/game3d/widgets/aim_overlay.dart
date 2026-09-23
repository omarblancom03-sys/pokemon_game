import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../game3d/sim/world3d_sim.dart';

/// Capa 2D sobre el mundo 3D para APUNTAR: la mira en el centro al apuntar
/// y, sobre el Pokémon fijado, un anillo con la probabilidad de captura
/// (verde = fácil, rojo = difícil). Sin apuntar, solo una flechita encima
/// del Pokémon al que iría la bola.
///
/// Se repinta en cada fotograma (el objetivo se mueve) leyendo el estado de
/// la simulación; no cambia nada de ella.
class AimOverlay extends StatefulWidget {
  const AimOverlay({super.key, required this.sim});

  final World3DSim sim;

  @override
  State<AimOverlay> createState() => _AimOverlayState();
}

class _AimOverlayState extends State<AimOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _frame.value++)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: Size.infinite,
      painter: _AimPainter(widget.sim, repaint: _frame),
    ),
  );
}

class _AimPainter extends CustomPainter {
  _AimPainter(this.sim, {super.repaint});

  final World3DSim sim;

  /// Color según la probabilidad: rojo (difícil) → amarillo → verde.
  static Color chanceColor(double chance) => Color.lerp(
    Color.lerp(Colors.redAccent, Colors.amberAccent, math.min(1, chance * 3))!,
    Colors.lightGreenAccent,
    ((chance - 0.33) / 0.5).clamp(0.0, 1.0),
  )!;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final aim = sim.camera.aim;
    final center = size.center(Offset.zero);
    if (aim > 0.05) _paintCrosshair(canvas, center, aim);

    final target = sim.lockedTarget;
    if (target == null) return;
    final feet = sim.player.position;
    final aspect = size.width / size.height;
    final base = sim.camera.project(target.position, feet, aspect: aspect);
    final top = sim.camera.project(
      target.position..y = target.displayHeight,
      feet,
      aspect: aspect,
    );
    if (base == null || top == null) return;
    Offset toScreen(({double x, double y}) p) =>
        Offset((p.x + 1) / 2 * size.width, (1 - p.y) / 2 * size.height);
    final b = toScreen(base);
    final t = toScreen(top);

    if (aim < 0.5) {
      _paintArrow(canvas, t + const Offset(0, -10));
      return;
    }
    final chance = sim.lockedChance;
    final color = chance == null ? Colors.white : chanceColor(chance);
    final mid = Offset.lerp(b, t, 0.5)!;
    final radius = math.max(18.0, (b.dy - t.dy).abs() * 0.55);
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    // Cuatro arcos que giran despacio: "objetivo fijado".
    final spin = sim.time * 1.5;
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: mid, radius: radius),
        spin + i * math.pi / 2,
        math.pi / 3,
        false,
        ring,
      );
    }
    if (chance != null) {
      final text = TextPainter(
        text: TextSpan(
          text: '${(chance * 100).round()} %',
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            shadows: const [Shadow(blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, mid + Offset(radius + 6, -text.height / 2));
    }
  }

  void _paintCrosshair(Canvas canvas, Offset c, double aim) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85 * aim)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, 12, paint);
    for (final d in const [
      Offset(1, 0),
      Offset(-1, 0),
      Offset(0, 1),
      Offset(0, -1),
    ]) {
      canvas.drawLine(c + d * 16, c + d * 24, paint);
    }
    canvas.drawCircle(c, 2, paint..style = PaintingStyle.fill);
  }

  void _paintArrow(Canvas canvas, Offset tip) {
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 8, tip.dy - 12)
      ..lineTo(tip.dx + 8, tip.dy - 12)
      ..close();
    canvas
      ..drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.85))
      ..drawPath(
        path,
        Paint()
          ..color = Colors.black45
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  @override
  bool shouldRepaint(_AimPainter old) => old.sim != sim;
}
