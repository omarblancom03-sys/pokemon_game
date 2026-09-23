import 'package:flutter/widgets.dart';
import 'package:pokemon_game/game3d/render/scene_renderer.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';

/// Renderer falso: en los tests no hay GPU, así que se dibuja una caja vacía.
/// Guarda la simulación recibida para que el test pueda inspeccionarla.
class FakeSceneRenderer implements SceneRenderer {
  World3DSim? lastSim;

  @override
  Widget buildView(World3DSim sim) {
    lastSim = sim;
    return const SizedBox.expand(key: Key('fake_scene'));
  }
}
