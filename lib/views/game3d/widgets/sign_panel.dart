import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../game/map/world_signs.dart';
import '../../../game3d/sim/world3d_sim.dart';

/// CARTELES: con uno delante sale abajo "L · Leer el cartel"; al leerlo,
/// un panel de madera con el título y el texto (L o tocarlo lo cierra;
/// alejarse, también).
///
/// La simulación dice QUÉ cartel (casilla); lo que pone lo aporta el
/// contenido del mapa ([signTextAt]). Se mira la simulación en cada
/// fotograma, pero solo se reconstruye cuando cambia el cartel.
class SignPanel extends StatefulWidget {
  const SignPanel({super.key, required this.sim, required this.onToggle});

  final World3DSim sim;

  /// Leer / cerrar (lo mismo que la tecla L).
  final VoidCallback onToggle;

  @override
  State<SignPanel> createState() => _SignPanelState();
}

class _SignPanelState extends State<SignPanel>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  MapCell? _readable;
  MapCell? _open;

  @override
  void initState() {
    super.initState();
    final (open, readable) = _current();
    _open = open;
    _readable = readable;
    _ticker = createTicker((_) => _sync())..start();
  }

  /// Cartel abierto y, si no hay ninguno abierto, el que se puede leer.
  (MapCell?, MapCell?) _current() {
    final open = widget.sim.openSign;
    return (open, open == null ? widget.sim.readableSign : null);
  }

  void _sync() {
    final (open, readable) = _current();
    if (open == _open && readable == _readable) return;
    setState(() {
      _open = open;
      _readable = readable;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = _open;
    if (open != null) {
      return _Board(
        key: const Key('sign_panel'),
        text: signTextAt(open.col, open.row),
        onTap: widget.onToggle,
      );
    }
    if (_readable != null) {
      return _Prompt(key: const Key('sign_prompt'), onTap: widget.onToggle);
    }
    return const SizedBox.shrink();
  }
}

/// Aviso "L · Leer el cartel" (se puede tocar).
class _Prompt extends StatelessWidget {
  const _Prompt({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _KeyCap('L'),
              SizedBox(width: 8),
              Icon(Icons.signpost, color: Color(0xFFE8C88C), size: 20),
              SizedBox(width: 6),
              Text(
                'Leer el cartel',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El texto del cartel en una tabla de madera.
class _Board extends StatelessWidget {
  const _Board({super.key, required this.text, required this.onTap});

  final SignText text;
  final VoidCallback onTap;

  static const _wood = Color(0xFFE8C88C);
  static const _woodDark = Color(0xFF7A4E2A);
  static const _ink = Color(0xFF3B2412);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _wood,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _woodDark, width: 4),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.title,
                  style: const TextStyle(
                    color: _woodDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text.body,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'L · cerrar',
                    style: TextStyle(
                      color: _woodDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Una tecla dibujada ("L").
class _KeyCap extends StatelessWidget {
  const _KeyCap(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
