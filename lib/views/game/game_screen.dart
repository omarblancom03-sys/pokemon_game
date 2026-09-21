import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/game_controller.dart';
import '../../game/poke_game.dart';
import 'widgets/d_pad.dart';
import 'widgets/encounter_overlay.dart';

/// VISTA: aloja la escena de Flame y hace de PUENTE con [GameController].
///
/// Las tres conexiones son:
///  - juego → controlador: callback onSmokeReached ("Ash tocó el humo X").
///  - controlador → juego: setPaused, al enterarse de que cambió el estado.
///  - controlador → juego: stream smokeConsumed ("borra ese humo").
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller;
  late final PokeGame _game;
  late final StreamSubscription<String> _smokeConsumedSub;

  @override
  void initState() {
    super.initState();
    _controller = context.read<GameController>();
    // El juego se crea UNA vez aquí: si se creara en build(), cada
    // repintado reiniciaría la partida desde cero.
    _game = PokeGame(
      // unawaited: el juego no puede quedarse esperando, debe seguir
      // dibujando mientras el controlador resuelve el encuentro.
      onSmokeReached: (id) => unawaited(_controller.onSmokeReached(id)),
    );
    _controller.addListener(_syncPause);
    _smokeConsumedSub = _controller.smokeConsumed.listen(_game.removeSmoke);
  }

  // Cada vez que el controlador avisa, el juego se pausa o se reanuda.
  void _syncPause() => _game.setPaused(_controller.isPaused);

  @override
  void dispose() {
    // Cerrar el grifo al salir: si no, quedan fugas de memoria.
    _controller.removeListener(_syncPause);
    unawaited(_smokeConsumedSub.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Jugar')),
      // Stack = capas apiladas, de abajo a arriba.
      body: Stack(
        children: [
          GameWidget(game: _game, autofocus: true), // la escena de Flame
          Positioned(
            left: 16,
            bottom: 16,
            child: DPad(
              key: const Key('game_dpad'),
              // El D-pad escribe directamente en la entrada del juego.
              onDirectionChanged: _game.input.setPadDirection,
            ),
          ),
          const Positioned(right: 16, top: 16, child: _Hint()),
          // Encima de todo: "cargando" o el error del encuentro.
          Positioned.fill(child: EncounterOverlay(controller: controller)),
        ],
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
          'Flechas / WASD o D-pad · Busca el humo',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
