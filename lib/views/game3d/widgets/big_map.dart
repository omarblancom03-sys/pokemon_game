import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

import '../../../game3d/sim/map_overview.dart';
import '../../../game3d/sim/minimap.dart';
import '../../../game3d/sim/world3d_sim.dart';
import '../../../models/poke_ball.dart';
import 'field_hud.dart';
import 'map_tiles.dart';

/// MAPA GRANDE (tecla M o tocar el minimapa): el mundo entero con el norte
/// arriba, dónde estás y hacia dónde miras, los carteles, los arbustos con
/// las bayas que les quedan, las Poké Balls y bayas del suelo y, dentro
/// del círculo de lo que alcanzas a ver, los Pokémon (con los colores del
/// minimapa). Mientras está abierto el mundo está congelado, así que se
/// pinta una sola vez.
///
/// Qué se marca lo decide [MapOverview]; aquí solo se pinta.
class BigMapPanel extends StatefulWidget {
  const BigMapPanel({super.key, required this.sim});

  final World3DSim sim;

  @override
  State<BigMapPanel> createState() => _BigMapPanelState();
}

class _BigMapPanelState extends State<BigMapPanel> {
  late final ui.Picture _tiles = recordMapTiles(
    widget.sim.layout,
    widget.sim.config.tileSize,
  );
  late final MapOverview _overview = MapOverview.of(widget.sim);

  @override
  void dispose() {
    _tiles.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final overview = _overview;
    return Dialog(
      key: const Key('big_map'),
      backgroundColor: const Color(0xFF0F1A30),
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.keyM): _close},
        child: Focus(
          autofocus: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
                  child: Row(
                    children: [
                      const Text(
                        'Mapa',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'M · cerrar',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      IconButton(
                        key: const Key('big_map_close'),
                        tooltip: 'Cerrar',
                        onPressed: _close,
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    // Center deja al AspectRatio encoger el ancho si falta alto.
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: overview.width / overview.depth,
                        child: CustomPaint(
                          painter: _BigMapPainter(overview, _tiles),
                        ),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: _Legend(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Qué es cada marca.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Widget icon, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(dimension: 18, child: Center(child: icon)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
    return Wrap(
      spacing: 18,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        item(
          const Icon(Icons.navigation, color: Color(0xFFFFD54F), size: 18),
          'Tú',
        ),
        item(const BallIcon(PokeBallType.poke, size: 14), 'Poké Balls'),
        item(const BerryIcon(size: 17), 'Arbustos con bayas'),
        item(
          const Icon(Icons.signpost, color: Color(0xFFE8C88C), size: 18),
          'Carteles',
        ),
        item(
          const CircleAvatar(radius: 5, backgroundColor: Colors.white),
          'Pokémon cerca (en el círculo)',
        ),
      ],
    );
  }
}

class _BigMapPainter extends CustomPainter {
  _BigMapPainter(this.map, this.tiles);

  final MapOverview map;
  final ui.Picture tiles;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Píxeles por metro: la misma escala en los dos ejes (el mapa no se
    // deforma aunque el hueco no tenga justo su proporción).
    final scale = math.min(size.width / map.width, size.height / map.depth);
    final area = Size(map.width * scale, map.depth * scale);
    Offset at(Vector3 p) {
      final m = map.project(p);
      return Offset(m.x * area.width, m.y * area.height);
    }

    final frame = RRect.fromRectAndRadius(
      Offset.zero & area,
      const Radius.circular(12),
    );
    canvas
      ..save()
      ..clipRRect(frame)
      ..drawRect(Offset.zero & area, Paint()..color = MapColors.forest)
      ..save()
      ..scale(scale)
      ..drawPicture(tiles)
      ..restore();

    // Lo que alcanzas a ver (donde salen los Pokémon) y hacia dónde mira
    // la cámara.
    final me = at(map.player);
    canvas
      ..drawCircle(
        me,
        MapOverview.wildRange * scale,
        Paint()..color = Colors.white.withValues(alpha: 0.08),
      )
      ..drawCircle(
        me,
        MapOverview.wildRange * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.4),
      );
    const cone = 70 * math.pi / 180;
    final coneRadius = 9 * scale;
    canvas.drawArc(
      Rect.fromCircle(center: me, radius: coneRadius),
      map.cameraAngle - math.pi / 2 - cone / 2,
      cone,
      true,
      Paint()
        ..shader = ui.Gradient.radial(me, coneRadius, [
          Colors.white.withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0),
        ]),
    );

    for (final sign in map.signs) {
      _paintSign(canvas, at(sign));
    }
    for (final bush in map.bushes) {
      _paintBush(canvas, at(bush.at), bush.berries);
    }
    for (final berry in map.berries) {
      canvas
        ..drawCircle(at(berry), 3.2, Paint()..color = Colors.white)
        ..drawCircle(at(berry), 2.3, Paint()..color = MapColors.berry);
    }
    for (final ball in map.balls) {
      canvas
        ..drawCircle(at(ball), 4.5, Paint()..color = Colors.white)
        ..drawCircle(
          at(ball),
          3.2,
          Paint()..color = MapColors.forMark(MinimapMark.ball),
        );
    }
    for (final w in map.wild) {
      canvas
        ..drawCircle(at(w.at), 5.5, Paint()..color = Colors.black54)
        ..drawCircle(at(w.at), 4.2, Paint()..color = MapColors.forMark(w.mark));
    }
    _paintPlayer(canvas, me, map.playerAngle);
    canvas.restore();

    // Norte arriba.
    final north = TextPainter(
      text: const TextSpan(
        text: 'N ↑',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = Rect.fromLTWH(8, 8, north.width + 12, north.height + 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(8)),
      Paint()..color = Colors.black54,
    );
    north.paint(canvas, box.topLeft + const Offset(6, 3));
  }

  /// Un cartel: tablilla de madera sobre su poste.
  void _paintSign(Canvas canvas, Offset at) {
    final board = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at - const Offset(0, 3), width: 14, height: 9),
      const Radius.circular(2),
    );
    canvas
      ..drawLine(
        at,
        at + const Offset(0, 6),
        Paint()
          ..color = const Color(0xFF7A4E2A)
          ..strokeWidth = 2.5,
      )
      ..drawRRect(board, Paint()..color = const Color(0xFFE8C88C))
      ..drawRRect(
        board,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF7A4E2A),
      );
  }

  /// Un arbusto: con bayas, un círculo rojo con cuántas le quedan; sin
  /// ninguna, un aro gris (vuelven a crecer).
  void _paintBush(Canvas canvas, Offset at, int berries) {
    if (berries == 0) {
      canvas.drawCircle(
        at,
        5.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white54,
      );
      return;
    }
    canvas
      ..drawCircle(at, 8, Paint()..color = Colors.white)
      ..drawCircle(at, 6.8, Paint()..color = MapColors.berry);
    final count = TextPainter(
      text: TextSpan(
        text: '$berries',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    count.paint(canvas, at - Offset(count.width / 2, count.height / 2));
  }

  void _paintPlayer(Canvas canvas, Offset center, double angle) {
    final arrow = Path()
      ..moveTo(0, -10)
      ..lineTo(7.5, 7.5)
      ..lineTo(0, 4)
      ..lineTo(-7.5, 7.5)
      ..close();
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(angle)
      ..drawPath(
        arrow,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.black54,
      )
      ..drawPath(arrow, Paint()..color = const Color(0xFFFFD54F))
      ..restore();
  }

  @override
  bool shouldRepaint(_BigMapPainter old) =>
      old.map != map || old.tiles != tiles;
}
