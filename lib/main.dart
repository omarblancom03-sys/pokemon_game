import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/dependencies.dart';

void main() {
  runApp(PokemonGameApp(dependencies: AppDependencies.create()));
}
