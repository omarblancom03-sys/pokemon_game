import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';

/// VISTA: cruceta en pantalla para jugar con el dedo (móvil o tableta).
///
/// Envía una dirección mientras el botón está PULSADO y Vector2.zero() al
/// soltarlo.
class DPad extends StatelessWidget {
  const DPad({super.key, required this.onDirectionChanged});

  /// A quién avisar de la dirección (aquí, al MovementInput del juego).
  final ValueChanged<Vector2> onDirectionChanged;

  static const _buttonSize = 56.0;

  @override
  Widget build(BuildContext context) {
    // Función local: crea un botón con su dirección (x, y).
    Widget button(IconData icon, double x, double y) => _DPadButton(
      icon: icon,
      size: _buttonSize,
      onPressed: () => onDirectionChanged(Vector2(x, y)),
      onReleased: () => onDirectionChanged(Vector2.zero()),
    );

    return SizedBox.square(
      dimension: _buttonSize * 3,
      child: Stack(
        children: [
          // Ojo: en gráficos la Y crece hacia abajo, por eso arriba es -1.
          Align(
            alignment: Alignment.topCenter,
            child: button(Icons.keyboard_arrow_up, 0, -1),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: button(Icons.keyboard_arrow_down, 0, 1),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: button(Icons.keyboard_arrow_left, -1, 0),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: button(Icons.keyboard_arrow_right, 1, 0),
          ),
        ],
      ),
    );
  }
}

/// Un botón de la cruceta.
class _DPadButton extends StatelessWidget {
  const _DPadButton({
    required this.icon,
    required this.size,
    required this.onPressed,
    required this.onReleased,
  });

  final IconData icon;
  final double size;
  final VoidCallback onPressed;
  final VoidCallback onReleased;

  @override
  Widget build(BuildContext context) {
    // Listener y no onTap: hace falta saber cuándo se MANTIENE pulsado.
    return Listener(
      onPointerDown: (_) => onPressed(),
      onPointerUp: (_) => onReleased(),
      // Si el sistema interrumpe el gesto, Ash no se queda andando solo.
      onPointerCancel: (_) => onReleased(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}
