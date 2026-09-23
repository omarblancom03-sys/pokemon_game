import 'package:flutter/widgets.dart';
import 'package:pokemon_game/game3d/render/scene_renderer.dart';

/// Renderer falso: en los tests no hay GPU, así que se dibuja una caja vacía.
class FakeSceneRenderer implements SceneRenderer {
  @override
  Widget buildView() => const SizedBox.expand(key: Key('fake_scene'));
}
