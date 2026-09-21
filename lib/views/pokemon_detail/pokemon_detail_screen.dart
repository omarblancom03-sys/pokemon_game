import 'package:flutter/material.dart';

import '../../models/pokemon.dart';
import '../../models/pokemon_type.dart';
import '../common/pokemon_formatters.dart';

/// Window 3: one Pokémon in detail.
///
/// Takes an already loaded [Pokemon] — the gallery that opens this screen has
/// the full model, so there is nothing left to fetch.
class PokemonDetailScreen extends StatelessWidget {
  const PokemonDetailScreen({super.key, required this.pokemon});

  static Route<void> route({required Pokemon pokemon}) =>
      MaterialPageRoute(builder: (_) => PokemonDetailScreen(pokemon: pokemon));

  final Pokemon pokemon;

  @override
  Widget build(BuildContext context) {
    final primary = pokemon.types.isEmpty
        ? PokemonType.unknown.color
        : pokemon.types.first.color;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1A30),
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: Text(displayName(pokemon.name)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _Artwork(pokemon: pokemon, glow: primary),
          const SizedBox(height: 16),
          Center(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in pokemon.types) _TypeChip(type: type),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(
                icon: Icons.straighten,
                label: 'Altura',
                value: heightLabel(pokemon.height),
                color: primary,
              ),
              _Stat(
                icon: Icons.monitor_weight_outlined,
                label: 'Peso',
                value: weightLabel(pokemon.weight),
                color: primary,
              ),
              _Stat(
                icon: Icons.tag,
                label: 'Pokédex',
                value: dexNumber(pokemon.id),
                color: primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.pokemon, required this.glow});

  final Pokemon pokemon;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    final url = pokemon.imageUrl;

    return SizedBox(
      height: 280,
      child: Stack(
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
            padding: const EdgeInsets.all(24),
            child: url == null
                ? const _ImageFallback()
                : Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator()),
                    errorBuilder: (_, _, _) => const _ImageFallback(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.catching_pokemon, color: Colors.white24, size: 96);
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final PokemonType type;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: type.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Text(
          type.label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}
