import 'package:flutter_scene/scene.dart';

import '../../models/poke_ball.dart';
import '../mesh/ball_mesh.dart';
import '../mesh/mesh_builder.dart';

/// Una Poké Ball (o media) lista para el motor: una geometría por cada
/// [BallSurface], cada una con su propio material PBR (la carcasa brilla
/// como plástico, la franja es mate...). Las geometrías y los materiales se
/// crean UNA vez y se comparten entre todas las bolas del mismo tipo.
class BallModel {
  BallModel(this.type, BallPieces pieces)
    : _geometries = {
        for (final MapEntry(:key, :value) in pieces.entries)
          key: _geometry(value),
      };

  final PokeBallType type;
  final Map<BallSurface, MeshGeometry> _geometries;
  late final Map<BallSurface, PhysicallyBasedMaterial> _materials = {
    for (final surface in _geometries.keys) surface: material(surface),
  };

  /// Un material NUEVO para [surface], con el brillo de la ficha.
  PhysicallyBasedMaterial material(BallSurface surface) =>
      PhysicallyBasedMaterial()
        ..metallicFactor = 0
        ..roughnessFactor = surface.roughnessFor(type);

  /// Una malla nueva. Con [replace] alguna pieza usa un material propio
  /// (p. ej. el botón de una bola lanzada, que se enciende él solo).
  Mesh mesh({Map<BallSurface, Material> replace = const {}}) => Mesh.primitives(
    primitives: [
      for (final MapEntry(:key, :value) in _geometries.entries)
        MeshPrimitive(value, replace[key] ?? _materials[key]!),
    ],
  );

  static MeshGeometry _geometry(MeshBuffers buffers) {
    final engine = buffers.toEngineSpace();
    return MeshGeometry.fromArrays(
      positions: engine.positions,
      normals: engine.normals,
      colors: engine.colors,
      indices: engine.indices,
    );
  }
}
