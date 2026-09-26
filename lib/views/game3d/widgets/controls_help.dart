import 'dart:async';

import 'package:flutter/material.dart';

/// AYUDA DE CONTROLES plegable (tecla H o tocarla). Al entrar se ve entera
/// y, pasado [autoHideAfter], se pliega sola en una pestaña pequeña
/// ("H · Controles") para no tapar a los Pokémon lejanos de la parte de
/// arriba de la pantalla. Si el jugador la abre o la cierra antes, ya no se
/// pliega sola: manda él.
///
/// Si está abierta o no lo guarda [open] (de la pantalla, que la cambia con
/// la tecla H); aquí solo se pinta y se cuenta el tiempo.
class ControlsHelp extends StatefulWidget {
  const ControlsHelp({
    super.key,
    required this.open,
    this.autoHideAfter = const Duration(seconds: 20),
  });

  final ValueNotifier<bool> open;

  /// Cuándo se pliega sola (null = nunca).
  final Duration? autoHideAfter;

  @override
  State<ControlsHelp> createState() => _ControlsHelpState();
}

class _ControlsHelpState extends State<ControlsHelp> {
  Timer? _autoHide;

  @override
  void initState() {
    super.initState();
    final after = widget.autoHideAfter;
    if (after != null && widget.open.value) {
      _autoHide = Timer(after, () => widget.open.value = false);
    }
    widget.open.addListener(_cancelAutoHide);
  }

  void _cancelAutoHide() {
    _autoHide?.cancel();
    _autoHide = null;
  }

  @override
  void dispose() {
    widget.open.removeListener(_cancelAutoHide);
    _cancelAutoHide();
    super.dispose();
  }

  void _toggle() => widget.open.value = !widget.open.value;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.open,
    builder: (_, open, _) => AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      child: open ? _Panel(onClose: _toggle) : _Tab(onOpen: _toggle),
    ),
  );
}

const _box = BoxDecoration(
  color: Colors.black54,
  borderRadius: BorderRadius.all(Radius.circular(8)),
);
const _text = TextStyle(color: Colors.white, fontSize: 13, height: 1.35);
const _accent = Color(0xFFFFD54F);

/// Plegada: una pestaña pequeña.
class _Tab extends StatelessWidget {
  const _Tab({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('game3d_help_tab'),
    onTap: onOpen,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: DecoratedBox(
        decoration: _box,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard, color: Colors.white70, size: 16),
              SizedBox(width: 6),
              Text('H · Controles', style: _text),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Abierta: los controles por grupos y un consejo.
class _Panel extends StatelessWidget {
  const _Panel({required this.onClose});

  final VoidCallback onClose;

  static const _groups = [
    ('Moverse', 'WASD / flechas · Mayús correr · C agacharse'),
    ('Cámara', 'Arrastrar o Q/E girar · Rueda zoom · V detrás'),
    ('Capturar', 'Clic der. / F apuntar · Clic / Espacio lanzar'),
    ('', 'R o 1-4 elegir bola o baya'),
    ('', 'Lanza cuando el aro de la mira sea pequeño: ¡Excelente! ×2'),
    ('Más', 'L leer carteles y sacudir arbustos · P capturas · M mapa'),
    ('', 'H esta ayuda · N sonido'),
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const Key('game3d_help'),
    decoration: _box,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Controles',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'H · ocultar',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                IconButton(
                  key: const Key('game3d_help_close'),
                  tooltip: 'Ocultar la ayuda (H)',
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: onClose,
                  icon: const Icon(Icons.expand_less, color: Colors.white70),
                ),
              ],
            ),
            for (final (label, keys) in _groups)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      label,
                      style: _text.copyWith(
                        color: _accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Flexible(child: Text(keys, style: _text)),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              'En la hierba alta no te ven · Correr hace ruido',
              style: _text.copyWith(
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
