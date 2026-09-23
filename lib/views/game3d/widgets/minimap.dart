import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../game/map/map_layout.dart';
import '../../../game3d/mesh/props.dart' show findHouseBlocks;
import '../../../game3d/sim/minimap.dart';
import '../../../game3d/sim/world3d_sim.dart';

/// MINIMAPA redondo: el mapa visto desde arriba, centrado en el jugador y
/// girado con la cámara (arriba = hacia donde miras, igual que "adelante"
/// en el teclado). Marca las Poké Balls del suelo y los Pokémon: blanco si
/// están tranquilos, amarillo si sospechan, naranja si te han visto y rojo
/// si vienen a por ti. La "N" del borde indica el norte del mapa.
///
/// Las cuentas (girar, escalar, qué entra en el círculo) están en
/// [MinimapView]; aquí solo se pinta. Se repinta en cada fotograma.
class Minimap extends StatefulWidget {
  const Minimap({super.key, required this.sim, this.size = 150});

  final World3DSim sim;

  /// Diámetro en píxeles.
  final double size;

  @override
  State<Minimap> createState() => _MinimapState();
}

class _MinimapState extends State<Minimap> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);

  /// El mapa de casillas se dibuja UNA vez (en metros) y luego solo se
  /// coloca girado y escalado en cada fotograma.
  late final ui.Picture _tiles;

  @override
  void initState() {
    super.initState();
    _tiles = _recordTiles(widget.sim.layout, widget.sim.config.tileSize);
    _ticker = createTicker((_) => _frame.value++)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _tiles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: Size.square(widget.size),
      painter: _MinimapPainter(widget.sim, _tiles, repaint: _frame),
    ),
  );
}

/// Colores del minimapa (parecidos a los del mundo 3D).
abstract final class _Colors {
  static const forest = Color(0xFF1E5631);
  static const grass = Color(0xFF7CC35A);
  static const flowers = Color(0xFF93CC6A);
  static const tallGrass = Color(0xFF2F8F3F);
  static const path = Color(0xFFE6D29C);
  static const stone = Color(0xFFC9C4BA);
  static const tree = Color(0xFF2E7D32);
  static const pine = Color(0xFF1F5E3A);
  static const autumn = Color(0xFFE0762F);
  static const bush = Color(0xFF3E9B4A);
  static const wood = Color(0xFF8E6639);
  static const wall = Color(0xFFF4EBDD);

  /// En el mismo orden que los tejados del mundo 3D (props.dart).
  static const roofs = [
    Color(0xFFD8453C),
    Color(0xFF3A74C9),
    Color(0xFF3C9A5B),
  ];

  static Color forMark(MinimapMark mark) => switch (mark) {
    MinimapMark.ball => const Color(0xFFE53935),
    MinimapMark.calm => Colors.white,
    MinimapMark.suspicious => Colors.amberAccent,
    MinimapMark.alert => Colors.orangeAccent,
    MinimapMark.hostile => Colors.redAccent,
  };
}

/// Dibuja el mapa en metros: suelo por casillas, luego árboles (círculos),
/// vallas, carteles y casas (con el color de su tejado).
ui.Picture _recordTiles(MapLayout layout, double tile) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // El suelo sin suavizado de bordes: con él, entre dos casillas del mismo
  // color se ve una rendija (una rejilla al girar el mapa).
  final paint = Paint()..isAntiAlias = false;
  for (var row = 0; row < layout.rows; row++) {
    for (var col = 0; col < layout.columns; col++) {
      final kind = layout.tileAt(col, row)!;
      paint.color = switch (kind) {
        TileKind.tallGrass => _Colors.tallGrass,
        TileKind.path => _Colors.path,
        TileKind.stone => _Colors.stone,
        TileKind.flowers => _Colors.flowers,
        _ => _Colors.grass,
      };
      canvas.drawRect(Rect.fromLTWH(col * tile, row * tile, tile, tile), paint);
    }
  }
  paint.isAntiAlias = true;
  for (var row = 0; row < layout.rows; row++) {
    for (var col = 0; col < layout.columns; col++) {
      final center = Offset((col + 0.5) * tile, (row + 0.5) * tile);
      switch (layout.tileAt(col, row)!) {
        case TileKind.tree:
          canvas.drawCircle(center, tile * 0.48, paint..color = _Colors.tree);
        case TileKind.pine:
          canvas.drawCircle(center, tile * 0.45, paint..color = _Colors.pine);
        case TileKind.autumnTree:
          canvas.drawCircle(center, tile * 0.48, paint..color = _Colors.autumn);
        case TileKind.bush:
          canvas.drawCircle(center, tile * 0.35, paint..color = _Colors.bush);
        case TileKind.fence:
          canvas.drawRect(
            Rect.fromCenter(center: center, width: tile, height: tile * 0.2),
            paint..color = _Colors.wood,
          );
        case TileKind.sign:
          canvas.drawRect(
            Rect.fromCenter(
              center: center,
              width: tile * 0.5,
              height: tile * 0.3,
            ),
            paint..color = _Colors.wood,
          );
        default:
          break;
      }
    }
  }
  final houses = findHouseBlocks(layout);
  for (var i = 0; i < houses.length; i++) {
    final h = houses[i];
    final rect = Rect.fromLTWH(
      h.col * tile,
      h.row * tile,
      h.width * tile,
      h.height * tile,
    ).deflate(tile * 0.08);
    canvas
      ..drawRect(rect, paint..color = _Colors.wall)
      ..drawRect(
        rect.deflate(tile * 0.18),
        paint..color = _Colors.roofs[i % _Colors.roofs.length],
      );
  }
  return recorder.endRecording();
}

