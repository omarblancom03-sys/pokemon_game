import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../controllers/safari_controller.dart';
import '../../../controllers/trainer_controller.dart';
import '../../../game3d/sim/world3d_sim.dart';
import '../../common/pokemon_formatters.dart';
import 'field_hud.dart' show BallIcon, BerryIcon;

/// "9:05": minutos y segundos (redondeando hacia arriba: 0:01 hasta el
/// final).
String safariClock(double seconds) {
  final s = seconds.ceil().clamp(0, 99 * 60);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// MARCADOR del Reto Safari (arriba a la izquierda, en lugar de la bolsa):
/// el reloj (rojo en el último minuto), las bolas del reto y las bayas (se
/// tocan para llevarlas en la mano), lo capturado y "Abandonar".
///
/// El reloj lo lleva la simulación; se vuelve a pintar solo cuando cambia
/// el segundo que se enseña.
class SafariHud extends StatefulWidget {
  const SafariHud({
    super.key,
    required this.sim,
    required this.safari,
    required this.trainer,
    required this.onAbandon,
  });

  final World3DSim sim;
  final SafariController safari;
  final TrainerController trainer;
  final VoidCallback onAbandon;

  @override
  State<SafariHud> createState() => _SafariHudState();
}

class _SafariHudState extends State<SafariHud>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  String _clock = '';

  String get _now => safariClock(widget.sim.safariTimeLeft ?? 0);

  @override
  void initState() {
    super.initState();
    _clock = _now;
    _ticker = createTicker((_) {
      final now = _now;
      if (now != _clock) setState(() => _clock = now);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safari = widget.safari;
    final trainer = widget.trainer;
    final hurry = (widget.sim.safariTimeLeft ?? 0) <= 60;
    Widget slot({
      required Key key,
      required Widget icon,
      required String count,
      required bool selected,
      required VoidCallback onTap,
    }) => GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.amber : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 3),
            Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
    return DecoratedBox(
      key: const Key('safari_hud'),
      decoration: BoxDecoration(
        color: const Color(0xCC3E2A12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8C88C), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flag, color: Color(0xFFE8C88C), size: 16),
                const SizedBox(width: 4),
                const Text(
                  'RETO SAFARI',
                  style: TextStyle(
                    color: Color(0xFFE8C88C),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: hurry ? Colors.redAccent : Colors.white,
                ),
                const SizedBox(width: 2),
                Text(
                  _clock,
                  key: const Key('safari_clock'),
                  style: TextStyle(
                    color: hurry ? Colors.redAccent : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                slot(
                  key: const Key('safari_balls'),
                  icon: const BallIcon(SafariController.ball, size: 18),
                  count: '×${safari.ballsLeft}',
                  selected: !trainer.berrySelected,
                  // Solo guarda la baya: la bola del reto no es de la bolsa.
                  onTap: () => trainer.select(trainer.selected),
                ),
                slot(
                  key: const Key('safari_berries'),
                  icon: const BerryIcon(size: 18),
                  count: '×${trainer.berries}',
                  selected: trainer.berrySelected,
                  onTap: trainer.selectBerry,
                ),
                Text(
                  'Capturas: ${safari.catches.length} · ${safari.score} pts',
                  key: const Key('safari_tally'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 6),
                TextButton(
                  key: const Key('safari_abandon'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFFAB91),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: widget.onAbandon,
                  child: const Text('Abandonar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón para empezar el reto (bajo la bolsa, en el modo libre).
class SafariStartButton extends StatelessWidget {
  const SafariStartButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    key: const Key('safari_start'),
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xCC3E2A12),
      foregroundColor: const Color(0xFFE8C88C),
      visualDensity: VisualDensity.compact,
    ),
    onPressed: onPressed,
    icon: const Icon(Icons.flag, size: 18),
    label: const Text('Reto Safari'),
  );
}

/// Antes de empezar: en qué consiste el reto. Devuelve true si se acepta.
class SafariIntroDialog extends StatelessWidget {
  const SafariIntroDialog({super.key});

  @override
  Widget build(BuildContext context) {
    const rules = [
      (Icons.timer_outlined, '10 minutos para capturar todo lo que puedas.'),
      (Icons.catching_pokemon, '25 Poké Balls del reto: tu bolsa no se toca.'),
      (Icons.block, 'No hay bolas en el suelo y las que falles se pierden.'),
      (Icons.spa, 'Tus bayas sí sirven para distraerlos.'),
      (
        Icons.star_outline,
        'Puntos: los raros valen más; sigilo, baya y aro multiplican.',
      ),
      (
        Icons.flag_outlined,
        'Puedes abandonar cuando quieras: lo capturado es tuyo.',
      ),
    ];
    return AlertDialog(
      key: const Key('safari_intro'),
      backgroundColor: const Color(0xFF2B1E0E),
      title: const Row(
        children: [
          Icon(Icons.flag, color: Color(0xFFE8C88C)),
          SizedBox(width: 8),
          Text('Reto Safari', style: TextStyle(color: Color(0xFFE8C88C))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icon, text) in rules)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          key: const Key('safari_go'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('¡Empezar!'),
        ),
      ],
    );
  }
}

/// Al terminar: por qué terminó y qué se capturó.
class SafariSummaryDialog extends StatelessWidget {
  const SafariSummaryDialog({super.key, required this.safari});

  final SafariController safari;

  @override
  Widget build(BuildContext context) {
    final title = switch (safari.end) {
      SafariEnd.timeUp => '¡Se acabó el tiempo!',
      SafariEnd.outOfBalls => '¡Sin bolas!',
      SafariEnd.abandoned || null => 'Reto abandonado',
    };
    final catches = safari.catches;
    return AlertDialog(
      key: const Key('safari_summary'),
      backgroundColor: const Color(0xFF2B1E0E),
      title: Text(title, style: const TextStyle(color: Color(0xFFE8C88C))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            catches.isEmpty
                ? 'Esta vez no capturaste ninguno. ¡A la próxima!'
                : 'Capturaste ${catches.length} Pokémon:',
            style: const TextStyle(color: Colors.white),
          ),
          if (catches.isNotEmpty) ...[
            const SizedBox(height: 8),
            // Cada captura: puntos por rareza × bonus del tiro.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Column(
                  children: [for (final c in catches) _CatchRow(c)],
                ),
              ),
            ),
            const Divider(color: Colors.white24),
            Row(
              children: [
                const Text(
                  'Puntos',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const Spacer(),
                Text(
                  '${safari.score}',
                  key: const Key('safari_score'),
                  style: const TextStyle(
                    color: Color(0xFFE8C88C),
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        FilledButton(
          key: const Key('safari_close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver al campo'),
        ),
      ],
    );
  }
}

/// "×1,5": un multiplicador con coma decimal (sin decimales si es entero).
String bonusLabel(double bonus) {
  final rounded = (bonus * 100).round() / 100;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toString().replaceAll('.', ',');
  return '×$text';
}

/// Una captura en el resumen: nombre, "rareza × bonus" y los puntos.
class _CatchRow extends StatelessWidget {
  const _CatchRow(this.entry);

  final SafariCatch entry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            displayName(entry.pokemon.name),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        Text(
          entry.bonus == 1
              ? '${entry.base}'
              : '${entry.base} ${bonusLabel(entry.bonus)}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          child: Text(
            '+${entry.points}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.lightGreenAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}
