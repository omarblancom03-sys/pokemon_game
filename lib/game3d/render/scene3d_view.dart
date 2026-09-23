import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../mesh/mesh_builder.dart';
import '../mesh/terrain_mesh.dart';
import '../sim/world3d_sim.dart';

/// VISTA 3D: dibuja la [World3DSim] con flutter_scene.
///
/// Es la ÚNICA pieza que toca el motor. En cada fotograma: avanza la
/// simulación, copia la posición del jugador a su nodo y coloca la cámara.
/// El motor necesita preparar sus shaders antes de dibujar
/// ([Scene.initializeStaticResources]); hasta entonces, indicador de carga.
class Scene3DView extends StatefulWidget {
  const Scene3DView({super.key, required this.sim});

  final World3DSim sim;

  @override
  State<Scene3DView> createState() => _Scene3DViewState();
}

class _Scene3DViewState extends State<Scene3DView> {
  Scene? _scene;
  late Node _player;
  Object? _error;

  World3DSim get _sim => widget.sim;

  @override
  void initState() {
    super.initState();
    Scene.initializeStaticResources().then(
      (_) {
        if (mounted) setState(() => _scene = _buildScene());
      },
      onError: (Object error) {
        if (mounted) setState(() => _error = error);
      },
    );
  }

  Scene _buildScene() {
    final scene = Scene()
      ..directionalLight = DirectionalLight(
        direction: _toEngine(vm.Vector3(-0.45, -1, 0.35)),
        castsShadow: true,
      )
      ..skybox = Skybox(
        GradientSkySource(
          zenithColor: vm.Vector3(0.18, 0.42, 0.9),
          horizonColor: vm.Vector3(0.75, 0.87, 1),
          groundColor: vm.Vector3(0.3, 0.45, 0.25),
        ),
      );

    final tile = _sim.config.tileSize;
    scene.add(Node(mesh: _mesh(buildTerrain(_sim.layout, tile))));

    // Provisional (8.2): obstáculos como cajas; en 8.3 llegan los modelos.
    final blocks = MeshBuilder();
    for (var row = 0; row < _sim.layout.rows; row++) {
      for (var col = 0; col < _sim.layout.columns; col++) {
        if (_sim.layout.isWalkable(col, row)) continue;
        blocks.box(
          vm.Vector3(col * tile + 0.1, 0, row * tile + 0.1),
          vm.Vector3((col + 1) * tile - 0.1, 1.6, (row + 1) * tile - 0.1),
          srgb(0x2F6B34),
        );
      }
    }
    scene.add(Node(mesh: _mesh(blocks.build())));

    _player = Node(
      mesh: Mesh(
        CapsuleGeometry(radius: 0.35, height: 1),
        PhysicallyBasedMaterial()
          ..baseColorFactor = srgb(0xE53935)
          ..metallicFactor = 0
          ..roughnessFactor = 0.7,
      ),
    );
    scene.add(_player);
    _syncPlayer();
    return scene;
  }

  /// Simulación (mano derecha) → motor (mano izquierda): se invierte Z.
  /// Ver [MeshBuffers.toEngineSpace].
  static vm.Vector3 _toEngine(vm.Vector3 v) => vm.Vector3(v.x, v.y, -v.z);

  /// Malla del constructor → malla del motor (colores por vértice).
  static Mesh _mesh(MeshBuffers buffers) {
    final engine = buffers.toEngineSpace();
    return Mesh(
      MeshGeometry.fromArrays(
        positions: engine.positions,
        normals: engine.normals,
        colors: engine.colors,
        indices: engine.indices,
      ),
      PhysicallyBasedMaterial()
        ..metallicFactor = 0
        ..roughnessFactor = 0.9,
    );
  }

  void _syncPlayer() {
    final p = _sim.player;
    // La cápsula mide 1.7 m y su centro está a media altura.
    _player
      ..position = _toEngine(p.position + vm.Vector3(0, 0.85, 0))
      // Con Z invertida, el giro también cambia de signo.
      ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), -p.facing);
  }

  void _tick(Duration _, double dt) {
    // Un salto grande (pestaña en segundo plano) no debe teletransportar.
    _sim.update(math.min(dt, 0.1));
    _syncPlayer();
  }

  Camera _camera(Duration _) {
    final feet = _sim.player.position;
    return PerspectiveCamera(
      position: _toEngine(_sim.camera.eyeFor(feet)),
      target: _toEngine(_sim.camera.targetFor(feet)),
      fovRadiansY: 55 * math.pi / 180,
      fovFar: 400,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scene = _scene;
    if (_error != null) {
      return Center(child: Text('No se pudo iniciar el 3D: $_error'));
    }
    if (scene == null) return const Center(child: CircularProgressIndicator());
    return SceneView(scene, onTick: _tick, cameraBuilder: _camera);
  }
}
