import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../game/map/world_signs.dart';
import '../../../game3d/sim/world3d_sim.dart';
import 'field_hud.dart';

/// Qué ofrece ahora la tecla de acción (L / Intro): la simulación dice qué
/// hay a mano; este panel lo enseña abajo y se puede tocar.
///
///  - CARTELES: con uno delante sale "L · Leer el cartel"; al leerlo, un
///    panel de madera con el título y el texto (L o tocarlo lo cierra;
///    alejarse, también). Lo que pone lo aporta el contenido del mapa
///    ([signTextAt]).
///  - ARBUSTOS: con uno delante sale "L · Sacudir el arbusto" con las
///    bayas que le quedan (o "sin bayas").
///
/// Se mira la simulación en cada fotograma, pero solo se reconstruye
/// cuando cambia lo que hay que enseñar.
class ActionPanel extends StatefulWidget {
  const ActionPanel({super.key, required this.sim, required this.onAction});

  final World3DSim sim;

  /// Lo mismo que la tecla L: leer / cerrar el cartel o sacudir el arbusto.
  final VoidCallback onAction;

  @override
  State<ActionPanel> createState() => _ActionPanelState();
}

/// Lo que se enseña: el cartel abierto, el que se puede leer o las bayas
/// del arbusto que se puede sacudir (-1 = ningún arbusto).
typedef _Shown = ({MapCell? open, MapCell? readable, int bushBerries});

class _ActionPanelState extends State<ActionPanel>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late _Shown _shown;

  @override
  void initState() {
    super.initState();
    _shown = _current();
    _ticker = createTicker((_) => _sync())..start();
  }

  _Shown _current() {
    final sim = widget.sim;
    final open = sim.openSign;
    if (open != null) return (open: open, readable: null, bushBerries: -1);
    return (
      open: null,
      readable: sim.readableSign,
      bushBerries: sim.shakableBush?.berries ?? -1,
    );
  }

  void _sync() {
    final shown = _current();
    if (shown == _shown) return;
    setState(() => _shown = shown);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (:open, :readable, :bushBerries) = _shown;
    if (open != null) {
      return _Board(
        key: const Key('sign_panel'),
        text: signTextAt(open.col, open.row),
        onTap: widget.onAction,
      );
    }
    if (readable != null) {
      return _Prompt(
        key: const Key('sign_prompt'),
        onTap: widget.onAction,
        icon: const Icon(Icons.signpost, color: Color(0xFFE8C88C), size: 20),
        label: 'Leer el cartel',
      );
    }
    if (bushBerries >= 0) {
      return _Prompt(
        key: const Key('bush_prompt'),
        onTap: widget.onAction,
        icon: const Icon(Icons.grass, color: Color(0xFF7BD389), size: 20),
        label: 'Sacudir el arbusto',
        trailing: bushBerries == 0
            ? const Text(
                'sin bayas',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < bushBerries; i++)
                    const Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: BerryIcon(size: 16),
                    ),
                ],
              ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Aviso "L · …" (se puede tocar).
class _Prompt extends StatelessWidget {
  const _Prompt({
    super.key,
    required this.onTap,
    required this.icon,
    required this.label,
    this.trailing,
  });

  final VoidCallback onTap;
  final Widget icon;
  final String label;

  /// Algo más a la derecha (las bayas del arbusto).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _KeyCap('L'),
              const SizedBox(width: 8),
              icon,
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
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
