import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/generations_controller.dart';
import '../../models/load_state.dart';
import '../../models/named_resource.dart';
import '../common/error_view.dart';
import '../common/pokemon_formatters.dart';
import 'generation_detail_screen.dart';

/// VISTA (ventana 1): la lista de generaciones.
class GenerationsScreen extends StatefulWidget {
  const GenerationsScreen({super.key});

  @override
  State<GenerationsScreen> createState() => _GenerationsScreenState();
}

class _GenerationsScreenState extends State<GenerationsScreen> {
  @override
  void initState() {
    super.initState();
    // Se pide la lista tras el primer fotograma (nunca dentro de build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GenerationsController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GenerationsController>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F1A30),
      appBar: AppBar(title: const Text('Generaciones')),
      // switch sobre el LoadState: un caso por estado posible.
      body: switch (controller.state) {
        LoadIdle() ||
        LoadInProgress() => const Center(child: CircularProgressIndicator()),
        // ":final error" saca el error de dentro del estado.
        LoadFailure(:final error) => ErrorView(
          message: errorMessage(error),
          onRetry: controller.retry,
          retryKey: const Key('generations_retry'),
        ),
        LoadSuccess(:final data) => _GenerationList(generations: data),
      },
    );
  }
}

/// La lista en sí, con separación entre banners.
class _GenerationList extends StatelessWidget {
  const _GenerationList({required this.generations});

  final List<NamedResource> generations;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: generations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) =>
          _GenerationTile(generation: generations[index]),
    );
  }
}

/// Banner de una generación, en el mismo estilo de carta que [PokemonCard]:
/// marco de dos tonos y el número romano como medalla.
class _GenerationTile extends StatelessWidget {
  const _GenerationTile({required this.generation});

  /// Un color por generación; si PokeAPI añadiera más, se reutilizan.
  static const _accents = [
    Color(0xFFEE8130),
    Color(0xFF6390F0),
    Color(0xFF7AC74C),
    Color(0xFFA33EA1),
    Color(0xFFF7D02C),
    Color(0xFF6F35FC),
    Color(0xFFD685AD),
    Color(0xFF40B5A5),
    Color(0xFFC22E28),
  ];

  final NamedResource generation;

  @override
  Widget build(BuildContext context) {
    // El id sale de la URL de la referencia (.../generation/1/ → 1).
    final id = generation.id;
    final accent = _accents[((id ?? 1) - 1) % _accents.length];
    final label = generationLabel(generation.name); // "Generación I"
    final numeral = generationNumeral(generation.name); // "I"

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, Color.lerp(accent, Colors.black, 0.45)!],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Material(
            color: const Color(0xFF1E2A44),
            // InkWell = zona pulsable con efecto de onda.
            child: InkWell(
              // Sin id numérico no se puede abrir (onTap null = desactivado).
              onTap: id == null
                  ? null
                  : () => Navigator.of(context).push(
                      // La pantalla de detalle se construye a sí misma
                      // (crea su propio controlador en route()).
                      GenerationDetailScreen.route(
                        generationId: id,
                        title: label,
                      ),
                    ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _Numeral(numeral: numeral, color: accent),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            generation.name,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La medalla redonda con el número romano.
class _Numeral extends StatelessWidget {
  const _Numeral({required this.numeral, required this.color});

  final String numeral;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.4)!],
        ),
      ),
      child: Text(
        numeral,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 18,
          shadows: [Shadow(blurRadius: 2, offset: Offset(0, 1))],
        ),
      ),
    );
  }
}
