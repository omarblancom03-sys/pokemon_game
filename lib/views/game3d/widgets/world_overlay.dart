import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:vector_math/vector_math.dart' show Vector3;

import '../../../controllers/capture/capture_calculator.dart';
import '../../../game3d/sim/wild_pokemon.dart';
import '../../../game3d/sim/world3d_sim.dart';
import '../../common/pokemon_formatters.dart';

/// Capa 2D sobre el mundo 3D:
///  - APUNTAR: la mira en el centro y, sobre el Pokémon fijado, un anillo
///    con la probabilidad de captura (verde = fácil, rojo = difícil). Sin
///    apuntar, solo una flechita encima del Pokémon al que iría la bola.
///  - SIGILO: "?" sobre los Pokémon que sospechan y "!" sobre los que te
///    han descubierto (rojo si van a por ti), y abajo cómo te notan
///    (escondido, agachado, haciendo ruido).
///  - POKÉDEX: una Poké Ball pequeña sobre los Pokémon cercanos cuya
///    especie ya tienes; al apuntar, el nombre del fijado ("¡Nuevo!" si no
///    lo tienes aún).
///  - BAYAS: una baya en un bocadillo sobre los Pokémon que van a por una
///    baya del suelo (late con cada mordisco mientras se la comen).
///  - AL GOLPEAR: sobre el Pokémon, qué bonus ha tenido el tiro ("¡No te
///    vio!", "¡Por la espalda!", "¡Está comiendo!"), que sube y se
///    desvanece. Si es una captura crítica, también lo dice, y la calidad
///    del tiro ("¡Excelente! ×2").
///  - EL ARO: dentro del anillo del fijado, un aro que se encoge (su color
///    dice qué tiro saldría si lanzas ya).
///
/// Se repinta en cada fotograma leyendo el estado de la simulación; no
/// cambia nada de ella.
class WorldOverlay extends StatefulWidget {
  const WorldOverlay({super.key, required this.sim, this.isCaught = _never});

  final World3DSim sim;

  /// ¿Ya tiene el entrenador esta especie? (por número de Pokédex).
  final bool Function(int pokemonId) isCaught;

  static bool _never(int _) => false;

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
      painter: _WorldPainter(
        widget.sim,
        isCaught: widget.isCaught,
        repaint: _frame,
      ),
    ),
  );
}

class _WorldPainter extends CustomPainter {
  _WorldPainter(this.sim, {required this.isCaught, super.repaint});

  final World3DSim sim;
  final bool Function(int pokemonId) isCaught;

  /// Color según la probabilidad: rojo (difícil) → amarillo → verde.
  static Color chanceColor(double chance) => Color.lerp(
    Color.lerp(Colors.redAccent, Colors.amberAccent, math.min(1, chance * 3))!,
    Colors.lightGreenAccent,
    ((chance - 0.33) / 0.5).clamp(0.0, 1.0),
  )!;

  /// Color del aro que se encoge según el tiro que daría: blanco (nada),
  /// azul (¡Bien!), violeta (¡Genial!) y dorado (¡Excelente!).
  static Color throwColor(ThrowQuality quality) => switch (quality) {
    ThrowQuality.none => Colors.white70,
    ThrowQuality.nice => const Color(0xFF80D8FF),
    ThrowQuality.great => const Color(0xFFB388FF),
    ThrowQuality.excellent => const Color(0xFFFFD54F),
  };

