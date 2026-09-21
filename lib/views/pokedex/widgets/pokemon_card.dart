import 'package:flutter/material.dart';

import '../../../models/pokemon.dart';
import '../../../models/pokemon_type.dart';
import '../../common/pokemon_formatters.dart';

/// VISTA: la carta tipo coleccionable. Recibe un Pokémon y lo dibuja:
/// marco del color de su tipo, número, ilustración, nombre y chips de tipo.
///
/// No pide nada ni decide nada: es un widget "puro".
class PokemonCard extends StatelessWidget {
  const PokemonCard({super.key, required this.pokemon});

  final Pokemon pokemon;

  @override
  Widget build(BuildContext context) {
    // Color principal = el del primer tipo (por eso importa el orden).
    final primary = pokemon.types.isEmpty
        ? PokemonType.unknown.color
        : pokemon.types.first.color;
    // Segundo color: el del tipo secundario o el principal oscurecido.
    final secondary = pokemon.types.length > 1
        ? pokemon.types[1].color
        : Color.lerp(primary, Colors.black, 0.35)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Degradado del marco entre los dos colores.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, secondary],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: const Color(0xFF1E2A44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Artwork(pokemon: pokemon, glow: primary),
                ),
                _NameBanner(name: displayName(pokemon.name), color: primary),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final type in pokemon.types) _TypeChip(type: type),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La ilustración, con resplandor detrás y el número arriba a la izquierda.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.pokemon, required this.glow});

  final Pokemon pokemon;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    final url = pokemon.imageUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [glow.withValues(alpha: 0.55), Colors.transparent],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: url == null
              ? const _ImageFallback()
              // Image.network descarga la imagen de internet.
              : Image.network(
                  url,
                  fit: BoxFit.contain,
                  // Mientras baja: una ruedecita.
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                  // Si falla: icono de Pokébola en vez de un hueco roto.
                  errorBuilder: (_, _, _) => const _ImageFallback(),
                ),
        ),
        Positioned(
          top: 6,
          left: 6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                dexNumber(pokemon.id), // "#025"
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Icono de repuesto cuando no hay imagen o falla la descarga.
class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.catching_pokemon, color: Colors.white24, size: 48);
}

/// Franja con el nombre del Pokémon.
class _NameBanner extends StatelessWidget {
  const _NameBanner({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Color.lerp(color, Colors.black, 0.25)!,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
        child: Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          // Si el nombre no cabe, se corta con puntos suspensivos.
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            shadows: [Shadow(blurRadius: 2, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta de un tipo, con su color oficial.
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final PokemonType type;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: type.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          type.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
