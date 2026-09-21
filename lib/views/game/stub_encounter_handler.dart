import 'package:flutter/material.dart';

import '../../controllers/encounter/encounter_handler.dart';
import '../../models/pokemon.dart';
import '../common/pokemon_formatters.dart';

/// Implementación PROVISIONAL del contrato de encuentro (la secuencia de
/// captura es la parte del compañero).
///
/// "Stub" = pieza de relleno que cumple el contrato para poder probar el
/// flujo completo de punta a punta. Para sustituirla, basta con cambiarla
/// en `app/dependencies.dart`.
class StubEncounterHandler implements EncounterHandler {
  StubEncounterHandler({required this._navigatorKey});

  /// Llave del navegador: permite abrir el diálogo desde aquí, que no es
  /// un widget y por tanto no tiene BuildContext propio.
  final GlobalKey<NavigatorState> _navigatorKey;

  @override
  Future<EncounterOutcome> handleEncounter(Pokemon pokemon) async {
    final context = _navigatorKey.currentContext;
    if (context == null) return EncounterOutcome.fled;

    final outcome = await showDialog<EncounterOutcome>(
      context: context,
      // No se puede cerrar tocando fuera: hay que decidir.
      barrierDismissible: false,
      builder: (_) => _EncounterDialog(pokemon: pokemon),
    );
    // Si se cerrara sin respuesta, se da por huido: así esta función
    // SIEMPRE devuelve algo y el juego siempre se reanuda.
    return outcome ?? EncounterOutcome.fled;
  }
}

/// El diálogo "¡Un X salvaje apareció!" con los botones Huir y Atrapar.
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
        // pop(valor): cierra el diálogo devolviendo el resultado, que es lo
        // que completa el Future que el GameController está esperando.
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
