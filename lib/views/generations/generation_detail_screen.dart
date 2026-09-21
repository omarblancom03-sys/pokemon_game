import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/generation_detail_controller.dart';
import '../../services/pokemon_repository.dart';
import '../common/error_view.dart';
import '../common/pokemon_formatters.dart';
import '../pokedex/widgets/pokemon_card.dart';
import '../pokemon_detail/pokemon_detail_screen.dart';

/// VISTA (ventana 2): los Pokémon que pertenecen a una generación.
/// Funciona igual que la Pokédex, pero al tocar una carta abre el detalle.
class GenerationDetailScreen extends StatefulWidget {
  const GenerationDetailScreen({super.key, required this.title});

  /// La ruta se construye aquí y crea su PROPIO controlador, que Provider
  /// destruye al cerrar la pantalla. Quien navega no sabe que existe.
  static Route<void> route({
    required int generationId,
    required String title,
  }) => MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider(
      create: (context) => GenerationDetailController(
        repository: context.read<PokemonRepository>(),
        generationId: generationId,
      ),
      child: GenerationDetailScreen(title: title),
    ),
  );

  /// Ya formateado, por ejemplo "Generación I".
  final String title;

  @override
  State<GenerationDetailScreen> createState() => _GenerationDetailScreenState();
}

class _GenerationDetailScreenState extends State<GenerationDetailScreen> {
  /// Píxeles antes del final a los que se pide la página siguiente.
  static const _loadMoreThreshold = 600.0;

  static const _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 190,
    childAspectRatio: 0.72,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
  );

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GenerationDetailController>().loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < _loadMoreThreshold) {
      context.read<GenerationDetailController>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GenerationDetailController>();

    // En pantallas grandes una página puede no llenar la ventana y no
    // habría evento de scroll que pidiera la siguiente.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeLoadMore();
    });

    final region = controller.generation?.mainRegion;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1A30),
      appBar: AppBar(
        title: Text(
          controller.total == null
              ? widget.title
              : '${widget.title} · ${controller.items.length}/'
                    '${controller.total}',
        ),
        // La región solo se muestra cuando ya se conoce.
        bottom: region == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Región ${displayName(region)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
      ),
      body: _buildBody(controller),
    );
  }

  Widget _buildBody(GenerationDetailController controller) {
    if (controller.hasInitialError) {
      return ErrorView(
        message: errorMessage(controller.error!),
        onRetry: controller.retry,
        retryKey: const Key('generation_detail_retry'),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: controller.isInitialLoading
              ? SliverGrid.builder(
                  gridDelegate: _gridDelegate,
                  itemCount: 12,
                  itemBuilder: (_, _) => const _SkeletonCard(),
                )
              : SliverGrid.builder(
                  gridDelegate: _gridDelegate,
                  itemCount: controller.items.length,
                  itemBuilder: (_, index) {
                    final pokemon = controller.items[index];
                    // GestureDetector: hace la carta pulsable.
                    return GestureDetector(
                      // Se le pasa el Pokémon YA cargado: el detalle no
                      // tiene que pedir nada a internet.
                      onTap: () => Navigator.of(
                        context,
                      ).push(PokemonDetailScreen.route(pokemon: pokemon)),
                      child: PokemonCard(pokemon: pokemon),
                    );
                  },
                ),
        ),
        if (!controller.isInitialLoading)
          SliverToBoxAdapter(child: _Footer(controller: controller)),
      ],
    );
  }
}

/// Pie: rueda, error pequeño o "¡Generación completa!".
class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final GenerationDetailController controller;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (controller.isLoading) {
      child = const CircularProgressIndicator();
    } else if (controller.error != null) {
      child = ErrorView(
        message: errorMessage(controller.error!),
        onRetry: controller.retry,
        retryKey: const Key('generation_detail_retry'),
        compact: true,
      );
    } else if (!controller.hasMore) {
      child = const Text(
        '¡Generación completa!',
        style: TextStyle(color: Colors.white70),
      );
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Center(child: child),
    );
  }
}

/// Hueco gris mientras llega la primera página.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
