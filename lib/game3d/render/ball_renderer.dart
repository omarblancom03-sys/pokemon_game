import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../models/poke_ball.dart';
import '../mesh/ball_mesh.dart';
import '../mesh/effects_mesh.dart';
import '../mesh/mesh_builder.dart';
import '../sim/throwing.dart';

/// Dibuja las Poké Balls LANZADAS y sus efectos, a partir del estado de la
/// simulación (fase y tiempo de cada bola):
///  - en vuelo y rodando: gira sobre sí misma;
///  - al absorber: la tapa se abre y se cierra con un destello rojo;
///  - en el suelo: se sacude mirando a la cámara;
///  - ¡capturado!: estallido de estrellas;
///  - se escapa: la tapa salta, destello blanco y la bola desaparece.
/// Además, al apuntar, la trayectoria prevista (puntos) y dónde caerá.
class BallRenderer {
  BallRenderer({required this.root, required this.toMesh}) {
    for (final type in PokeBallType.values) {
      final parts = buildPokeBallParts(type, radius: ballRadius);
      _lids[type] = toMesh(parts.top);
      _bases[type] = toMesh(parts.bottom);
    }
    _star = _unlit(buildStar(vm.Vector4(2.4, 2.0, 0.5, 1)));
    _flash = Mesh(
      SphereGeometry(radius: 1),
      UnlitMaterial()
        ..alphaMode = AlphaMode.blend
        ..baseColorFactor = vm.Vector4(1, 1, 1, 0),
    );

    // Trayectoria: muchas bolitas en UNA llamada de dibujo.
    final dot = _unlit(
      (MeshBuilder()..gem(
            vm.Vector3.zero(),
            vm.Vector3.all(0.045),
            vm.Vector4(1.5, 1.5, 1.4, 1),
          ))
          .build(),
    );
    _dots = InstancedMesh(
      geometry: dot.primitives.first.geometry,
      material: dot.primitives.first.material,
    );
    for (var i = 0; i < _maxDots; i++) {
      _dots.addInstance(_hidden);
    }
    root.add(
      Node(name: 'aimDots')
        ..castsShadows = false
        ..frustumCulled = false
        ..addComponent(InstancedMeshComponent(_dots)),
    );
    _marker = Node(
      name: 'aimMarker',
      mesh: _unlit(buildRing(vm.Vector4(1.6, 1.6, 1.5, 0.9), inner: 0.72)),
    )..castsShadows = false;
    _lockedMarker = Node(
      name: 'aimMarkerLocked',
      mesh: _unlit(buildRing(vm.Vector4(0.6, 2.2, 0.6, 0.9), inner: 0.72)),
    )..castsShadows = false;
    root
      ..add(_marker)
      ..add(_lockedMarker);
  }

  final Node root;
  final Mesh Function(MeshBuffers) toMesh;

  final Map<PokeBallType, Mesh> _lids = {};
  final Map<PokeBallType, Mesh> _bases = {};
  late final Mesh _star;
  late final Mesh _flash;
  late final InstancedMesh _dots;
  late final Node _marker;
  late final Node _lockedMarker;
  final Map<String, _BallVisual> _visuals = {};

  static const _maxDots = 48;
  static final _hidden = vm.Matrix4.compose(
    vm.Vector3(0, -50, 0),
    vm.Quaternion.identity(),
    vm.Vector3.zero(),
  );
  static final _x = vm.Vector3(1, 0, 0);
  static final _y = vm.Vector3(0, 1, 0);
  static final _z = vm.Vector3(0, 0, 1);

  /// Malla sin luz con colores por vértice (y alfa).
  static Mesh _unlit(MeshBuffers buffers) {
    final e = buffers.toEngineSpace();
    return Mesh(
      MeshGeometry.fromArrays(
        positions: e.positions,
        normals: e.normals,
        colors: e.colors,
        indices: e.indices,
      ),
      UnlitMaterial()..alphaMode = AlphaMode.blend,
    );
  }

