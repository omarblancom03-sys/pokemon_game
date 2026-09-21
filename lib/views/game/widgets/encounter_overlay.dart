import 'package:flutter/material.dart';

import '../../../controllers/game_controller.dart';
import '../../common/pokemon_formatters.dart';

/// VISTA: la capa que se pone encima del juego mientras se resuelve un
/// encuentro (cargando) o si falla (error).
///
/// El encuentro en sí lo presenta el EncounterHandler, por eso en el estado
/// Active esta capa no pinta nada.
class EncounterOverlay extends StatelessWidget {
  const EncounterOverlay({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    // Un caso por estado; al ser sealed, el compilador obliga a cubrirlos.
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
      // Del estado fallido se saca el error para traducirlo a español.
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
                // Cancelar: se reanuda el juego y el humo sigue en el mapa.
                onPressed: controller.cancel,
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const Key('encounter_retry'),
                // Reintentar: vuelve a sortear Pokémon para el mismo humo.
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

/// Tarjeta centrada sobre un fondo oscurecido.
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
