import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';

/// On-screen directional pad for touch devices. Reports a direction while a
/// button is held and [Vector2.zero] on release.
class DPad extends StatelessWidget {
  const DPad({super.key, required this.onDirectionChanged});

  final ValueChanged<Vector2> onDirectionChanged;

  static const _buttonSize = 56.0;

  @override
  Widget build(BuildContext context) {
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
    return Listener(
      onPointerDown: (_) => onPressed(),
      onPointerUp: (_) => onReleased(),
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
