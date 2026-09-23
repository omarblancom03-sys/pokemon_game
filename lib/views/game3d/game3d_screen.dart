import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../game/input/movement_input.dart';
import '../../game/map/map_layout.dart';
import '../../game/map/world_map.dart';
import '../../game3d/render/scene_renderer.dart';
import '../../game3d/sim/camera_input.dart';
import '../../game3d/sim/world3d_sim.dart';
import '../game/widgets/d_pad.dart';

/// VISTA: exploración en 3D (tercera persona).
///
/// Crea la simulación una sola vez y traduce la entrada del usuario
/// (teclado, ratón, D-pad) a las "intenciones" que lee la simulación.
/// El dibujo lo hace el [SceneRenderer] que llega por provider.
class Game3DScreen extends StatefulWidget {
  const Game3DScreen({super.key});

  @override
  State<Game3DScreen> createState() => _Game3DScreenState();
}

class _Game3DScreenState extends State<Game3DScreen> {
  // Igual que en 2D: si se creara en build(), cada repintado reiniciaría.
  late final World3DSim _sim = World3DSim(
    layout: MapLayout.parse(worldMapRows),
  );

  /// Teclas → movimiento y cámara. Se recalcula con TODAS las teclas
  /// pulsadas, así soltar una no deja otra "pegada".
  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;
    if (!MovementInput.isMovementKey(key) && !CameraInput.isCameraKey(key)) {
      return KeyEventResult.ignored;
    }
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    _sim.input.setKeyboardDirection(MovementInput.directionFromKeys(pressed));
    _sim.cameraInput.updateFromKeys(pressed);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final renderer = context.read<SceneRenderer>();
    return Scaffold(
      appBar: AppBar(title: const Text('Jugar 3D')),
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          children: [
            // Ratón: arrastrar con cualquier botón gira la cámara; la
            // rueda acerca o aleja.
            Listener(
              onPointerMove: (event) {
                if (event.buttons != 0) {
                  _sim.cameraInput.addDrag(event.delta.dx, event.delta.dy);
                }
              },
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  _sim.cameraInput.addZoom(event.scrollDelta.dy * 0.01);
                }
              },
              child: renderer.buildView(_sim),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: DPad(
                key: const Key('game3d_dpad'),
                onDirectionChanged: _sim.input.setPadDirection,
              ),
            ),
            const Positioned(right: 16, top: 16, child: _Hint()),
          ],
        ),
      ),
    );
  }
}

/// Pista de controles en una esquina.
class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          'WASD mover · Mayús correr · Arrastrar / Q-E cámara · Rueda zoom',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
