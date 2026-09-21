import 'package:flutter/material.dart';

import '../../controllers/encounter/encounter_handler.dart';
import '../../models/pokemon.dart';
import '../common/pokemon_formatters.dart';

/// TEMPORARY stand-in for the capture sequence (partner's deliverable).
///
/// Shows which Pokémon appeared so the flow can be tested end to end.
/// Replace it in `app/dependencies.dart` with the real `EncounterHandler`.
class StubEncounterHandler implements EncounterHandler {
  StubEncounterHandler({required this._navigatorKey});

  final GlobalKey<NavigatorState> _navigatorKey;

  @override
  Future<EncounterOutcome> handleEncounter(Pokemon pokemon) async {
    final context = _navigatorKey.currentContext;
    if (context == null) return EncounterOutcome.fled;

    final outcome = await showDialog<EncounterOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EncounterDialog(pokemon: pokemon),
    );
    return outcome ?? EncounterOutcome.fled;
  }
}

class _EncounterDialog extends StatelessWidget {
  const _EncounterDialog({required this.pokemon});

  final Pokemon pokemon;

  @override
  Widget build(BuildContext context) {
    final url = pokemon.imageUrl;
    return AlertDialog(
      key: const Key('encounter_dialog'),
      title: Text('¡Un ${displayName(pokemon.name)} salvaje apareció!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (url != null)
            Image.network(
              url,
              height: 160,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.catching_pokemon, size: 96),
            ),
          Text(dexNumber(pokemon.id)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final type in pokemon.types)
                Chip(
                  label: Text(type.label),
                  backgroundColor: type.color,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Stub: aquí se conecta la animación de captura.',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(EncounterOutcome.fled),
          child: const Text('Huir'),
        ),
        FilledButton(
          key: const Key('encounter_catch'),
          onPressed: () => Navigator.of(context).pop(EncounterOutcome.caught),
          child: const Text('Atrapar'),
        ),
      ],
    );
  }
}