  static vm.Vector3 _engine(vm.Vector3 v) => vm.Vector3(v.x, v.y, -v.z);

  /// Giro alrededor del eje vertical para que el "frente" (+Z de la
  /// simulación, donde está el botón) mire hacia [heading] (0 = +Z).
  static vm.Quaternion _heading(double heading) =>
      vm.Quaternion.axisAngle(_y, -heading);

  /// [preview]: trayectoria al apuntar (vacía si no); [locked]: si va hacia
  /// un objetivo fijado (el marcador se pone verde).
  void update(
    List<ThrownBall> balls, {
    required List<vm.Vector3> preview,
    required bool locked,
    required double cameraYaw,
  }) {
    final alive = {for (final b in balls) b.id};
    for (final id in _visuals.keys.toList()) {
      if (!alive.contains(id)) root.remove(_visuals.remove(id)!.node);
    }
    for (final ball in balls) {
      _place(_visuals[ball.id] ??= _create(ball), ball, cameraYaw);
    }
    _updatePreview(preview, locked);
  }

  _BallVisual _create(ThrownBall ball) {
    final base = Node(mesh: _bases[ball.ball]!.clone());
    final lid = Node(mesh: _lids[ball.ball]!.clone());
    // La tapa gira sobre la bisagra trasera (en el motor, Z invertida).
    final lidPivot = Node()
      ..position = vm.Vector3(0, 0, ballRadius)
      ..add(lid);
    final orient = Node()
      ..add(base)
      ..add(lidPivot);
    final flashMaterial = UnlitMaterial()
      ..alphaMode = AlphaMode.blend
      ..baseColorFactor = vm.Vector4(1, 1, 1, 0);
    final flash = Node(
      mesh: Mesh(_flash.primitives.first.geometry, flashMaterial),
    )..castsShadows = false;
    final stars = [
      for (var i = 0; i < 5; i++)
        Node(mesh: _star.clone())
          ..castsShadows = false
          ..visible = false,
    ];
    final node = Node(name: ball.id)
      ..add(orient)
      ..add(flash);
    stars.forEach(node.add);
    root.add(node);
    return _BallVisual(
      node: node,
      orient: orient,
      lidPivot: lidPivot,
      flash: flash,
      flashMaterial: flashMaterial,
      stars: stars,
    );
  }

  void _place(_BallVisual v, ThrownBall ball, double cameraYaw) {
    v.node.position = _engine(ball.position);
    var scale = 1.0;
    var lidOpen = 0.0;
    var flashColor = vm.Vector4(1, 1, 1, 0);
    var flashSize = 0.0;
    vm.Quaternion rotation;

    final t = ball.phaseTime;
    final vel = ball.velocity;
    if (vel.x * vel.x + vel.z * vel.z > 0.01) {
      v.heading = math.atan2(vel.x, vel.z);
    }
    switch (ball.phase) {
      case BallPhase.flying || BallPhase.missed:
        // Rueda hacia delante sobre su eje lateral.
        rotation =
            _heading(v.heading) * vm.Quaternion.axisAngle(_x, -ball.spin);
      case BallPhase.absorbing:
        // Se abre, destello rojo, y se cierra con el Pokémon dentro.
        final target = ball.target;
        if (target != null) {
          final to = target.position - ball.position;
          v.heading = math.atan2(to.x, to.z);
        }
        final p = (t / ThrownBall.absorbTime).clamp(0.0, 1.0);
        lidOpen = math.sin(p * math.pi) * 1.5;
        rotation = _heading(v.heading);
        flashColor = vm.Vector4(3, 0.35, 0.3, 0.55 * math.sin(p * math.pi));
        flashSize = 0.25 + 0.35 * p;
      case BallPhase.falling:
        rotation = _heading(v.heading);
      case BallPhase.shaking:
        // El botón mira a la cámara y se balancea de lado a lado.
        rotation =
            _heading(cameraYaw) * vm.Quaternion.axisAngle(_z, ball.wobble);
      case BallPhase.caught:
        rotation = _heading(cameraYaw);
        // "Clic": un saltito y, al final, se desvanece.
        final end = ThrownBall.caughtTime;
        scale = t > end - 0.3 ? math.max(0, (end - t) / 0.3) : 1;
        if (t < 0.25) {
          flashColor = vm.Vector4(2.5, 2.3, 1.2, 0.6 * (1 - t / 0.25));
          flashSize = 0.2 + t * 1.6;
        }
      case BallPhase.escaped:
        // La tapa salta, destello blanco y la bola se encoge.
        rotation = _heading(cameraYaw);
        lidOpen = math.min(1, t / 0.12) * 2.1;
        final f = (t / 0.4).clamp(0.0, 1.0);
        flashColor = vm.Vector4(2.6, 2.6, 2.6, 0.75 * (1 - f));
        flashSize = 0.2 + f * 1.1;
        scale = t < 0.2 ? 1 : math.max(0, 1 - (t - 0.2) / 0.35);
    }

    v.orient
      ..rotation = rotation
      ..scale = vm.Vector3.all(scale);
    v.lidPivot.rotation = vm.Quaternion.axisAngle(_x, lidOpen);
    v.flashMaterial.baseColorFactor = flashColor;
    v.flash
      ..visible = flashColor.w > 0.01
      ..scale = vm.Vector3.all(flashSize);
    _placeStars(v, ball);
  }