  static String throwLabel(ThrowQuality quality) => switch (quality) {
    ThrowQuality.none => '',
    ThrowQuality.nice => '¡Bien!',
    ThrowQuality.great => '¡Genial!',
    ThrowQuality.excellent => '¡Excelente!',
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Mientras la cámara de captura enseña la bola no se apunta: sin mira.
    final aim = sim.captureCam.engaged ? 0.0 : sim.camera.aim;
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

    for (final ball in sim.balls) {
      _paintHitBonus(canvas, ball, onScreen);
    }

    for (final w in sim.wild) {
      if (!w.isFree) continue;
      final marked = w.isAlert || w.isSuspicious;
      final baited = w.bait != null && !w.isAlert;
      if (!marked && !baited) continue;
      final head = onScreen(w.position..y = w.displayHeight + 0.35);
      if (head == null) continue;
      if (marked) _paintMark(canvas, head, w);
      // Va a por una baya (o se la está comiendo): una baya en un bocadillo.
      if (baited) {
        _paintBerryBubble(
          canvas,
          marked ? head - const Offset(24, 0) : head,
          w.munch,
        );
      }
    }
    // Especie ya capturada: una Poké Ball junto a la cabeza (a la derecha
    // del "?" / "!" si lo hay).
    // Al apuntar, el fijado ya lo dice junto a su nombre.
    final named = aim >= 0.5 ? sim.lockedTarget : null;
    for (final w in sim.visibleWildNearby) {
      if (w == named || !isCaught(w.pokemon.id)) continue;
      final head = onScreen(w.position..y = w.displayHeight + 0.35);
      if (head == null) continue;
      final marked = w.isAlert || w.isSuspicious;
      _paintCaughtIcon(canvas, marked ? head + const Offset(22, 0) : head);
    }
    // Variocolor: destellos a ratos (y uno grande al verlo por primera vez).
    for (final w in sim.visibleWildNearby) {
      if (w.shiny) _paintShinySparkles(canvas, w, onScreen);
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
    // El aro que se encoge: lanzar cuando es pequeño da un tiro mejor.
    final throwRing = sim.throwRing;
    if (throwRing.target == target.id) {
      final quality = throwRing.quality;
      canvas.drawCircle(
        mid,
        radius * throwRing.size,
        Paint()
          ..color = throwColor(quality)
          ..style = PaintingStyle.stroke
          ..strokeWidth = quality == ThrowQuality.excellent ? 4 : 2.5,
      );
    }
    _paintLockName(canvas, mid, radius, target);
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

  /// Cada cuánto (s) brilla un variocolor y cuánto dura cada destello.
  static const _shinyPeriod = 2.6;
  static const _sparkleSeconds = 0.8;

  /// Duración del destello grande al ver un variocolor por primera vez.
  static const _spottedSparkleSeconds = 1.2;

  /// Estrellitas de cuatro puntas alrededor de un variocolor: cada
  /// [_shinyPeriod] s un corro que se abre y se apaga; justo al verlo, uno
  /// más grande y con más estrellas.
  void _paintShinySparkles(
    Canvas canvas,
    WildPokemon w,
    Offset? Function(Vector3 world) onScreen,
  ) {
    final center = onScreen(w.position..y = w.displayHeight * 0.55);
    final top = onScreen(w.position..y = w.displayHeight);
    if (center == null || top == null) return;
    final spottedAt = w.shinySpottedAt;
    final sinceSpotted = spottedAt == null ? null : sim.time - spottedAt;
    final big = sinceSpotted != null && sinceSpotted < _spottedSparkleSeconds;
    // Cada uno a su ritmo (no brillan todos a la vez).
    final offset = (w.id.hashCode % 10) * 0.37;
    final t = big
        ? sinceSpotted / _spottedSparkleSeconds
        : ((sim.time + offset) % _shinyPeriod) / _sparkleSeconds;
    if (t > 1) return;
    final alpha = math.sin(t * math.pi);
    final reach = math.max(16.0, (center.dy - top.dy).abs() * 1.4);
    final radius = reach * (0.55 + 0.6 * t) * (big ? 1.3 : 1);
    final count = big ? 8 : 4;
    final paint = Paint()
      ..color = const Color(0xFFFFF59D).withValues(alpha: alpha);
    for (var i = 0; i < count; i++) {
      final a = i * 2 * math.pi / count + offset + t * 0.8;
      final at = center + Offset(math.cos(a), math.sin(a)) * radius;
      _paintStar(canvas, at, (big ? 10 : 7) * (1 - 0.3 * t), paint);
    }
  }

  /// Estrella de cuatro puntas (un destello) de radio [r].
  static void _paintStar(Canvas canvas, Offset at, double r, Paint paint) {
    final k = r * 0.22;
    canvas.drawPath(
      Path()
        ..moveTo(at.dx, at.dy - r)
        ..lineTo(at.dx + k, at.dy - k)
        ..lineTo(at.dx + r, at.dy)
        ..lineTo(at.dx + k, at.dy + k)
        ..lineTo(at.dx, at.dy + r)
        ..lineTo(at.dx - k, at.dy + k)
        ..lineTo(at.dx - r, at.dy)
        ..lineTo(at.dx - k, at.dy - k)
        ..close(),
      paint,
    );
  }

  /// Una Poké Ball pequeña: "esta especie ya la tienes".
  void _paintCaughtIcon(Canvas canvas, Offset at) {
    const r = 7.0;
    final rect = Rect.fromCircle(center: at, radius: r);
    canvas
      ..drawArc(rect, math.pi, math.pi, true, Paint()..color = Colors.red)
      ..drawArc(rect, 0, math.pi, true, Paint()..color = Colors.white)
      ..drawLine(
        at - const Offset(r, 0),
        at + const Offset(r, 0),
        Paint()
          ..color = Colors.black87
          ..strokeWidth = 1.6,
      )
      ..drawCircle(
        at,
        r,
        Paint()
          ..color = Colors.black87
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      )
      ..drawCircle(at, 2.2, Paint()..color = Colors.white)
      ..drawCircle(
        at,
        2.2,
        Paint()
          ..color = Colors.black87
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  /// Encima del anillo de la mira (debajo si no cabe arriba): el nombre del
  /// Pokémon fijado y, si aún no tienes su especie, "¡Nuevo!" (si ya la
  /// tienes, su Poké Ball).
  void _paintLockName(
    Canvas canvas,
    Offset ringCenter,
    double radius,
    WildPokemon w,
  ) {
    final caught = isCaught(w.pokemon.id);
    final name = TextPainter(
      text: TextSpan(
        text: displayName(w.pokemon.name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final badge = caught
        ? null
        : (TextPainter(
            text: const TextSpan(
              text: '¡Nuevo!',
              style: TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout());
    const gap = 6.0;
    final extra = caught ? 14.0 + gap : badge!.width + 10 + gap;
    final width = name.width + extra;
    final height = name.height + 6;
    final above = ringCenter.dy - radius - 10 - height;
    final top = above >= 6 ? above : ringCenter.dy + radius + 10;
    final box = Rect.fromLTWH(
      ringCenter.dx - width / 2 - 8,
      top,
      width + 16,
      height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(10)),
      Paint()..color = Colors.black54,
    );
    final x = box.left + 8;
    final cy = box.center.dy;
    name.paint(canvas, Offset(x, cy - name.height / 2));
    final after = x + name.width + gap;
    if (badge == null) {
      _paintCaughtIcon(canvas, Offset(after + 7, cy));
    } else {
      final pill = Rect.fromLTWH(
        after,
        cy - badge.height / 2 - 1,
        badge.width + 10,
        badge.height + 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(pill, const Radius.circular(8)),
        Paint()..color = const Color(0xFFFFD54F),
      );
      badge.paint(canvas, Offset(after + 5, cy - badge.height / 2));
    }
  }

  /// Segundos que se ve el texto del bonus tras el golpe.
  static const _bonusSeconds = 1.6;

  /// Multiplicador en español: 2 → "2", 1.5 → "1,5".
  static String _factor(double f) => f == f.roundToDouble()
      ? f.toInt().toString()
      : f.toString().replaceAll('.', ',');

  /// El bonus del golpe sobre el Pokémon: sube y se desvanece.
  void _paintHitBonus(
    Canvas canvas,
    ThrownBall ball,
    Offset? Function(Vector3 world) onScreen,
  ) {
    final hit = ball.hit;
    final since = ball.sinceHit;
    final target = ball.target;
    if (hit == null || since == null || target == null) return;
    if (since > _bonusSeconds) return;
    final lines = [
      if (ball.result?.critical ?? false)
        ('¡Captura crítica!', const Color(0xFFFFD54F)),
      if (ball.quality != ThrowQuality.none)
        (
          '${throwLabel(ball.quality)} ×${_factor(ball.quality.bonus)}',
          throwColor(ball.quality),
        ),
      if (hit.unaware)
        (
          '¡No te vio! ×${_factor(CaptureCalculator.unawareBonus)}',
          Colors.amberAccent,
        ),
      if (hit.fromBehind)
        (
          '¡Por la espalda! ×${_factor(CaptureCalculator.backStrikeBonus)}',
          Colors.lightGreenAccent,
        ),
      if (hit.eating)
        (
          '¡Está comiendo! ×${_factor(CaptureCalculator.eatingBonus)}',
          Colors.pinkAccent,
        ),
    ];
    if (lines.isEmpty) return;
    // Donde golpeó la bola (a media altura del Pokémon).
    final anchor = onScreen(target.position..y = target.displayHeight * 0.55);
    if (anchor == null) return;
    final t = since / _bonusSeconds;
    // Aparece de golpe (un pelín grande), sube y se va apagando al final.
    final pop = 1 + 0.25 * math.max(0, 1 - since / 0.15);
    final alpha = t < 0.7 ? 1.0 : (1 - t) / 0.3;
    final texts = [
      for (final (label, color) in lines)
        TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: color.withValues(alpha: alpha),
              fontSize: 17 * pop,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black.withValues(alpha: 0.8 * alpha),
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final height = texts.fold(0.0, (h, text) => h + text.height);
    final width = texts.fold(0.0, (w, text) => math.max(w, text.width));
    // Sube 40 px, pero nunca se sale por arriba (Pokémon muy altos).
    var y = math.max(12.0, anchor.dy - 40 * t - height);
    // Fondo oscuro para que se lea sobre cualquier cosa.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(anchor.dx - width / 2 - 8, y - 3, width + 16, height + 6),
        const Radius.circular(10),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.45 * alpha),
    );
    for (final text in texts) {
      text.paint(canvas, Offset(anchor.dx - text.width / 2, y));
      y += text.height;
    }
  }

  /// Una baya en un bocadillo: el Pokémon va a por ella. Comiendo, el
  /// bocadillo late con cada mordisco ([munch]).
  void _paintBerryBubble(Canvas canvas, Offset at, double munch) {
    final r = 11 + 2 * munch;
    canvas
      ..drawCircle(at, r, Paint()..color = Colors.white)
      ..drawCircle(
        at,
        r,
        Paint()
          ..color = Colors.black54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      )
      ..drawCircle(
        at + Offset(0, r * 0.12),
        r * 0.5,
        Paint()..color = const Color(0xFFD8384A),
      )
      ..drawCircle(
        at + Offset(-r * 0.17, -r * 0.05),
        r * 0.14,
        Paint()..color = const Color(0xAAFFFFFF),
      );
    final leaf = Path()
      ..moveTo(at.dx, at.dy - r * 0.35)
      ..quadraticBezierTo(
        at.dx + r * 0.3,
        at.dy - r * 0.75,
        at.dx + r * 0.5,
        at.dy - r * 0.5,
      )
      ..quadraticBezierTo(
        at.dx + r * 0.25,
        at.dy - r * 0.3,
        at.dx,
        at.dy - r * 0.35,
      );
    canvas.drawPath(leaf, Paint()..color = const Color(0xFF3FA34D));
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
