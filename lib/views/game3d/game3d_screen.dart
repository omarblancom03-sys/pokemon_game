import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/field_controller.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/trainer_controller.dart';
import '../../game/input/movement_input.dart';
import '../../game/map/map_layout.dart';
import '../../game/map/world_map.dart';
import '../../game3d/render/scene_renderer.dart';
import '../../game3d/sim/camera_input.dart';
import '../../game3d/sim/world3d_sim.dart';
import '../game/widgets/d_pad.dart';
import '../game/widgets/encounter_overlay.dart';
import 'widgets/field_hud.dart';

/// VISTA: exploración en 3D (tercera persona).
///
/// Crea la simulación una sola vez y hace de PUENTE con [GameController],
/// igual que la pantalla 2D:
///  - mundo → controlador: tocó un Pokémon visible / encuentro en la hierba.
///  - controlador → mundo: pausa mientras dura el encuentro, y quitar el
///    Pokémon del mapa cuando termina (stream smokeConsumed).
/// Además traduce teclado, ratón y D-pad a las "intenciones" de la
/// simulación. El dibujo lo hace el [SceneRenderer] que llega por provider.
class Game3DScreen extends StatefulWidget {
  const Game3DScreen({super.key});

  @override
  State<Game3DScreen> createState() => _Game3DScreenState();
}

class _Game3DScreenState extends State<Game3DScreen> {
  late final GameController _controller;
  late final FieldController _field;
  late final World3DSim _sim;
  late final StreamSubscription<String> _consumedSub;

  @override
  void initState() {
    super.initState();
    _controller = context.read<GameController>();
    _field = context.read<FieldController>();
    // Igual que en 2D: si se creara en build(), cada repintado reiniciaría.
    _sim = World3DSim(
      layout: MapLayout.parse(worldMapRows),
      spawnWild: _controller.pickWildPokemon,
      // unawaited: el mundo no espera; sigue dibujándose durante el encuentro.
      onWildContact: (wild) =>
          unawaited(_controller.onWildEncounter(wild.id, wild.pokemon)),
      onGrassEncounter: () => unawaited(_controller.onGrassEncounter()),
      onEvent: _field.onWorldEvent,
    );
    _controller.addListener(_syncPause);
    _consumedSub = _controller.smokeConsumed.listen(_sim.removeWild);
  }

  void _syncPause() => _sim.setPaused(_controller.isPaused);

  @override
  void dispose() {
    _controller.removeListener(_syncPause);
    unawaited(_consumedSub.cancel());
    _sim.dispose();
    super.dispose();
  }

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
    final controller = context.watch<GameController>();
    final trainer = context.read<TrainerController>();
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
            Positioned(
              left: 16,
              top: 16,
              child: ListenableBuilder(
                listenable: trainer,
                builder: (_, _) => BagBar(trainer: trainer),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 16,
              child: IgnorePointer(
                child: ListenableBuilder(
                  listenable: _field,
                  builder: (_, _) => NoticeStack(field: _field),
                ),
              ),
            ),
            Positioned.fill(
              child: EncounterOverlay(
                controller: controller,
                loadingMessage: '¡Algo se mueve entre la hierba…!',
              ),
            ),
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
          'WASD mover · Mayús correr · Arrastrar / Q-E cámara · Rueda zoom\n'
          'Busca Pokémon en la hierba alta',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
