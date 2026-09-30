import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../controllers/field_controller.dart';
import '../../../controllers/trainer_controller.dart';
import '../../../models/poke_ball.dart';
import '../../common/pokemon_formatters.dart';
import 'capture_card.dart';

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
    FieldNoticeKind.ballLost => 'Fallaste: en el Safari la bola se pierde',
    FieldNoticeKind.fled => '¡El $name salvaje huyó!',
    FieldNoticeKind.noBalls => 'No te quedan Poké Balls: busca más brillos',
    FieldNoticeKind.burstOut => '¡Un $name salvaje salió de la hierba!',
    FieldNoticeKind.peeked => '$name asoma entre la hierba… ¡no te ha visto!',
    FieldNoticeKind.berriesPickedUp => '+${n.count} ${berryLabel(n.count)}',
    FieldNoticeKind.emptyBush =>
      'Este arbusto no tiene bayas: le vuelven a crecer',
    FieldNoticeKind.noBerries => 'No te quedan bayas: sacude algún arbusto',
    FieldNoticeKind.eating => '¡$name se está comiendo la baya! Aprovecha',
    FieldNoticeKind.shinySpotted => '¡Un $name VARIOCOLOR! Qué suerte',
    FieldNoticeKind.dodged => '¡$name esquivó la bola! Te vio venir',
    FieldNoticeKind.dazed => '¡$name se pasó de largo! Está aturdido: ¡ahora!',
    FieldNoticeKind.wokeUp => '¡$name se despertó!',
    FieldNoticeKind.herdAlerted => '¡$name avisó a su manada!',
  };
}

/// Nombre de las bayas que dan los arbustos (la Baya Frambu de los juegos).
String berryLabel(int count) => count == 1 ? 'Baya Frambu' : 'Bayas Frambu';

/// Icono de baya dibujado a mano: roja con brillo y una hojita.
class BerryIcon extends StatelessWidget {
  const BerryIcon({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _BerryPainter());
}

class _BerryPainter extends CustomPainter {
  const _BerryPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r * 1.12);
    canvas
      ..drawCircle(c, r * 0.8, Paint()..color = const Color(0xFFD8384A))
      ..drawCircle(
        c + Offset(-r * 0.3, -r * 0.28),
        r * 0.22,
        Paint()..color = const Color(0xAAFFFFFF),
      );
    // Hojita arriba.
    final leaf = Path()
      ..moveTo(r, r * 0.4)
      ..quadraticBezierTo(r * 1.5, -r * 0.05, r * 1.75, r * 0.3)
      ..quadraticBezierTo(r * 1.4, r * 0.6, r, r * 0.4)
      ..close();
    canvas.drawPath(leaf, Paint()..color = const Color(0xFF3FA34D));
  }

  @override
  bool shouldRepaint(_BerryPainter old) => false;
}

/// Colores de cada bola para los iconos de la interfaz (los mismos de la
/// bola 3D, ficha "PokeBall Spec").
({Color top, Color accent}) ballColors(PokeBallType type) => switch (type) {
  PokeBallType.poke => (
    top: const Color(0xFFE3392F),
    accent: const Color(0xFFE3392F),
  ),
  PokeBallType.great => (
    top: const Color(0xFF2F6BD8),
    accent: const Color(0xFFE3392F),
  ),
  PokeBallType.ultra => (
    top: const Color(0xFF2A2B31),
    accent: const Color(0xFFF4C21B),
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

/// Pensado para 14–22 px: exagera a propósito el aro, la franja y las
/// marcas respecto a la bola 3D para que se lean a ese tamaño, y alinea la
/// franja a píxeles enteros para que no salga borrosa.
class _BallPainter extends CustomPainter {
  _BallPainter(this.type);

  final PokeBallType type;

  static const _ink = Color(0xFF1B1B21);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Radio con 1 px de margen.
    final r = size.width / 2 - 1;
    final center = Offset(cx, cy);
    final colors = ballColors(type);
    final fill = Paint();

    // Mitades, marcas y franja, recortadas por el círculo.
    canvas
      ..save()
      ..clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)))
      ..drawRect(
        Rect.fromLTRB(cx - r, cy - r, cx + r, cy),
        fill..color = colors.top,
      )
      ..drawRect(
        Rect.fromLTRB(cx - r, cy, cx + r, cy + r),
        fill..color = const Color(0xFFF2EEE6),
      );
    fill.color = colors.accent;
    switch (type) {
      case PokeBallType.poke:
        break;
      case PokeBallType.great:
        // Las alas: una cuña por lado que sale del borde.
        for (final s in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(cx + s * 0.32 * r, cy)
              ..lineTo(cx + s * 0.58 * r, cy - 0.80 * r)
              ..lineTo(cx + s * 1.2 * r, cy - 1.2 * r)
              ..lineTo(cx + s * 1.2 * r, cy)
              ..close(),
            fill,
          );
        }
      case PokeBallType.ultra:
        // Los palos de la "H" (vista de frente), con bordes en píxel entero.
        for (final s in [-1.0, 1.0]) {
          final a = (cx + s * 0.30 * r).roundToDouble();
          final b = (cx + s * 0.62 * r).roundToDouble();
          canvas.drawRect(
            Rect.fromLTRB(math.min(a, b), cy - r, math.max(a, b), cy),
            fill,
          );
        }
    }
    final band = (0.24 * r).roundToDouble().clamp(2.0, 3.0);
    final bandTop = (cy - band / 2).roundToDouble();
    canvas
      ..drawRect(
        Rect.fromLTRB(cx - r, bandTop, cx + r, bandTop + band),
        fill..color = _ink,
      )
      ..restore();

    // Contorno, un brillo arriba a la izquierda, y el botón con su aro.
    final stroke = math.max(1.25, 0.16 * r);
    canvas
      ..drawCircle(
        center,
        r - stroke / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = _ink,
      )
      ..drawArc(
        Rect.fromCircle(center: center, radius: 0.62 * r),
        200 * math.pi / 180,
        50 * math.pi / 180,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, 0.13 * r)
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x8CFFFFFF),
      )
      ..drawCircle(center, 0.40 * r, fill..color = _ink)
      ..drawCircle(center, 0.22 * r, fill..color = const Color(0xFFF7F5EF));
  }

  @override
  bool shouldRepaint(_BallPainter old) => old.type != type;
}

