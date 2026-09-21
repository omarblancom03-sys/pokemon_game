import 'package:flutter/material.dart';

import '../../../controllers/game_controller.dart';
import '../../common/pokemon_formatters.dart';

/// Loading and error feedback while a random Pokémon is being resolved.
/// The encounter itself is presented by the `EncounterHandler`.
class EncounterOverlay extends StatelessWidget {
  const EncounterOverlay({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return switch (controller.state) {
      EncounterNone() || EncounterActive() => const SizedBox.shrink(),
      EncounterResolving() => const _Panel(
        key: Key('encounter_loading'),
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('¡Algo se mueve entre el humo…!'),
        ],
      ),
      EncounterFailed(:final error) => _Panel(
        key: const Key('encounter_error'),
        children: [
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 8),
          Text(errorMessage(error), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: controller.cancel,
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const Key('encounter_retry'),
                onPressed: controller.retry,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ],
      ),
    };
  }
}

class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black38,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}
