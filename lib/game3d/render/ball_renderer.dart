import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../models/poke_ball.dart';
import '../mesh/ball_mesh.dart';
import '../mesh/effects_mesh.dart';
import '../mesh/mesh_builder.dart';
import '../sim/throwing.dart';
import 'ball_model.dart';

/// Dibuja las Poké Balls LANZADAS y sus efectos, a partir del estado de la
/// simulación (fase y tiempo de cada bola):
///  - en vuelo y rodando: gira sobre sí misma, con una estela brillante del
///    color de la bola;
///  - al golpear: una onda que se abre y un fogonazo en el punto del golpe;
///  - al absorber: la tapa se abre y se cierra con un destello rojo;
///  - en el suelo: se sacude mirando a la cámara, con el botón encendido
///    en rojo en cada sacudida;
///  - ¡capturado!: "clic" (destello blanco del botón), estrellas y la bola
///    vuelve en arco a la mochila del entrenador;
///  - se escapa: la bola se parte en dos (la tapa sale volando), destello
///    blanco y chispas.
/// Además, al apuntar, la trayectoria prevista (puntos) y dónde caerá.
class BallRenderer {
  BallRenderer({required this.root, required this.toMesh}) {
    for (final type in PokeBallType.values) {
      final parts = buildPokeBallParts(type, radius: ballRadius);
      _lids[type] = BallModel(type, parts.top);
      _bases[type] = BallModel(type, parts.bottom);
      _hinge = _engine(parts.hinge);
    }
    _star = _unlit(buildStar(vm.Vector4(2.4, 2.0, 0.5, 1)));
    _flash = Mesh(
      SphereGeometry(radius: 1),
      UnlitMaterial()
        ..alphaMode = AlphaMode.blend
        ..baseColorFactor = vm.Vector4(1, 1, 1, 0),
    );
    // Onda del impacto: un anillo blanco de radio 1 (el color y el alfa van
    // en el material de cada bola).
    final ring = buildRing(vm.Vector4(1, 1, 1, 1), inner: 0.78).toEngineSpace();
    _impactRing = MeshGeometry.fromArrays(
      positions: ring.positions,
      normals: ring.normals,
      colors: ring.colors,
      indices: ring.indices,
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
    // Estela de las bolas en vuelo: bolitas brillantes, todas en UNA malla
    // instanciada; el color y la opacidad van en cada instancia.
    final spark =
        (MeshBuilder()..gem(
              vm.Vector3.zero(),
              vm.Vector3.all(1),
              vm.Vector4(1, 1, 1, 1),
            ))
            .build()
            .toEngineSpace();
    _trail = InstancedMesh(
      geometry: MeshGeometry.fromArrays(
        positions: spark.positions,
        normals: spark.normals,
        colors: spark.colors,
        indices: spark.indices,
      ),
      material: UnlitMaterial()..alphaMode = AlphaMode.blend,
      sortTransparentInstances: false,
    );
    for (var i = 0; i < _maxTrail; i++) {
      _trail.addInstance(_hidden, color: vm.Vector4.zero());
    }
    root.add(
      Node(name: 'ballTrails')
        ..castsShadows = false
        ..frustumCulled = false
        ..addComponent(InstancedMeshComponent(_trail)),
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

  final Map<PokeBallType, BallModel> _lids = {};
  final Map<PokeBallType, BallModel> _bases = {};

  /// Bisagra de la tapa (en el motor), en la parte de atrás de la bola.
  late final vm.Vector3 _hinge;
  late final Mesh _star;
  late final Mesh _flash;
  late final MeshGeometry _impactRing;
  late final InstancedMesh _dots;
  late final InstancedMesh _trail;
  late final Node _marker;
  late final Node _lockedMarker;
  final Map<String, _BallVisual> _visuals = {};

  static const _maxDots = 48;
  static const _maxTrail = 3 * 2 * ThrownBall.trailLength;
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
    required vm.Vector3 backpack,
  }) {
    final alive = {for (final b in balls) b.id};
    for (final id in _visuals.keys.toList()) {
      if (!alive.contains(id)) root.remove(_visuals.remove(id)!.node);
    }
    for (final ball in balls) {
      _place(_visuals[ball.id] ??= _create(ball), ball, cameraYaw, backpack);
    }
    _updatePreview(preview, locked);
    _updateTrails(balls);
  }

  _BallVisual _create(ThrownBall ball) {
    // El botón y su aro de luz se encienden en cada bola por separado:
    // llevan materiales propios (el resto se comparte).
    final model = _bases[ball.ball]!;
    final buttonMaterial = model.material(BallSurface.button);
    final haloMaterial = model.material(BallSurface.halo);
    final base = Node(
      mesh: model.mesh(
        replace: {
          BallSurface.button: buttonMaterial,
          BallSurface.halo: haloMaterial,
        },
      ),
    );
    final lid = Node(mesh: _lids[ball.ball]!.mesh());
    // La tapa gira sobre la bisagra trasera.
    final lidPivot = Node()
      ..position = _hinge
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
    // El impacto: onda y fogonazo (se colocan en el punto del golpe).
    UnlitMaterial blend() => UnlitMaterial()
      ..alphaMode = AlphaMode.blend
      ..baseColorFactor = vm.Vector4(1, 1, 1, 0);
    final ringMaterial = blend();
    final burstMaterial = blend();
    final ring = Node(mesh: Mesh(_impactRing, ringMaterial))
      ..castsShadows = false;
    final burst = Node(
      mesh: Mesh(_flash.primitives.first.geometry, burstMaterial),
    )..castsShadows = false;
    final impact = Node()
      ..visible = false
      ..add(ring)
      ..add(burst);
    // Chispas al partirse la bola (todas con el mismo material).
    final shardMaterial = blend();
    final shards = [
      for (var i = 0; i < 7; i++)
        Node(mesh: Mesh(_flash.primitives.first.geometry, shardMaterial))
          ..castsShadows = false
          ..visible = false,
    ];
    final stars = [
      for (var i = 0; i < 5; i++)
        Node(mesh: _star.clone())
          ..castsShadows = false
          ..visible = false,
    ];
    final node = Node(name: ball.id)
      ..add(orient)
      ..add(flash)
      ..add(impact);
    stars.forEach(node.add);
    shards.forEach(node.add);
    root.add(node);
    return _BallVisual(
      node: node,
      orient: orient,
      base: base,
      lidPivot: lidPivot,
      flash: flash,
      flashMaterial: flashMaterial,
      buttonMaterial: buttonMaterial,
      haloMaterial: haloMaterial,
      stars: stars,
      impact: impact,
      ring: ring,
      ringMaterial: ringMaterial,
      burst: burst,
      burstMaterial: burstMaterial,
      shards: shards,
      shardMaterial: shardMaterial,
    );
  }

  void _place(
    _BallVisual v,
    ThrownBall ball,
    double cameraYaw,
    vm.Vector3 backpack,
  ) {
    // La captura crítica brilla en dorado en vez de rojo.
    final critical = ball.result?.critical ?? false;
    v.node.position = _engine(ball.position);
    var scale = 1.0;
    var lidOpen = 0.0;
    // La tapa y la base, separadas al partirse (en el espacio de la bola).
    var lidOffset = vm.Vector3.zero();
    var baseTilt = 0.0;
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
        final absorb = 0.55 * math.sin(p * math.pi);
        flashColor = critical
            ? vm.Vector4(3, 2.4, 0.6, absorb)
            : vm.Vector4(3, 0.35, 0.3, absorb);
        flashSize = 0.25 + 0.35 * p;
      case BallPhase.falling:
        rotation = _heading(v.heading);
      case BallPhase.shaking:
        // El botón mira a la cámara y se balancea de lado a lado.
        rotation =
            _heading(cameraYaw) * vm.Quaternion.axisAngle(_z, ball.wobble);
        // Halo rojo suave mientras el botón está encendido.
        final glow = ball.buttonGlow;
        if (glow > 0) {
          flashColor = critical
              ? vm.Vector4(3, 2.4, 0.5, 0.35 * glow)
              : vm.Vector4(3, 0.3, 0.25, 0.28 * glow);
          flashSize = 0.2 + 0.04 * glow;
        }
      case BallPhase.caught:
        rotation = _heading(cameraYaw);
        if (t < 0.25) {
          flashColor = vm.Vector4(2.5, 2.3, 1.2, 0.6 * (1 - t / 0.25));
          flashSize = 0.2 + t * 1.6;
        }
        // Vuelve a la mochila: en arco, girando y algo más pequeña; al
        // llegar, un destellito.
        final back = ball.returnProgress;
        if (back != null) {
          v.node.position = _engine(ball.returnPosition(backpack));
          rotation = rotation * vm.Quaternion.axisAngle(_x, back * 9);
          scale = 1 - 0.45 * back;
          if (back > 0.8) {
            final a = (back - 0.8) / 0.2;
            flashColor = vm.Vector4(2.6, 2.4, 1.6, 0.55 * a);
            flashSize = 0.12 + 0.12 * a;
          }
          if (back >= 1) scale = 0;
        }
      case BallPhase.escaped:
        // Se parte: la tapa se abre de golpe y sale volando hacia arriba y
        // atrás; la base se vuelca; destello blanco; y todo se encoge.
        rotation = _heading(cameraYaw);
        final s = (t / ThrownBall.escapeTime).clamp(0.0, 1.0);
        lidOpen = math.min(1, t / 0.08) * 2.6 + s * 2;
        lidOffset = vm.Vector3(0, 1.5 * s - 1.7 * s * s, 0.35 * s);
        baseTilt = -0.9 * math.min(1, s * 2.5);
        // Un fogonazo breve y no muy grande: que se vea cómo se rompe.
        final f = (t / 0.3).clamp(0.0, 1.0);
        flashColor = vm.Vector4(2.6, 2.6, 2.6, 0.55 * (1 - f));
        flashSize = 0.2 + f * 0.7;
        scale = t < 0.3 ? 1 : math.max(0, 1 - (t - 0.3) / 0.3);
    }

    v.orient
      ..rotation = rotation
      ..scale = vm.Vector3.all(scale);
    v.lidPivot
      ..rotation = vm.Quaternion.axisAngle(_x, lidOpen)
      ..position = _hinge + lidOffset;
    v.base.rotation = vm.Quaternion.axisAngle(_x, baseTilt);
    v.flashMaterial.baseColorFactor = flashColor;
    v.flash
      ..visible = flashColor.w > 0.01
      ..scale = vm.Vector3.all(flashSize);
    // Botón: rojo en cada sacudida (dorado si es crítica); blanco en el
    // "clic" de la captura. Se enciende el disco y, más fuerte, el aro de
    // luz de alrededor: así el halo se ve como anillo y no como mancha.
    final glow = ball.buttonGlow;
    final click = ball.clickFlash;
    final (core, halo) = click > 0
        ? (
            BallPalette.catchCore * (BallPalette.catchCoreIntensity * click),
            BallPalette.catchHalo * (BallPalette.catchHaloIntensity * click),
          )
        : critical
        ? (
            BallPalette.criticalCore * (BallPalette.coreIntensity * glow),
            BallPalette.criticalHalo * (BallPalette.haloIntensity * glow),
          )
        : (
            BallPalette.shakeCore * (BallPalette.coreIntensity * glow),
            BallPalette.shakeHalo * (BallPalette.haloIntensity * glow),
          );
    v.buttonMaterial.emissiveFactor = core..w = 1;
    v.haloMaterial.emissiveFactor = halo..w = 1;
    _placeStars(v, ball);
    _placeImpact(v, ball, cameraYaw, critical: critical);
    _placeShards(v, ball);
  }

