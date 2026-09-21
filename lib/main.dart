import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/dependencies.dart';

// Punto de entrada: todo programa Dart empieza en main().
void main() {
  // AppDependencies.create() construye los servicios y controladores.
  // runApp() pinta el widget raíz en la pantalla.
  runApp(PokemonGameApp(dependencies: AppDependencies.create()));
}
