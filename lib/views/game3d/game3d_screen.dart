import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../game3d/render/scene_renderer.dart';

/// VISTA: exploración en 3D (tercera persona). El dibujo lo hace el
/// [SceneRenderer] que llega por provider.
class Game3DScreen extends StatelessWidget {
  const Game3DScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final renderer = context.read<SceneRenderer>();
    return Scaffold(
      appBar: AppBar(title: const Text('Jugar 3D')),
      body: renderer.buildView(),
    );
  }
}