  /// Al escaparse, siete chispas salen disparadas en todas direcciones y
  /// caen apagándose.
  void _placeShards(_BallVisual v, ThrownBall ball) {
    final show = ball.phase == BallPhase.escaped;
    for (final shard in v.shards) {
      shard.visible = show;
    }
    if (!show) return;
    final s = (ball.phaseTime / ThrownBall.escapeTime).clamp(0.0, 1.0);
    final e = 1 - (1 - s) * (1 - s);
    v.shardMaterial.baseColorFactor = vm.Vector4(3, 2.2, 1.9, 1 - s);
    for (var i = 0; i < v.shards.length; i++) {
      final a = i * 2 * math.pi / v.shards.length + 0.4;
      final up = i.isEven ? 0.9 : 0.35;
      final dir = vm.Vector3(math.cos(a), up, math.sin(a))..normalize();
      v.shards[i]
        ..position = dir * (0.12 + 0.8 * e) + vm.Vector3(0, -0.6 * s * s, 0)
        ..scale = vm.Vector3.all(0.035 * (1 - 0.5 * s));
    }
  }

  /// El golpe: una onda que se abre mirando a la cámara y un fogonazo
  /// breve, en el punto del golpe (la bola ya sube a absorberlo). Dorado
  /// si la captura va a ser crítica.
  void _placeImpact(
    _BallVisual v,
    ThrownBall ball,
    double cameraYaw, {
    required bool critical,
  }) {
    final p = ball.impactProgress;
    final at = ball.hitPoint;
    v.impact.visible = p != null && at != null;
    if (p == null || at == null) return;
    v.impact.position = _engine(at) - _engine(ball.position);
    final c = critical ? vm.Vector3(3, 2.4, 0.5) : vm.Vector3(2.6, 2.5, 2.2);
    final ease = 1 - (1 - p) * (1 - p);
    v.ringMaterial.baseColorFactor = vm.Vector4(c.x, c.y, c.z, 0.85 * (1 - p));
    v.ring
      ..rotation =
          _heading(cameraYaw) * vm.Quaternion.axisAngle(_x, math.pi / 2)
      ..scale = vm.Vector3.all(0.2 + 1.3 * ease);
    // El fogonazo dura la primera tercera parte.
    final f = math.min(1.0, p * 3);
    v.burstMaterial.baseColorFactor = vm.Vector4(c.x, c.y, c.z, 0.9 * (1 - f));
    v.burst
      ..visible = f < 1
      ..scale = vm.Vector3.all(0.18 + 0.45 * f);
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
      // Se apagan antes de que la bola vuelva a la mochila.
      final fade = t > 0.9 ? math.max(0, 1 - (t - 0.9) / 0.3) : 1.0;
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

  /// Brillo de la estela según la bola (más de 1 para que el "bloom" la
  /// haga relucir).
  static vm.Vector4 _trailColor(PokeBallType type) => switch (type) {
    PokeBallType.poke => vm.Vector4(1.5, 0.3, 0.25, 1),
    PokeBallType.great => vm.Vector4(0.3, 0.65, 1.7, 1),
    PokeBallType.ultra => vm.Vector4(1.6, 1.3, 0.25, 1),
  };

  /// Estelas: de la cola (pequeña y transparente) a la bola (grande).
  void _updateTrails(List<ThrownBall> balls) {
    final sparks = <(vm.Vector3, double, vm.Vector4)>[];
    for (final ball in balls) {
      final trail = ball.trail;
      final color = _trailColor(ball.ball);
      // Con un punto intermedio entre cada dos: parece una línea continua.
      final points = [
        for (var i = 0; i < trail.length; i++) ...[
          if (i > 0) (trail[i - 1] + trail[i]) * 0.5,
          trail[i],
        ],
        if (trail.isNotEmpty && ball.phase == BallPhase.flying)
          (trail.last + ball.position) * 0.5,
      ];
      for (var i = 0; i < points.length; i++) {
        final f = (i + 1) / points.length; // 0 cola … 1 bola
        sparks.add((
          points[i],
          ballRadius * (0.3 + 0.6 * f),
          vm.Vector4(color.x, color.y, color.z, 0.1 + 0.6 * f),
        ));
      }
    }
    _trail.updateInstanceTransforms((transforms) {
      for (var i = 0; i < transforms.length; i++) {
        if (i < sparks.length) {
          final (at, size, _) = sparks[i];
          transforms[i].setFrom(
            vm.Matrix4.compose(
              _engine(at),
              vm.Quaternion.identity(),
              vm.Vector3.all(size),
            ),
          );
        } else {
          transforms[i].setFrom(_hidden);
        }
      }
    }, recomputeWinding: false);
    for (var i = 0; i < _maxTrail; i++) {
      _trail.setInstanceColor(
        i,
        i < sparks.length ? sparks[i].$3 : vm.Vector4.zero(),
      );
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
    required this.base,
    required this.lidPivot,
    required this.flash,
    required this.flashMaterial,
    required this.buttonMaterial,
    required this.haloMaterial,
    required this.stars,
    required this.impact,
    required this.ring,
    required this.ringMaterial,
    required this.burst,
    required this.burstMaterial,
    required this.shards,
    required this.shardMaterial,
  });

  final Node node;
  final Node orient;

  /// Mitad de abajo (se vuelca al partirse).
  final Node base;
  final Node lidPivot;
  final Node flash;
  final UnlitMaterial flashMaterial;

  /// Materiales del botón y de su aro de luz: se encienden (emisivo) en
  /// rojo al sacudirse y en blanco en el "clic".
  final PhysicallyBasedMaterial buttonMaterial;
  final PhysicallyBasedMaterial haloMaterial;
  final List<Node> stars;

  /// Onda y fogonazo del golpe.
  final Node impact;
  final Node ring;
  final UnlitMaterial ringMaterial;
  final Node burst;
  final UnlitMaterial burstMaterial;

  /// Chispas al partirse la bola.
  final List<Node> shards;
  final UnlitMaterial shardMaterial;

  /// Último rumbo conocido (para que no gire de golpe al pararse).
  double heading = 0;
}
