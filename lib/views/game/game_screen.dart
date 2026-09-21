import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/game_controller.dart';
import '../../game/poke_game.dart';
import 'widgets/d_pad.dart';
import 'widgets/encounter_overlay.dart';

/// Hosts the Flame scene and bridges it with [GameController].
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
    // Created once so rebuilds do not restart the scene.
    _game = PokeGame(
      onSmokeReached: (id) => unawaited(_controller.onSmokeReached(id)),
    );
    _controller.addListener(_syncPause);
    _smokeConsumedSub = _controller.smokeConsumed.listen(_game.removeSmoke);
  }

  void _syncPause() => _game.setPaused(_controller.isPaused);

  @override
  void dispose() {
    _controller.removeListener(_syncPause);
    unawaited(_smokeConsumedSub.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Jugar')),
      body: Stack(
        children: [
          GameWidget(game: _game, autofocus: true),
          Positioned(
            left: 16,
            bottom: 16,
            child: DPad(
              key: const Key('game_dpad'),
              onDirectionChanged: _game.input.setPadDirection,
            ),
          ),
          const Positioned(right: 16, top: 16, child: _Hint()),
          Positioned.fill(child: EncounterOverlay(controller: controller)),
        ],
      ),
    );
  }
}

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
