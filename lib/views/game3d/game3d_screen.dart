import 'dart:async';

import 'package:flutter/foundation.dart';
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

import '../../models/poke_ball.dart';
import '../game/widgets/d_pad.dart';
import '../game/widgets/encounter_overlay.dart';
import 'widgets/world_overlay.dart';
import 'widgets/field_hud.dart';

/// VISTA: exploración en 3D (tercera persona) y captura con Poké Balls.
///
/// Crea la simulación una sola vez y hace de PUENTE con los controladores:
///  - [GameController] (encuentros, igual que en 2D): tocar un Pokémon
///    agresivo pausa el mundo hasta que termina el encuentro.
///  - [FieldController] (captura): lo que pasa en el mundo (recoger bolas,
///    capturas...) va a la bolsa; y al lanzar se saca una bola de ella.
/// Además traduce teclado, ratón, D-pad y botones a las "intenciones" de
/// la simulación. El dibujo lo hace el [SceneRenderer] que llega por
/// provider.
class Game3DScreen extends StatefulWidget {
  const Game3DScreen({super.key});

  @override
  State<Game3DScreen> createState() => _Game3DScreenState();
}

class _Game3DScreenState extends State<Game3DScreen> {
  late final GameController _controller;
  late final FieldController _field;
  late final TrainerController _trainer;
  late final World3DSim _sim;
  late final StreamSubscription<String> _consumedSub;

  // Apuntar se puede pedir a la vez con el ratón, la tecla y el botón.
  bool _aimMouse = false;
  bool _aimKey = false;
  bool _aimButton = false;

