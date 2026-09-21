import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/pokedex_controller.dart';
import '../common/error_view.dart';
import '../common/pokemon_formatters.dart';
import 'widgets/pokemon_card.dart';

/// VISTA: la galería completa de Pokémon, con scroll infinito.
///
/// Aquí NO hay ninguna llamada a internet: solo se lee el estado del
/// controlador y se le avisa cuando hace falta otra página.
///
/// Es StatefulWidget porque guarda el ScrollController entre repintados.
class PokedexScreen extends StatefulWidget {
  const PokedexScreen({super.key});

  @override
  State<PokedexScreen> createState() => _PokedexScreenState();
}

class _PokedexScreenState extends State<PokedexScreen> {
  /// Pide la página siguiente cuando faltan estos píxeles para el final,
  /// para que las cartas ya estén listas al llegar.
  static const _loadMoreThreshold = 600.0;

  /// Cuadrícula responsiva: tantas columnas como quepan con cartas de
  /// 190 px como máximo.
  static const _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 190,
    childAspectRatio: 0.72,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
  );

  final _scrollController = ScrollController();

  /// initState: una sola vez, al crear la pantalla.
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    // Se pide la primera página DESPUÉS del primer fotograma: cambiar el
    // estado mientras se construye la interfaz es un error en Flutter.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PokedexController>().loadInitial();
    });
  }

  /// dispose: al salir, se libera el controlador de scroll.
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // extentAfter = cuánto queda por debajo de lo que se ve.
    if (position.extentAfter < _loadMoreThreshold) {
      // read (no watch): aquí solo se llama a un método.
      context.read<PokedexController>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch: redibuja esta pantalla cada vez que el controlador avisa.
    final controller = context.watch<PokedexController>();

    // En pantallas grandes una página puede no llenar la ventana; sin
    // scroll no habría evento y la galería se quedaría a 30 cartas.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeLoadMore();
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F1A30),
      appBar: AppBar(
        title: Text(
          controller.total == null
              ? 'Pokédex'
              : 'Pokédex · ${controller.items.length}/${controller.total}',
        ),
      ),
      body: _buildBody(controller),
    );
  }

  /// Qué se pinta según el estado del controlador.
  Widget _buildBody(PokedexController controller) {
    // 1) No hay nada y falló: error a pantalla completa.
    if (controller.hasInitialError) {
      return ErrorView(
        message: errorMessage(controller.error!),
        onRetry: controller.retry,
        retryKey: const Key('pokedex_retry'),
      );
    }

    // Slivers: listas "perezosas", solo construyen lo que se ve.
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: controller.isInitialLoading
              // 2) Primera carga: 12 esqueletos grises.
              ? SliverGrid.builder(
                  gridDelegate: _gridDelegate,
                  itemCount: 12,
                  itemBuilder: (_, _) => const _SkeletonCard(),
                )
              // 3) Normal: las cartas.
              : SliverGrid.builder(
                  gridDelegate: _gridDelegate,
                  itemCount: controller.items.length,
                  itemBuilder: (_, index) =>
                      PokemonCard(pokemon: controller.items[index]),
                ),
        ),
        if (!controller.isInitialLoading)
          SliverToBoxAdapter(child: _Footer(controller: controller)),
      ],
    );
  }
}

/// Pie de la lista: rueda si carga, error pequeño si falló, o el aviso de
/// que ya no queda nada por cargar.
class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final PokedexController controller;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (controller.isLoading) {
      child = const CircularProgressIndicator();
    } else if (controller.error != null) {
      child = ErrorView(
        message: errorMessage(controller.error!),
        onRetry: controller.retry,
        retryKey: const Key('pokedex_retry'),
        compact: true,
      );
    } else if (!controller.hasMore) {
      child = const Text(
        '¡Pokédex completa!',
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

/// Hueco gris con la forma de una carta, mientras llega la primera página.
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