  /// Cinco estrellas que salen disparadas en abanico y caen.
  void _placeStars(_BallVisual v, ThrownBall ball) {
    final show = ball.phase == BallPhase.caught;
    final t = ball.phaseTime;
    for (var i = 0; i < v.stars.length; i++) {
      final star = v.stars[i]..visible = show;
      if (!show) continue;
      final a = i * 2 * math.pi / v.stars.length + 0.3;
      final r = 0.15 + t * 0.9;
      final y = 0.15 + 1.9 * t - 1.6 * t * t;
      final fade = t > 1.1 ? math.max(0, 1 - (t - 1.1) / 0.4) : 1.0;
      star
        ..position = vm.Vector3(
          math.cos(a) * r,
          math.max(0.05, y),
          math.sin(a) * r,
        )
        ..rotation = vm.Quaternion.axisAngle(_y, t * 5 + i)
        ..scale = vm.Vector3.all(0.11 * fade * math.min(1, t / 0.1));
    }
  }

  void _updatePreview(List<vm.Vector3> preview, bool locked) {
    // Una bolita cada ~2 pasos de la previsión, de la mano al impacto.
    final dots = <vm.Vector3>[
      for (var i = 1; i < preview.length; i += 2) preview[i],
    ];
    _dots.updateInstanceTransforms((transforms) {
      for (var i = 0; i < transforms.length; i++) {
        if (i < dots.length && i < _maxDots) {
          transforms[i].setFrom(
            vm.Matrix4.compose(
              _engine(dots[i]),
              vm.Quaternion.identity(),
              vm.Vector3.all(1 - 0.5 * i / dots.length),
            ),
          );
        } else {
          transforms[i].setFrom(_hidden);
        }
      }
    }, recomputeWinding: false);

    final showMarker = preview.length > 1;
    final end = showMarker ? preview.last : vm.Vector3.zero();
    for (final (node, active) in [
      (_marker, showMarker && !locked),
      (_lockedMarker, showMarker && locked),
    ]) {
      node.visible = active;
      if (active) {
        node
          ..position = _engine(vm.Vector3(end.x, 0.04, end.z))
          ..scale = vm.Vector3.all(0.45);
      }
    }
  }
}

class _BallVisual {
  _BallVisual({
    required this.node,
    required this.orient,
    required this.lidPivot,
    required this.flash,
    required this.flashMaterial,
    required this.stars,
  });

  final Node node;
  final Node orient;
  final Node lidPivot;
  final Node flash;
  final UnlitMaterial flashMaterial;
  final List<Node> stars;

  /// Último rumbo conocido (para que no gire de golpe al pararse).
  double heading = 0;
}