class _MinimapPainter extends CustomPainter {
  _MinimapPainter(this.sim, this.tiles, {super.repaint});

  final World3DSim sim;
  final ui.Picture tiles;

  /// La "N" se prepara una vez.
  late final TextPainter _north = TextPainter(
    text: const TextSpan(
      text: 'N',
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  /// Ancho del cono de visión de la cámara.
  static const _viewCone = 70 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = size.shortestSide / 2;
    final center = size.center(Offset.zero);
    final view = MinimapView.of(sim);
    final circle = Rect.fromCircle(center: center, radius: radius);

    canvas
      ..save()
      ..clipPath(Path()..addOval(circle))
      ..drawCircle(center, radius, Paint()..color = _Colors.forest)
      // Mismo giro y escala que MinimapView.project, pero con el lienzo.
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(view.yaw)
      ..scale(radius / view.radius)
      ..translate(-view.center.x, -view.center.z)
      ..drawPicture(tiles)
      ..restore();

    // Cono de visión: hacia arriba (la cámara mira "arriba" en el mapa).
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.75),
      -math.pi / 2 - _viewCone / 2,
      _viewCone,
      true,
      Paint()
        ..shader = ui.Gradient.radial(center, radius * 0.75, [
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0),
        ]),
    );

    for (final m in view.markers(sim)) {
      _paintMarker(canvas, center + Offset(m.x, m.y) * radius, m.mark);
    }
    canvas.restore();

    // Borde, norte y el jugador (flecha en el centro).
    canvas.drawCircle(
      center,
      radius - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.black54,
    );
    final n = view.northAngle;
    final northAt = center + Offset(math.sin(n), -math.cos(n)) * (radius - 10);
    canvas.drawCircle(northAt, 8, Paint()..color = Colors.black54);
    _north.paint(canvas, northAt - Offset(_north.width / 2, _north.height / 2));
    _paintPlayer(canvas, center, view.screenAngle(sim.player.facing));
  }

  void _paintMarker(Canvas canvas, Offset at, MinimapMark mark) {
    final color = _Colors.forMark(mark);
    if (mark == MinimapMark.ball) {
      canvas
        ..drawCircle(at, 3.2, Paint()..color = Colors.white)
        ..drawCircle(at, 2.2, Paint()..color = color);
      return;
    }
    if (mark == MinimapMark.hostile) {
      // Aro que late: ¡viene a por ti!
      final pulse = (sim.time * 2) % 1;
      canvas.drawCircle(
        at,
        4 + pulse * 7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 1 - pulse),
      );
    }
    canvas
      ..drawCircle(at, 5, Paint()..color = Colors.black54)
      ..drawCircle(at, 3.8, Paint()..color = color);
  }

  void _paintPlayer(Canvas canvas, Offset center, double angle) {
    final arrow = Path()
      ..moveTo(0, -8)
      ..lineTo(6, 6)
      ..lineTo(0, 3)
      ..lineTo(-6, 6)
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
  bool shouldRepaint(_MinimapPainter old) =>
      old.sim != sim || old.tiles != tiles;
}
