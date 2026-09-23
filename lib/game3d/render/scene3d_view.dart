import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// VISTA 3D (spike de la Fase 8.1): un cubo iluminado girando.
///
/// Es la ÚNICA pieza que toca flutter_scene. El motor necesita preparar
/// sus shaders antes de dibujar ([Scene.initializeStaticResources]); hasta
/// entonces se muestra un indicador de carga.
class Scene3DView extends StatefulWidget {
  const Scene3DView({super.key});

  @override
  State<Scene3DView> createState() => _Scene3DViewState();
}

class _Scene3DViewState extends State<Scene3DView> {
  Scene? _scene;
  Node? _cube;
  Object? _error;
  double _elapsed = 0;

  @override
  void initState() {
    super.initState();
    Scene.initializeStaticResources().then(
      (_) {
        if (!mounted) return;
        final scene = Scene()
          ..directionalLight = DirectionalLight(
            direction: vm.Vector3(-0.4, -1, -0.3),
            castsShadow: true,
          )
          ..skybox = Skybox(
            GradientSkySource(
              zenithColor: vm.Vector3(0.25, 0.5, 0.95),
              horizonColor: vm.Vector3(0.8, 0.9, 1),
              groundColor: vm.Vector3(0.3, 0.45, 0.25),
            ),
          );
        final cube = Node(
          mesh: Mesh(
            CuboidGeometry(vm.Vector3(1, 1, 1)),
            PhysicallyBasedMaterial()
              ..baseColorFactor = vm.Vector4(0.9, 0.2, 0.2, 1)
              ..metallicFactor = 0
              ..roughnessFactor = 0.6,
          ),
        )..position = vm.Vector3(0, 0.5, 0);
        final ground = Node(
          mesh: Mesh(
            PlaneGeometry(width: 10, depth: 10),
            PhysicallyBasedMaterial()
              ..baseColorFactor = vm.Vector4(0.35, 0.7, 0.3, 1)
              ..metallicFactor = 0,
          ),
        );
        scene.addAll([ground, cube]);
        setState(() {
          _scene = scene;
          _cube = cube;
        });
      },
      onError: (Object error) {
        if (mounted) setState(() => _error = error);
      },
    );
  }

  void _tick(Duration _, double dt) {
    _elapsed += dt;
    _cube?.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), _elapsed);
  }

  @override
  Widget build(BuildContext context) {
    final scene = _scene;
    if (_error != null) {
      return Center(child: Text('No se pudo iniciar el 3D: $_error'));
    }
    if (scene == null) return const Center(child: CircularProgressIndicator());
    return SceneView(
      scene,
      onTick: _tick,
      camera: PerspectiveCamera(
        position: vm.Vector3(3, 2.5, -4),
        target: vm.Vector3(0, 0.5, 0),
        fovRadiansY: 50 * math.pi / 180,
      ),
    );
  }
}
