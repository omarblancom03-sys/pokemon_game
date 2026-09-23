import 'package:vector_math/vector_math.dart';

import '../../game/input/movement_input.dart';
import '../../game/map/map_layout.dart';
import 'camera_input.dart';
import 'orbit_camera.dart';
import 'player_body.dart';
import 'world3d_config.dart';

/// LA SIMULACIÓN del mundo 3D: jugador + cámara sobre el mapa ASCII.
///
/// No dibuja nada ni conoce el motor: el renderer llama a [update] en cada
/// fotograma y luego lee [player] y [camera] para colocar la escena. Por eso
/// toda la jugabilidad se puede probar con tests normales.
class World3DSim {
  World3DSim({
    required this.layout,
    this.config = const World3DConfig(),
    MovementInput? input,
    CameraInput? cameraInput,
    OrbitCamera? camera,
  }) : input = input ?? MovementInput(),
       cameraInput = cameraInput ?? CameraInput(),
       camera = camera ?? OrbitCamera() {
    player = PlayerBody(
      config: config,
      canOccupy: (footprint) =>
          layout.isAreaWalkable(footprint, config.tileSize),
      position: cellCenter(layout.start.col, layout.start.row),
    );
  }

  final MapLayout layout;
  final World3DConfig config;

  /// Movimiento (teclado + D-pad), compartido con el modo 2D.
  final MovementInput input;
  final CameraInput cameraInput;
  final OrbitCamera camera;
  late final PlayerBody player;

  /// Radianes por segundo al girar con Q/E.
  static const keyTurnSpeed = 2.2;

  /// Radianes por píxel arrastrado con el ratón.
  static const dragSensitivity = 0.008;

  /// Tamaño del mundo en metros (ancho en X, fondo en Z).
  double get width => layout.columns * config.tileSize;
  double get depth => layout.rows * config.tileSize;

  /// Centro de una casilla, en metros (y = 0: el suelo).
  Vector3 cellCenter(int col, int row) =>
      Vector3((col + 0.5) * config.tileSize, 0, (row + 0.5) * config.tileSize);

  /// Casilla bajo un punto del mundo.
  ({int col, int row}) cellAt(Vector3 p) => (
    col: (p.x / config.tileSize).floor(),
    row: (p.z / config.tileSize).floor(),
  );

  /// Avanza la simulación [dt] segundos.
  void update(double dt) {
    // 1) Cámara: ratón (acumulado desde el último fotograma) y Q/E.
    final (dragX, dragY) = cameraInput.takeDrag();
    camera
      ..rotate(
        -dragX * dragSensitivity + cameraInput.turnAxis * keyTurnSpeed * dt,
        dragY * dragSensitivity,
      )
      ..zoom(cameraInput.takeZoom());

    // 2) Jugador: la dirección pulsada es RELATIVA A LA CÁMARA
    // (arriba = alejarse de la cámara), como en GTA.
    final dir = input.direction; // x: derecha, y: abajo (convención 2D)
    final wish = camera.right * dir.x + camera.forward * -dir.y;
    player.update(dt, wish, running: cameraInput.running && input.enabled);
  }
}
