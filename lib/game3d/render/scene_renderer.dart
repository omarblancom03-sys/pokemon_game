import 'package:flutter/widgets.dart';

import '../sim/world3d_sim.dart';
import 'scene3d_view.dart';

/// Puerta de entrada al motor 3D. La pantalla no sabe qué motor dibuja el
/// mundo: pide la vista a esta interfaz. Así el motor se puede cambiar
/// (o sustituir por uno falso en los tests, donde no hay GPU).
abstract interface class SceneRenderer {
  /// Vista que dibuja [sim] y la hace avanzar en cada fotograma.
  Widget buildView(World3DSim sim);
}

/// Implementación real: flutter_scene (Flutter GPU en Windows, WebGL2 en web).
class FlutterSceneRenderer implements SceneRenderer {
  const FlutterSceneRenderer();

  @override
  Widget buildView(World3DSim sim) => Scene3DView(sim: sim);
}
