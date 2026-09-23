import 'package:flutter/material.dart';

/// VISTA: exploración en 3D (tercera persona). Por ahora es una pantalla
/// temporal; el motor se conecta en la Fase 8.1.
class Game3DScreen extends StatelessWidget {
  const Game3DScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jugar 3D')),
      body: const Center(child: Text('Mundo 3D en construcción')),
    );
  }
}
