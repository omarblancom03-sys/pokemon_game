import 'package:flutter/material.dart';

import '../../../controllers/field_controller.dart';
import '../../../controllers/trainer_controller.dart';
import '../../../models/pokemon.dart';
import '../../../models/pokemon_type.dart';
import '../../common/pokemon_formatters.dart';
import '../../pokedex/widgets/pokemon_card.dart';
import 'field_hud.dart' show BallIcon;

/// TARJETA "¡Capturado!": el premio de una captura. Enseña el arte oficial
/// del Pokémon, su nombre, número y tipos, la bola con la que se atrapó y
/// "¡Nuevo!" si es la primera vez que se captura esa especie.
///
/// Solo pinta los datos del aviso ([FieldNotice]); no pide nada a nadie
/// (la imagen la descarga el propio widget de imagen, como en la Pokédex).
class CaptureCard extends StatelessWidget {
  const CaptureCard({super.key, required this.notice});

  final FieldNotice notice;

  @override
  Widget build(BuildContext context) {
    final pokemon = notice.pokemon!;
    final primary = pokemon.types.isEmpty
        ? PokemonType.unknown.color
        : pokemon.types.first.color;
    return Container(
      key: const Key('capture_card'),
      width: 320,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [primary, Color.lerp(primary, Colors.black, 0.4)!],
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xEE1E2A44),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
          child: Row(
            children: [
              _Art(pokemon: pokemon, glow: primary),
              const SizedBox(width: 10),
              Expanded(
                child: _Details(notice: notice, pokemon: pokemon),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Art extends StatelessWidget {
  const _Art({required this.pokemon, required this.glow});

  final Pokemon pokemon;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    final url = pokemon.imageUrl;
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [glow.withValues(alpha: 0.6), Colors.transparent],
        ),
      ),
      child: url == null
          ? const Icon(Icons.catching_pokemon, color: Colors.white54, size: 40)
          : Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.catching_pokemon,
                color: Colors.white54,
                size: 40,
              ),
            ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.notice, required this.pokemon});

  final FieldNotice notice;
  final Pokemon pokemon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text(
              '¡Capturado!',
              style: TextStyle(
                color: Colors.lightGreenAccent,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            if (notice.isNew)
              Container(
                key: const Key('capture_card_new'),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '¡Nuevo!',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Flexible(
              child: Text(
                displayName(pokemon.name),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                ),
              ),
            ),
            if (notice.ball != null) ...[
              const SizedBox(width: 6),
              BallIcon(notice.ball!, size: 16),
            ],
          ],
        ),
        Text(
          dexNumber(pokemon.id),
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final type in pokemon.types)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: type.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  type.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// PANEL "Mis capturas": todas las cartas de los Pokémon capturados (la
/// misma carta que la Pokédex) con la bola con que se atraparon. Escucha al
/// [TrainerController], así que se actualiza solo.
class CapturesPanel extends StatelessWidget {
  const CapturesPanel({super.key, required this.trainer});

  final TrainerController trainer;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('captures_panel'),
      backgroundColor: const Color(0xFF0F1A30),
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 560),
        child: ListenableBuilder(
          listenable: trainer,
          builder: (context, _) {
            final captured = trainer.captured;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
                  child: Row(
                    children: [
                      Text(
                        'Mis capturas (${captured.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        key: const Key('captures_close'),
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (captured.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, 40),
                    child: Text(
                      'Aún no has capturado ningún Pokémon.\n'
                      'Apunta con clic derecho (o F) y lanza una Poké Ball a '
                      'uno que no te haya visto: por la espalda es más fácil.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  )
                else
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 170,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: captured.length,
                      itemBuilder: (_, i) => Stack(
                        children: [
                          Positioned.fill(
                            child: PokemonCard(pokemon: captured[i].pokemon),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: BallIcon(captured[i].ball, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
