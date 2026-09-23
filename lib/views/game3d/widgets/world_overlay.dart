import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:vector_math/vector_math.dart' show Vector3;

import '../../../game3d/sim/wild_pokemon.dart';
import '../../../game3d/sim/world3d_sim.dart';

/// Capa 2D sobre el mundo 3D:
///  - APUNTAR: la mira en el centro y, sobre el Pokémon fijado, un anillo
///    con la probabilidad de captura (verde = fácil, rojo = difícil). Sin
///    apuntar, solo una flechita encima del Pokémon al que iría la bola.
///  - SIGILO: "?" sobre los Pokémon que sospechan y "!" sobre los que te
///    han descubierto (rojo si van a por ti), y abajo cómo te notan
///    (escondido, agachado, haciendo ruido).
///
/// Se repinta en cada fotograma leyendo el estado de la simulación; no
/// cambia nada de ella.
class WorldOverlay extends StatefulWidget {
  const WorldOverlay({super.key, required this.sim});

  final World3DSim sim;

  @override
  State<WorldOverlay> createState() => _WorldOverlayState();
}

class _WorldOverlayState extends State<WorldOverlay>
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
      painter: _WorldPainter(widget.sim, repaint: _frame),
    ),
  );
}

class _WorldPainter extends CustomPainter {
  _WorldPainter(this.sim, {super.repaint});

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
    _paintStealth(canvas, size);

    final feet = sim.player.position;
    final aspect = size.width / size.height;
    Offset? onScreen(Vector3 world) {
      final p = sim.camera.project(world, feet, aspect: aspect);
      if (p == null) return null;
      return Offset((p.x + 1) / 2 * size.width, (1 - p.y) / 2 * size.height);
    }

    for (final w in sim.wild) {
      if (!w.isFree || (!w.isAlert && !w.isSuspicious)) continue;
      final head = onScreen(w.position..y = w.displayHeight + 0.35);
      if (head != null) _paintMark(canvas, head, w);
    }

    final target = sim.lockedTarget;
    if (target == null) return;
    final b = onScreen(target.position);
    final t = onScreen(target.position..y = target.displayHeight);
    if (b == null || t == null) return;

    if (aim < 0.5) {
      if (!target.isAlert && !target.isSuspicious) {
        _paintArrow(canvas, t + const Offset(0, -10));
      }
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

  /// "?" (sospecha) o "!" (te ha visto; rojo si va a por ti) en un bocadillo.
  void _paintMark(Canvas canvas, Offset at, WildPokemon w) {
    final alert = w.isAlert;
    final danger = alert && w.temperament == Temperament.aggressive;
    final fill = danger
        ? Colors.redAccent
        : alert
        ? Colors.amberAccent
        : Colors.white;
    // Crece un poco mientras sube la sospecha.
    final r = alert ? 13.0 : 9 + 4 * w.awareness;
    canvas
      ..drawCircle(at, r, Paint()..color = fill)
      ..drawCircle(
        at,
        r,
        Paint()
          ..color = Colors.black54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    final text = TextPainter(
      text: TextSpan(
        text: alert ? '!' : '?',
        style: TextStyle(
          color: danger ? Colors.white : Colors.black87,
          fontSize: r * 1.4,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
  }

  /// Abajo en el centro: cómo te notan ahora mismo.
  void _paintStealth(Canvas canvas, Size size) {
    final (label, color) = switch (sim.stealth) {
      PlayerStealth.hidden => ('Escondido en la hierba', Colors.greenAccent),
      PlayerStealth.crouching => ('Agachado', Colors.tealAccent),
      PlayerStealth.noisy => ('¡Haces ruido!', Colors.orangeAccent),
      PlayerStealth.normal => (null, Colors.white),
    };
    if (label == null) return;
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = Rect.fromCenter(
      center: Offset(size.width / 2, size.height - 34),
      width: text.width + 24,
      height: text.height + 10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(14)),
      Paint()..color = Colors.black54,
    );
    text.paint(canvas, box.center - Offset(text.width / 2, text.height / 2));
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
  bool shouldRepaint(_WorldPainter old) => old.sim != sim;
}
