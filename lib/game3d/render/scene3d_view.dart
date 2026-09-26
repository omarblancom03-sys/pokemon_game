import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../mesh/mesh_builder.dart';
import '../mesh/props.dart';
import '../mesh/terrain_mesh.dart';
import '../sim/orbit_camera.dart';
import '../sim/trainer_pose.dart';
import '../sim/world3d_config.dart';
import '../sim/world3d_sim.dart';
import 'ball_renderer.dart';
import 'bird_renderer.dart';
import 'bush_renderer.dart';
import 'butterfly_renderer.dart';
import 'cloud_renderer.dart';
import 'dust_renderer.dart';
import 'footprint_renderer.dart';
import 'grass_blade_renderer.dart';
import 'grass_renderer.dart';
import 'item_renderer.dart';
import 'trainer_rig.dart';
import 'wild_renderer.dart';

/// VISTA 3D: dibuja la [World3DSim] con flutter_scene.
///
/// Es la ÚNICA pieza que toca el motor. En cada fotograma: avanza la
/// simulación, copia la posición del jugador a su nodo y coloca la cámara.
/// El motor necesita preparar sus shaders antes de dibujar
/// ([Scene.initializeStaticResources]); hasta entonces, indicador de carga.
class Scene3DView extends StatefulWidget {
  const Scene3DView({super.key, required this.sim, required this.loadImage});

  final World3DSim sim;

  /// Descarga de los dibujos de los Pokémon (capa de servicios).
  final ImageBytesLoader loadImage;

  @override
  State<Scene3DView> createState() => _Scene3DViewState();
}

class _Scene3DViewState extends State<Scene3DView> {
  Scene? _scene;
  late TrainerRig _trainer;
  late GrassRenderer _grass;
  late WildRenderer _wild;
  late ItemRenderer _items;
  late BallRenderer _balls;
  late DustRenderer _dust;
  late FootprintRenderer _footprints;
  late GrassBladeRenderer _blades;
  late ButterflyRenderer _butterflies;
  late CloudRenderer _clouds;
  late BirdRenderer _birds;
  late BushRenderer _bushes;
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
        direction: _toEngine(World3DConfig.sunDirection),
        color: vm.Vector3(1, 0.96, 0.88),
        intensity: 3.2,
        castsShadow: true,
        shadowMaxDistance: 60,
      )
      // Aspecto "stylized": colores vivos, algo cálidos, brillo suave y
      // una neblina azulada que da profundidad.
      ..environmentSettings = EnvironmentSettings(
        toneMapping: ToneMappingMode.aces,
        exposure: 0.85,
        environmentIntensity: 0.55,
        colorGradingEnabled: true,
        saturation: 1.2,
        contrast: 1.15,
        temperature: 0.08,
        bloomEnabled: true,
        bloomThreshold: 1.2,
        bloomIntensity: 0.15,
        vignetteEnabled: true,
        vignetteIntensity: 0.2,
        fogEnabled: true,
        fogMode: FogMode.exponential,
        fogColor: vm.Vector3(0.72, 0.84, 0.97),
        fogDensity: 0.004,
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

    // Todo lo fijo (árboles, casas, vallas...) va en UNA malla. Los
    // arbustos van aparte: se balancean al sacudirlos.
    scene.add(Node(mesh: _mesh(buildProps(_sim.layout, tile, bushes: false))));
    _bushes = BushRenderer(_sim.berries, _mesh);
    scene.add(_bushes.root);

    // Césped exterior bajo el bosque del borde (un poco por debajo del
    // suelo para que no parpadee con él).
    final outer = MeshBuilder()
      ..quad(
        vm.Vector3(-40, -0.02, -40),
        vm.Vector3(-40, -0.02, _sim.depth + 40),
        vm.Vector3(_sim.width + 40, -0.02, _sim.depth + 40),
        vm.Vector3(_sim.width + 40, -0.02, -40),
        srgb(0x4E9A3E),
      );
    scene.add(Node(mesh: _mesh(outer.build())));

    _grass = GrassRenderer(_sim.grass, _mesh);
    scene.add(_grass.node);

    final wildRoot = Node(name: 'wild');
    scene.add(wildRoot);
    _wild = WildRenderer(root: wildRoot, loadImage: widget.loadImage);

    final itemsRoot = Node(name: 'items');
    scene.add(itemsRoot);
    _items = ItemRenderer(root: itemsRoot, toMesh: _mesh);

    final ballsRoot = Node(name: 'balls');
    scene.add(ballsRoot);
    _balls = BallRenderer(root: ballsRoot, toMesh: _mesh);

    _footprints = FootprintRenderer();
    scene.add(_footprints.node);
    _dust = DustRenderer();
    scene.add(_dust.node);
    _blades = GrassBladeRenderer(_mesh);
    scene.add(_blades.node);
    _butterflies = ButterflyRenderer(_sim.butterflies, _mesh);
    scene.add(_butterflies.node);
    _clouds = CloudRenderer(_sim.clouds);
    scene.add(_clouds.node);
    _birds = BirdRenderer(_sim.birds, _mesh);
    scene.add(_birds.node);

    _trainer = TrainerRig(_mesh);
    scene.add(_trainer.root);
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
    _trainer.apply(
      feet: p.position,
      facing: p.facing,
      pose: TrainerPose.fromMotion(
        distanceWalked: p.distanceWalked,
        speed: p.speed,
        walkSpeed: _sim.config.walkSpeed,
        runSpeed: _sim.config.runSpeed,
        crouch: _sim.crouchAmount,
        aiming: _sim.isAiming && _sim.camera.aim > 0.5,
        throwProgress: _sim.throwProgress,
        rollProgress: _sim.rollProgress,
      ),
      heldBall: _sim.heldBall,
      heldBerry: _sim.heldBerry,
    );
  }

  void _tick(Duration _, double dt) {
    // Un salto grande (pestaña en segundo plano) no debe teletransportar.
    _sim.update(math.min(dt, 0.1));
    _syncPlayer();
    _grass.update(
      _sim.time,
      _sim.grassPushers,
      rustlers: _sim.grassRustlers,
      trampled: _sim.trampled,
    );
    _wild.update(_sim.wild, _sim.balls, _sim.camera.yaw, _sim.time);
    _items.update(_sim.fieldItems.items, _sim.time);
    _footprints.update(_sim.footprints.prints);
    _dust.update(_sim.dust.puffs);
    _blades.update(_sim.blades.blades);
    _butterflies.update();
    _clouds.update();
    _birds.update();
    _bushes.update();
    _balls.update(
      _sim.balls,
      preview: _sim.aimPreview,
      locked: _sim.lockedTarget != null,
      cameraYaw: _sim.camera.yaw,
      backpack: _sim.backpackPosition,
    );
  }

  Camera _camera(Duration _) {
    final feet = _sim.player.position;
    return PerspectiveCamera(
      position: _toEngine(_sim.camera.eyeFor(feet)),
      target: _toEngine(_sim.camera.targetFor(feet)),
      fovRadiansY: OrbitCamera.fovY,
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
