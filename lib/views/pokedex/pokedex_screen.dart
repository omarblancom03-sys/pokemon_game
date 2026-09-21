import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/pokedex_controller.dart';
import '../common/pokemon_formatters.dart';
import 'widgets/pokemon_card.dart';

class PokedexScreen extends StatefulWidget {
  const PokedexScreen({super.key});

  @override
  State<PokedexScreen> createState() => _PokedexScreenState();
}

class _PokedexScreenState extends State<PokedexScreen> {
  /// Start loading the next page this many pixels before the end.
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
      context.read<PokedexController>().loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.extentAfter < _loadMoreThreshold) {
      context.read<PokedexController>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PokedexController>();

    // On large screens a page may not fill the viewport, so no scroll event
    // would ever request the next one.
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

  Widget _buildBody(PokedexController controller) {
    if (controller.hasInitialError) {
      return _ErrorView(
        message: errorMessage(controller.error!),
        onRetry: controller.retry,
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

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final PokedexController controller;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (controller.isLoading) {
      child = const CircularProgressIndicator();
    } else if (controller.error != null) {
      child = _ErrorView(
        message: errorMessage(controller.error!),
        onRetry: controller.retry,
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact)
              const Icon(Icons.wifi_off, color: Colors.white54, size: 56),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('pokedex_retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

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
