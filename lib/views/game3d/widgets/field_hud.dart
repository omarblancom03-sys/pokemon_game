import 'dart:async';

import 'package:flutter/material.dart';

import '../../../controllers/field_controller.dart';
import '../../../controllers/trainer_controller.dart';
import '../../../models/poke_ball.dart';
import '../../common/pokemon_formatters.dart';

/// Texto de cada aviso del campo (la vista decide el idioma y el formato).
String noticeText(FieldNotice n) {
  final name = n.pokemon == null ? '' : displayName(n.pokemon!.name);
  return switch (n.kind) {
    FieldNoticeKind.pickedUp => '+${n.count} ${n.ball!.label}',
    FieldNoticeKind.caught => '¡$name capturado!',
    FieldNoticeKind.brokeFree => switch (n.shakes) {
      0 => '¡Oh, no! $name se ha escapado',
      1 => '¡Vaya! Parecía que lo tenías…',
      2 => '¡Argh! ¡Casi lo consigues!',
      _ => '¡Qué rabia! ¡Por un pelo!',
    },
    FieldNoticeKind.missed => 'Fallaste: la bola quedó en el suelo',
    FieldNoticeKind.noBalls => 'No te quedan Poké Balls: busca más brillos',
  };
}

/// Colores de cada bola para los iconos de la interfaz.
({Color top, Color accent}) ballColors(PokeBallType type) => switch (type) {
  PokeBallType.poke => (
    top: const Color(0xFFE53935),
    accent: const Color(0xFFE53935),
  ),
  PokeBallType.great => (
    top: const Color(0xFF2D6CDF),
    accent: const Color(0xFFE53935),
  ),
  PokeBallType.ultra => (
    top: const Color(0xFF303030),
    accent: const Color(0xFFF4C430),
  ),
};

/// Icono de Poké Ball dibujado a mano (sin imágenes).
class BallIcon extends StatelessWidget {
  const BallIcon(this.type, {super.key, this.size = 22});

  final PokeBallType type;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _BallPainter(type));
}

class _BallPainter extends CustomPainter {
  _BallPainter(this.type);

  final PokeBallType type;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final rect = Rect.fromCircle(center: c, radius: r);
    final colors = ballColors(type);
    canvas
      ..drawArc(rect, 3.1416, 3.1416, true, Paint()..color = colors.top)
      ..drawArc(rect, 0, 3.1416, true, Paint()..color = Colors.white);
    if (type != PokeBallType.poke) {
      // Las "alas" de la Super Ball / la "H" de la Ultra Ball.
      final accent = Paint()..color = colors.accent;
      canvas
        ..drawRect(Rect.fromLTWH(r * 0.35, r * 0.25, r * 0.3, r * 0.6), accent)
        ..drawRect(Rect.fromLTWH(r * 1.35, r * 0.25, r * 0.3, r * 0.6), accent);
    }
    final line = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.14;
    canvas
      ..drawLine(Offset(0, r), Offset(size.width, r), line)
      ..drawCircle(c, r - line.strokeWidth / 2, line)
      ..drawCircle(c, r * 0.3, Paint()..color = Colors.white)
      ..drawCircle(c, r * 0.3, line);
  }

  @override
  bool shouldRepaint(_BallPainter old) => old.type != type;
}

/// La BOLSA: cuántas bolas quedan de cada tipo y cuál está elegida (se
/// puede tocar para elegir otra). Debajo, cuántos Pokémon llevas.
class BagBar extends StatelessWidget {
  const BagBar({super.key, required this.trainer});

  final TrainerController trainer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final type in PokeBallType.values)
                  _BagSlot(
                    key: Key('bag_${type.name}'),
                    type: type,
                    count: trainer.count(type),
                    selected: trainer.selected == type,
                    onTap: () => trainer.select(type),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
              child: Text(
                'Capturados: ${trainer.captured.length}',
                key: const Key('bag_captured'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BagSlot extends StatelessWidget {
  const _BagSlot({
    super.key,
    required this.type,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final PokeBallType type;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: count > 0 ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.white24 : Colors.transparent,
          border: Border.all(
            color: selected ? Colors.amberAccent : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Opacity(
          opacity: count > 0 ? 1 : 0.4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BallIcon(type),
              const SizedBox(width: 5),
              Text(
                '×$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Los avisos del campo, apilados. Cada uno se va solo a los pocos segundos.
class NoticeStack extends StatelessWidget {
  const NoticeStack({super.key, required this.field});

  final FieldController field;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final n in field.notices)
          _NoticeChip(
            key: ValueKey(n.id),
            notice: n,
            onDone: () => field.dismiss(n.id),
          ),
      ],
    );
  }
}

class _NoticeChip extends StatefulWidget {
  const _NoticeChip({super.key, required this.notice, required this.onDone});

  final FieldNotice notice;
  final VoidCallback onDone;

  @override
  State<_NoticeChip> createState() => _NoticeChipState();
}

class _NoticeChipState extends State<_NoticeChip> {
  late final Timer _timer;

  /// Cuánto se ve cada aviso (las capturas, un poco más).
  Duration get _duration => widget.notice.kind == FieldNoticeKind.caught
      ? const Duration(milliseconds: 3500)
      : const Duration(milliseconds: 2400);

  @override
  void initState() {
    super.initState();
    _timer = Timer(_duration, widget.onDone);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notice;
    final color = switch (n.kind) {
      FieldNoticeKind.caught => const Color(0xFF2E7D32),
      FieldNoticeKind.brokeFree => const Color(0xFFC62828),
      FieldNoticeKind.pickedUp => const Color(0xFF1565C0),
      FieldNoticeKind.missed || FieldNoticeKind.noBalls => Colors.black87,
    };
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (n.ball != null) ...[
              BallIcon(n.ball!, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              noticeText(n),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
