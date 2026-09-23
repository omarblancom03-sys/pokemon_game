import 'package:flutter/foundation.dart';

import '../game3d/sim/world3d_events.dart';
import '../models/poke_ball.dart';
import '../models/pokemon.dart';
import 'trainer_controller.dart';

/// Qué pasó, para el aviso que aparece en pantalla.
enum FieldNoticeKind { pickedUp, caught, brokeFree, missed, noBalls }

/// Un aviso breve del campo ("+2 Poké Ball", "¡Capturado!"...). Guarda los
/// DATOS; el texto lo compone la vista.
class FieldNotice {
  const FieldNotice({
    required this.id,
    required this.kind,
    this.ball,
    this.count = 0,
    this.pokemon,
    this.shakes = 0,
  });

  final int id;
  final FieldNoticeKind kind;
  final PokeBallType? ball;
  final int count;
  final Pokemon? pokemon;

  /// Sacudidas que aguantó la bola antes de abrirse (si se escapó).
  final int shakes;
}

/// CONTROLADOR de una partida en el campo 3D: recibe lo que pasa en el
/// mundo (recogidas, capturas, fallos), lo apunta en la bolsa del
/// entrenador ([TrainerController], que vive en toda la app) y guarda los
/// avisos que la pantalla enseña unos segundos.
///
/// Se crea por partida (como el GameController): al salir, los avisos se
/// pierden pero la bolsa y los capturados se conservan.
class FieldController extends ChangeNotifier {
  FieldController({required this._trainer});

  final TrainerController _trainer;
  final List<FieldNotice> _notices = [];
  int _nextId = 0;

  /// Como mucho se ven estos avisos a la vez (los más viejos se van).
  static const maxNotices = 3;

  /// Avisos visibles, del más antiguo al más nuevo.
  List<FieldNotice> get notices => List.unmodifiable(_notices);

  /// El mundo cuenta algo: se actualiza la bolsa y se avisa.
  void onWorldEvent(World3DEvent event) {
    switch (event) {
      case BallsPickedUp(:final ball, :final count):
        _trainer.addBalls(ball, count);
        _post(FieldNoticeKind.pickedUp, ball: ball, count: count);
      case BallMissed(:final ball):
        _post(FieldNoticeKind.missed, ball: ball);
      case PokemonCaught(:final wild, :final ball):
        _trainer.registerCapture(wild.pokemon, ball);
        _post(FieldNoticeKind.caught, ball: ball, pokemon: wild.pokemon);
      case PokemonBrokeFree(:final wild, :final ball, :final result):
        _post(
          FieldNoticeKind.brokeFree,
          ball: ball,
          pokemon: wild.pokemon,
          shakes: result.shakes,
        );
    }
  }

  /// Saca una bola de la bolsa para lanzarla; si no queda ninguna, avisa
  /// y devuelve null.
  PokeBallType? takeBallToThrow() {
    final ball = _trainer.takeBall();
    if (ball == null) _post(FieldNoticeKind.noBalls);
    return ball;
  }

  /// La vista quita el aviso cuando ya se ha mostrado el tiempo suficiente.
  void dismiss(int id) {
    final before = _notices.length;
    _notices.removeWhere((n) => n.id == id);
    if (_notices.length != before) notifyListeners();
  }

  void _post(
    FieldNoticeKind kind, {
    PokeBallType? ball,
    int count = 0,
    Pokemon? pokemon,
    int shakes = 0,
  }) {
    _notices.add(
      FieldNotice(
        id: _nextId++,
        kind: kind,
        ball: ball,
        count: count,
        pokemon: pokemon,
        shakes: shakes,
      ),
    );
    if (_notices.length > maxNotices) _notices.removeAt(0);
    notifyListeners();
  }
}
