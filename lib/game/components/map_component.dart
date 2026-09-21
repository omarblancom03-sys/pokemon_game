import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../config/world_config.dart';

/// El suelo provisional: césped a cuadros, dos caminos de tierra, árboles,
/// flores y un borde. Es solo decoración (no tiene lógica ni colisiones);
/// más adelante se puede sustituir por un mapa de baldosas real.
class MapComponent extends PositionComponent {
  MapComponent({required this.config})
    // priority -1: se dibuja por debajo de todo lo demás.
    : super(size: config.worldSize, priority: -1);

  final WorldConfig config;

  // Paint = "brocha": el color con el que se pinta cada cosa.
  static final _grassA = Paint()..color = const Color(0xFF7EC850);
  static final _grassB = Paint()..color = const Color(0xFF74BE48);
  static final _path = Paint()..color = const Color(0xFFD9B77A);
  static final _trunk = Paint()..color = const Color(0xFF7A5230);
  static final _leaves = Paint()..color = const Color(0xFF2E7D32);
  static final _flower = Paint()..color = const Color(0xFFFFEB3B);
  static final _border = Paint()
    ..color = const Color(0xFF3E2723)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 8;

  final List<Offset> _trees = [];
  final List<Offset> _flowers = [];

  @override
  Future<void> onLoad() async {
    // Semilla fija (7): la decoración sale IGUAL en cada partida.
    final random = Random(7);
    Offset randomPoint() => Offset(
      random.nextDouble() * (config.width - 80) + 40,
      random.nextDouble() * (config.height - 80) + 40,
    );
    for (var i = 0; i < 30; i++) {
      _trees.add(randomPoint());
    }
    for (var i = 0; i < 60; i++) {
      _flowers.add(randomPoint());
    }
  }

  /// render: dibuja el fotograma. Se ejecuta ~60 veces por segundo.
  @override
  void render(Canvas canvas) {
    // Césped: dos verdes alternados como un tablero de ajedrez.
    final t = config.tileSize;
    for (var y = 0; y * t < config.height; y++) {
      for (var x = 0; x * t < config.width; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x * t, y * t, t, t),
          (x + y).isEven ? _grassA : _grassB,
        );
      }
    }

    // Dos caminos de tierra en cruz.
    canvas.drawRect(
      Rect.fromLTWH(0, config.height / 2 - t / 2, config.width, t),
      _path,
    );
    canvas.drawRect(
      Rect.fromLTWH(config.width / 2 - t / 2, 0, t, config.height),
      _path,
    );

    for (final f in _flowers) {
      canvas.drawCircle(f, 3, _flower);
    }
    // Cada árbol: tronco (rectángulo) + copa (círculo).
    for (final tree in _trees) {
      canvas.drawRect(
        Rect.fromCenter(center: tree.translate(0, 14), width: 8, height: 16),
        _trunk,
      );
      canvas.drawCircle(tree, 18, _leaves);
    }

    canvas.drawRect(Rect.fromLTWH(0, 0, config.width, config.height), _border);
  }
}