  // Para distinguir un clic (lanzar) de un arrastre (girar la cámara).
  int _buttons = 0;
  double _dragDistance = 0;
  Duration _primaryAt = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = context.read<GameController>();
    _field = context.read<FieldController>();
    _trainer = context.read<TrainerController>();
    // Igual que en 2D: si se creara en build(), cada repintado reiniciaría.
    _sim = World3DSim(
      layout: MapLayout.parse(worldMapRows),
      spawnWild: _field.pickWildSpawn,
      // unawaited: el mundo no espera; sigue dibujándose durante el encuentro.
      onWildContact: (wild) =>
          unawaited(_controller.onWildEncounter(wild.id, wild.pokemon)),
      onGrassEncounter: () => unawaited(_controller.onGrassEncounter()),
      onEvent: _field.onWorldEvent,
    );
    _controller.addListener(_syncPause);
    _consumedSub = _controller.smokeConsumed.listen(_sim.removeWild);
    _trainer.addListener(_syncReadyBall);
    _syncReadyBall();
    // En web, el clic derecho es para apuntar, no para el menú del navegador.
    if (kIsWeb) unawaited(BrowserContextMenu.disableContextMenu());
  }

  void _syncPause() => _sim.setPaused(_controller.isPaused);

  /// La bola que se ve en la mano / con la que se calcula la probabilidad.
  void _syncReadyBall() => _sim.readyBall =
      _trainer.count(_trainer.selected) > 0 ? _trainer.selected : null;

  void _syncAim() => _sim.aiming = _aimMouse || _aimKey || _aimButton;

  /// Agacharse / levantarse (sigilo).
  void _toggleCrouch() => setState(() => _sim.crouching = !_sim.crouching);

  /// Lanzar: saca una bola de la bolsa (si hay) y la simulación la lanza.
  void _throw() {
    if (!_sim.canThrow) return;
    final ball = _field.takeBallToThrow();
    if (ball != null) _sim.throwBall(ball);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncPause);
    _trainer.removeListener(_syncReadyBall);
    unawaited(_consumedSub.cancel());
    _sim.dispose();
    if (kIsWeb) unawaited(BrowserContextMenu.enableContextMenu());
    super.dispose();
  }

  /// Teclas → movimiento, cámara y captura. El movimiento se recalcula con
  /// TODAS las teclas pulsadas, así soltar una no deja otra "pegada".
  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;
    final down = event is KeyDownEvent;
    if (key == LogicalKeyboardKey.keyF) {
      _aimKey = event is! KeyUpEvent;
      _syncAim();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      if (down) _throw();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyC ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight) {
      if (down) _toggleCrouch();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyR) {
      if (down) _trainer.selectNext();
      return KeyEventResult.handled;
    }
    final slot = _ballKeys.indexOf(key);
    if (slot >= 0) {
      final type = PokeBallType.values[slot];
      if (down && _trainer.count(type) > 0) _trainer.select(type);
      return KeyEventResult.handled;
    }
    if (!MovementInput.isMovementKey(key) && !CameraInput.isCameraKey(key)) {
      return KeyEventResult.ignored;
    }
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    _sim.input.setKeyboardDirection(MovementInput.directionFromKeys(pressed));
    _sim.cameraInput.updateFromKeys(pressed);
    return KeyEventResult.handled;
  }

  static const _ballKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
  ];

  // Ratón: arrastrar con cualquier botón gira la cámara; clic derecho
  // mantenido = apuntar; clic izquierdo (sin arrastrar) = lanzar.
  //
  // Ojo: el ratón es UN solo puntero. Si ya hay un botón pulsado, pulsar
  // otro no crea un "down" nuevo: solo cambian los botones de los eventos
  // de movimiento. Por eso se miran las TRANSICIONES de los botones.
  void _onButtons(PointerEvent event) {
    final cancelled = event is PointerCancelEvent;
    final buttons = event is PointerUpEvent || cancelled ? 0 : event.buttons;
    final pressed = buttons & ~_buttons;
    final released = _buttons & ~buttons;
    _buttons = buttons;
    if (pressed & kPrimaryButton != 0) {
      _primaryAt = event.timeStamp;
      _dragDistance = 0;
    }
    // Con el ratón, un clic lanza; en pantallas táctiles se usa el botón.
    if (released & kPrimaryButton != 0 &&
        !cancelled &&
        event.kind == PointerDeviceKind.mouse &&
        event.timeStamp - _primaryAt < _clickTime &&
        _dragDistance < 8) {
      _throw();
    }
    final aim = buttons & kSecondaryMouseButton != 0;
    if (aim != _aimMouse) {
      _aimMouse = aim;
      _syncAim();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    _onButtons(event);
    if (event.buttons == 0) return;
    _dragDistance += event.delta.distance;
    _sim.cameraInput.addDrag(event.delta.dx, event.delta.dy);
  }

  static const _clickTime = Duration(milliseconds: 350);

  @override
  Widget build(BuildContext context) {
    final renderer = context.read<SceneRenderer>();
    final controller = context.watch<GameController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Jugar 3D')),
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          children: [
            Listener(
              onPointerDown: _onButtons,
              onPointerMove: _onPointerMove,
              onPointerUp: _onButtons,
              onPointerCancel: _onButtons,
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  _sim.cameraInput.addZoom(event.scrollDelta.dy * 0.01);
                }
              },
              child: renderer.buildView(_sim),
            ),
            Positioned.fill(child: WorldOverlay(sim: _sim)),
            Positioned(
              left: 16,
              bottom: 16,
              child: DPad(
                key: const Key('game3d_dpad'),
                onDirectionChanged: _sim.input.setPadDirection,
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: ListenableBuilder(
                listenable: _trainer,
                builder: (_, _) => _ThrowButtons(
                  ball: _trainer.selected,
                  aiming: _aimButton,
                  crouching: _sim.crouching,
                  onCrouch: _toggleCrouch,
                  onAim: () {
                    setState(() => _aimButton = !_aimButton);
                    _syncAim();
                  },
                  onThrow: _throw,
                ),
              ),
            ),
            const Positioned(right: 16, top: 16, child: _Hint()),
            Positioned(
              left: 16,
              top: 16,
              child: ListenableBuilder(
                listenable: _trainer,
                builder: (_, _) => BagBar(trainer: _trainer),
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

/// Botones táctiles: agacharse y apuntar (se quedan activos) y lanzar la
/// bola elegida.
class _ThrowButtons extends StatelessWidget {
  const _ThrowButtons({
    required this.ball,
    required this.aiming,
    required this.crouching,
    required this.onCrouch,
    required this.onAim,
    required this.onThrow,
  });

  final PokeBallType ball;
  final bool aiming;
  final bool crouching;
  final VoidCallback onCrouch;
  final VoidCallback onAim;
  final VoidCallback onThrow;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          key: const Key('game3d_crouch'),
          heroTag: null,
          tooltip: 'Agacharse (C / Ctrl)',
          backgroundColor: crouching ? Colors.greenAccent : Colors.black54,
          foregroundColor: crouching ? Colors.black : Colors.white,
          onPressed: onCrouch,
          child: const Icon(Icons.accessibility_new),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          key: const Key('game3d_aim'),
          heroTag: null,
          tooltip: 'Apuntar (clic derecho / F)',
          backgroundColor: aiming ? Colors.amber : Colors.black54,
          foregroundColor: aiming ? Colors.black : Colors.white,
          onPressed: onAim,
          child: const Icon(Icons.center_focus_strong),
        ),
        const SizedBox(width: 12),
        FloatingActionButton.large(
          key: const Key('game3d_throw'),
          heroTag: null,
          tooltip: 'Lanzar (clic / Espacio)',
          backgroundColor: Colors.black54,
          onPressed: onThrow,
          child: BallIcon(ball, size: 44),
        ),
      ],
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
          'Clic der. / F apuntar · Clic / Espacio lanzar · R / 1-3 cambiar bola\n'
          'C agacharse: en la hierba alta no te ven · Correr hace ruido',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
