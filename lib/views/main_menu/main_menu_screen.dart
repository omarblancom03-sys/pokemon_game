import 'package:flutter/material.dart';

import '../../app/app.dart';

/// VISTA: menú principal. Tres botones que navegan a las otras pantallas.
///
/// StatelessWidget = no guarda nada que cambie; solo se dibuja.
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  /// build() describe la pantalla devolviendo widgets.
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Scaffold = esqueleto de pantalla (barra, cuerpo, etc.).
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          // Ancho máximo para que en pantallas grandes no se estire.
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pokémon Game',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineLarge,
                ),
                const SizedBox(height: 48),
                FilledButton.icon(
                  // Las Key sirven para que los tests encuentren el botón.
                  key: const Key('menu_play'),
                  // pushNamed apila la pantalla del juego encima de esta.
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.game),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Jugar'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('menu_pokedex'),
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.pokedex),
                  icon: const Icon(Icons.catching_pokemon),
                  label: const Text('Pokédex'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('menu_generations'),
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.generations),
                  icon: const Icon(Icons.format_list_numbered),
                  label: const Text('Generaciones'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
