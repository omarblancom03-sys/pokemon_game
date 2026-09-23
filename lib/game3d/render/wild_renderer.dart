import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../sim/throwing.dart';
import '../sim/wild_pokemon.dart';

/// Descarga los bytes de una imagen (lo aporta la capa de servicios).
typedef ImageBytesLoader = Future<Uint8List> Function(String url);

/// Dibuja los Pokémon salvajes como CARTELES ("billboards"): un cuadrado
/// con el dibujo oficial de PokeAPI que siempre mira a la cámara, con una
/// sombra redonda en el suelo, saltitos al andar y un "pop" al aparecer.
///
/// Mientras el dibujo se descarga solo se ve la sombra y la hierba
/// moviéndose: como la hierba que se agita en los juegos clásicos.
///
/// Al ser golpeado por una Poké Ball se vuelve rojo y se encoge hacia la
/// bola; si se escapa, sale de golpe con un destello blanco.
class WildRenderer {
  WildRenderer({required this.root, required this.loadImage});

  /// Nodo de la escena donde se cuelgan los carteles.
  final Node root;
  final ImageBytesLoader loadImage;

  final Map<String, _WildVisual> _visuals = {};
  final Map<String, Future<Texture2D?>> _textures = {};

  static final _y = vm.Vector3(0, 1, 0);

  /// Sincroniza los carteles con la lista de la simulación. [balls] sirve
  /// para saber hacia dónde encoger a los que están siendo absorbidos.
  void update(
    List<WildPokemon> wild,
    List<ThrownBall> balls,
    double cameraYaw,
    double time,
  ) {
    final ballsById = {for (final b in balls) b.id: b};
    // Quitar los que ya no están.
    final alive = {for (final w in wild) w.id};
    for (final id in _visuals.keys.toList()) {
      if (!alive.contains(id)) root.remove(_visuals.remove(id)!.node);
    }
    for (final w in wild) {
      final visual = _visuals[w.id] ??= _create(w);
      _place(visual, w, cameraYaw, time, ballsById[w.capturedBy]);
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
    final visual = _WildVisual(
      node: node,
      sprite: sprite,
      shadow: shadow,
      material: UnlitMaterial()
        ..alphaMode = AlphaMode.blend
        ..vertexColorWeight = 0,
    );

    final url = w.pokemon.imageUrl;
    if (url != null) {
      unawaited(
        _textureFor(url).then((texture) {
          if (texture == null || !_visuals.containsKey(w.id)) return;
          visual.material.baseColorTexture = texture;
          visual.sprite.mesh = Mesh(_quad(), visual.material);
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

  void _place(
    _WildVisual v,
    WildPokemon w,
    double cameraYaw,
    double time,
    ThrownBall? ball,
  ) {
    final p = w.position;
    final h = w.displayHeight;
    // "Pop" de entrada: crece con un pequeño rebote durante 0,45 s.
    final t = (w.age / 0.45).clamp(0.0, 1.0);
    var pop = t >= 1
        ? 1.0
        : math.sin(t * math.pi * 0.75) / math.sin(math.pi * 0.75);
    var tint = vm.Vector4(1, 1, 1, 1);
    var offset = vm.Vector3(0, w.hopHeight, 0);

    // Dentro de una bola: rojo, encogiéndose hacia ella; luego invisible.
    if (!w.isFree) {
      final absorbed = ball?.absorbProgress ?? 1;
      pop = math.pow(1 - absorbed, 1.5).toDouble();
      tint = vm.Vector4(
        1 + 2.5 * absorbed,
        1 - 0.7 * absorbed,
        1 - 0.7 * absorbed,
        1,
      );
      if (ball != null) {
        final to = ball.position - p;
        offset = vm.Vector3(to.x, to.y - ballRadius, -to.z) * absorbed;
      }
    }
    // Recién escapado: sale de golpe (un poco más grande) y blanco.
    final released = w.releasedFor;
    if (released != null) {
      final r = (released / 0.6).clamp(0.0, 1.0);
      pop = math.min(1, r / 0.25) * (1 + 0.25 * math.sin(r * math.pi));
      final glow = 2.5 * (1 - r);
      tint = vm.Vector4(1 + glow, 1 + glow, 1 + glow, 1);
    }
    v.material.baseColorFactor = tint;
    // Respiración: se estira un poco arriba y abajo cuando está quieto.
    final breathe = 1 + 0.035 * math.sin(time * 3 + w.id.hashCode % 7);

    v.node.position = vm.Vector3(p.x, 0, -p.z); // espacio del motor
    v.shadow
      ..position = vm.Vector3(0, 0.02, 0)
      ..scale = vm.Vector3(h * 0.7 * pop, 1, h * 0.45 * pop);
    v.sprite
      ..position = offset
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
  _WildVisual({
    required this.node,
    required this.sprite,
    required this.shadow,
    required this.material,
  });

  final Node node;
  final Node sprite;
  final Node shadow;

  /// Material propio del cartel (para teñirlo al capturarlo).
  final UnlitMaterial material;
}