/// La BOLSA: cuántas bolas quedan de cada tipo y cuántas bayas, y qué lleva
/// en la mano (se puede tocar para elegir otra cosa). Debajo, cuántos
/// Pokémon llevas (al tocarlo se abren tus capturas).
class BagBar extends StatelessWidget {
  const BagBar({super.key, required this.trainer, this.onShowCaptures});

  final TrainerController trainer;

  /// Abre el panel "Mis capturas".
  final VoidCallback? onShowCaptures;

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
                    icon: BallIcon(type),
                    count: trainer.count(type),
                    selected:
                        !trainer.berrySelected && trainer.selected == type,
                    onTap: () => trainer.select(type),
                  ),
                _BagSlot(
                  key: const Key('bag_berry'),
                  icon: const BerryIcon(),
                  count: trainer.berries,
                  selected: trainer.berrySelected,
                  onTap: trainer.selectBerry,
                ),
              ],
            ),
            GestureDetector(
              key: const Key('bag_captured'),
              onTap: onShowCaptures,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Capturados: ${trainer.captured.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    if (onShowCaptures != null) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.grid_view_rounded,
                        color: Colors.white54,
                        size: 13,
                      ),
                      const Text(
                        ' P',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ],
                ),
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
    required this.icon,
    required this.count,
    required this.selected,
    this.onTap,
  });

  final Widget icon;
  final int count;
  final bool selected;

  /// Elegir este objeto (null = no se puede elegir).
  final VoidCallback? onTap;

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
              icon,
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
      FieldNoticeKind.fled => const Color(0xFF6D4C41),
      FieldNoticeKind.pickedUp => const Color(0xFF1565C0),
      FieldNoticeKind.missed ||
      FieldNoticeKind.ballLost ||
      FieldNoticeKind.noBalls => Colors.black87,
      FieldNoticeKind.burstOut => const Color(0xFFE65100),
      FieldNoticeKind.peeked => const Color(0xFF00796B),
      FieldNoticeKind.berriesPickedUp => const Color(0xFFAD1457),
      FieldNoticeKind.eating => const Color(0xFF2E7D32),
      FieldNoticeKind.shinySpotted => const Color(0xFFB8860B),
      FieldNoticeKind.dodged => const Color(0xFF5D4037),
      FieldNoticeKind.dazed => const Color(0xFF6A1B9A),
      FieldNoticeKind.wokeUp => const Color(0xFF283593),
      FieldNoticeKind.herdAlerted => const Color(0xFFE65100),
      FieldNoticeKind.emptyBush || FieldNoticeKind.noBerries => Colors.black87,
    };
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      // Las capturas se celebran con una tarjeta; lo demás, con un aviso.
      child: n.kind == FieldNoticeKind.caught && n.pokemon != null
          ? CaptureCard(notice: n)
          : Container(
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
                  if (n.kind == FieldNoticeKind.berriesPickedUp ||
                      n.kind == FieldNoticeKind.eating) ...[
                    const BerryIcon(size: 18),
                    const SizedBox(width: 8),
                  ],
                  if (n.kind == FieldNoticeKind.shinySpotted) ...[
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 18,
                    ),
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
