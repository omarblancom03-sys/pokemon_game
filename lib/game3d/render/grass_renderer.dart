import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../mesh/grass_mesh.dart';
import '../mesh/mesh_builder.dart';
import '../sim/grass_field.dart';

/// Dibuja la hierba alta como UNA malla instanciada (una mata repetida
/// cientos de veces en una sola llamada de dibujo) y, en cada fotograma,
/// inclina cada mata según el viento y quien pase por encima.
class GrassRenderer {
  GrassRenderer(this.field, Mesh Function(MeshBuffers) toMesh) {
    final tuft = toMesh(buildGrassTuft());
    _instances = InstancedMesh(
      geometry: tuft.primitives.first.geometry,
      material: tuft.primitives.first.material,
    );
    for (final t in field.tufts) {
      _instances.addInstance(_transform(t, 0, 1, 0));
    }
    // Sin sombras propias: son cientos de hojas y la sombra costaría
    // redibujarlas en cada cascada de sombras (4 veces más trabajo).
    node = Node(name: 'tallGrass')
      ..castsShadows = false
      ..addComponent(InstancedMeshComponent(_instances));
  }

  final GrassField field;
  late final InstancedMesh _instances;
  late final Node node;

  static final _up = vm.Vector3(0, 1, 0);

  /// Recalcula la inclinación de todas las matas (y las que se agitan sobre
  /// Pokémon escondidos).
  void update(
    double time,
    Iterable<vm.Vector3> pushers, {
    Iterable<vm.Vector3> rustlers = const [],
  }) {
    final list = pushers.toList(growable: false);
    final shaking = rustlers.toList(growable: false);
    _instances.updateInstanceTransforms((transforms) {
      for (var i = 0; i < field.tufts.length; i++) {
        final t = field.tufts[i];
        final tilt = GrassField.tiltFor(t, time, list, rustlers: shaking);
        transforms[i].setFrom(
          _transform(t, tilt.angle, tilt.axisX, tilt.axisZ),
        );
      }
    }, recomputeWinding: false);
  }

  /// Transformación de una mata YA en el espacio del motor (Z invertida):
  /// el eje de inclinación también invierte su Z y los ángulos cambian de
  /// signo (un espejo invierte el sentido de giro).
  static vm.Matrix4 _transform(
    GrassTuft t,
    double angle,
    double axisX,
    double axisZ,
  ) {
    final tilt = angle == 0
        ? vm.Quaternion.identity()
        : vm.Quaternion.axisAngle(vm.Vector3(axisX, 0, -axisZ), -angle);
    final rotation = tilt * vm.Quaternion.axisAngle(_up, -t.yaw);
    return vm.Matrix4.compose(
      vm.Vector3(t.x, 0, -t.z),
      rotation,
      vm.Vector3.all(t.scale),
    );
  }
}
