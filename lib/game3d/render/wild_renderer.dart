import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../sim/wild_pokemon.dart';

/// Descarga los bytes de una imagen (lo aporta la capa de servicios).
typedef ImageBytesLoader = Future<Uint8List> Function(String url);

/// Dibuja los Pokémon salvajes como CARTELES ("billboards"): un cuadrado
/// con el dibujo oficial de PokeAPI que siempre mira a la cámara, con una
/// sombra redonda en el suelo, saltitos al andar y un "pop" al aparecer.
///
/// Mientras el dibujo se descarga solo se ve la sombra y la hierba
/// moviéndose: como la hierba que se agita en los juegos clásicos.
class WildRenderer {
  WildRenderer({required this.root, required this.loadImage});

  /// Nodo de la escena donde se cuelgan los carteles.
  final Node root;
  final ImageBytesLoader loadImage;

  final Map<String, _WildVisual> _visuals = {};
  final Map<String, Future<Texture2D?>> _textures = {};

  static final _y = vm.Vector3(0, 1, 0);

  /// Sincroniza los carteles con la lista de la simulación.
  void update(List<WildPokemon> wild, double cameraYaw, double time) {
    // Quitar los que ya no están.
    final alive = {for (final w in wild) w.id};
    for (final id in _visuals.keys.toList()) {
      if (!alive.contains(id)) root.remove(_visuals.remove(id)!.node);
    }
    for (final w in wild) {
      final visual = _visuals[w.id] ??= _create(w);
      _place(visual, w, cameraYaw, time);
    }
  }

  _WildVisual _create(WildPokemon w) {
    final shadow = Node(
      mesh: Mesh(
        DiscGeometry(radius: 0.5, segments: 20),
        UnlitMaterial()
          ..baseColorFactor = vm.Vector4(0, 0, 0, 0.3)
          ..alphaMode = AlphaMode.blend,
      ),
    )..castsShadows = false;
    final sprite = Node()..castsShadows = false;
    final node = Node(name: w.id)
      ..add(shadow)
      ..add(sprite);
    root.add(node);
    final visual = _WildVisual(node: node, sprite: sprite, shadow: shadow);

    final url = w.pokemon.imageUrl;
    if (url != null) {
      unawaited(
        _textureFor(url).then((texture) {
          if (texture == null || !_visuals.containsKey(w.id)) return;
          visual.sprite.mesh = Mesh(
            _quad(),
            UnlitMaterial(colorTexture: texture)
              ..alphaMode = AlphaMode.blend
              ..vertexColorWeight = 0,
          );
        }),
      );
    }
    return visual;
  }

  /// Una textura por URL (si dos Pokémon iguales aparecen, se comparte).
  Future<Texture2D?> _textureFor(String url) =>
      _textures[url] ??= _loadTexture(url);

  Future<Texture2D?> _loadTexture(String url) async {
    try {
      final bytes = await loadImage(url);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return await Texture2D.fromImage(frame.image);
    } catch (error) {
      // Sin dibujo el Pokémon sigue ahí (sombra + hierba agitándose).
      debugPrint('No se pudo cargar $url: $error');
      _textures.remove(url)?.ignore(); // permitir reintentar más tarde
      return null;
    }
  }

  void _place(_WildVisual v, WildPokemon w, double cameraYaw, double time) {
    final p = w.position;
    final h = w.displayHeight;
    // "Pop" de entrada: crece con un pequeño rebote durante 0,45 s.
    final t = (w.age / 0.45).clamp(0.0, 1.0);
    final pop = t >= 1
        ? 1.0
        : math.sin(t * math.pi * 0.75) / math.sin(math.pi * 0.75);
    // Respiración: se estira un poco arriba y abajo cuando está quieto.
    final breathe = 1 + 0.035 * math.sin(time * 3 + w.id.hashCode % 7);

    v.node.position = vm.Vector3(p.x, 0, -p.z); // espacio del motor
    v.shadow
      ..position = vm.Vector3(0, 0.02, 0)
      ..scale = vm.Vector3(h * 0.7 * pop, 1, h * 0.45 * pop);
    v.sprite
      ..position = vm.Vector3(0, w.hopHeight, 0)
      // Mirar a la cámara: el mismo giro que la cámara (signo del motor).
      ..rotation = vm.Quaternion.axisAngle(_y, -cameraYaw)
      ..scale = vm.Vector3(h * pop, h * pop * breathe, 1);
  }

  /// Cuadrado de 1x1 con la base en y = 0, mirando hacia -Z del motor
  /// (hacia la cámara cuando el nodo gira como ella).
  static MeshGeometry _quad() => MeshGeometry.fromArrays(
    positions: Float32List.fromList([
      -0.5, 0, 0, // abajo izquierda
      0.5, 0, 0, // abajo derecha
      0.5, 1, 0, // arriba derecha
      -0.5, 1, 0, // arriba izquierda
    ]),
    normals: Float32List.fromList([0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1]),
    texCoords: Float32List.fromList([0, 1, 1, 1, 1, 0, 0, 0]),
    indices: const [0, 2, 1, 0, 3, 2],
  );
}

class _WildVisual {
  _WildVisual({required this.node, required this.sprite, required this.shadow});

  final Node node;
  final Node sprite;
  final Node shadow;
}
