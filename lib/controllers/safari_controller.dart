import 'package:flutter/foundation.dart';

import '../game3d/sim/world3d_events.dart';
import '../models/poke_ball.dart';
import '../models/pokemon.dart';

/// En qué punto está el reto.
enum SafariPhase {
  /// No hay reto (el modo libre de siempre).
  off,

  /// En marcha: corre el reloj y se lanzan las bolas del Safari.
  running,

  /// Terminado: la pantalla enseña el resumen hasta que se cierra.
  finished,
}

/// Por qué terminó el reto.
enum SafariEnd { timeUp, outOfBalls, abandoned }

/// CONTROLADOR del RETO SAFARI (opcional; se crea por partida). Durante
/// [duration] segundos se juega con [ballCount] Poké Balls PROPIAS del
/// reto: la bolsa normal no se toca y en el campo no hay bolas que
/// recoger (eso, y que las falladas se pierden, lo hace la simulación con
/// `startSafari`). Se puede abandonar en cualquier momento sin perder nada:
/// lo capturado, capturado está.
///
/// Termina al acabarse el tiempo (la simulación avisa con [SafariTimeUp]),
/// al gastar todas las bolas (cuando la última termina de rodar o de
/// sacudirse) o al abandonar. El reloj lo lleva la simulación porque se
/// para con el mundo (pausa, paneles); aquí solo se cuentan las bolas y
/// las capturas.
class SafariController extends ChangeNotifier {
  /// 10 minutos y 25 bolas.
  static const duration = 600.0;
  static const ballCount = 25;

  /// Las bolas del reto son Poké Balls normales (se ven y capturan igual).
  static const ball = PokeBallType.poke;

  SafariPhase _phase = SafariPhase.off;
  SafariEnd? _end;
  int _ballsLeft = 0;
  int _thrown = 0;
  int _resolved = 0;
  final List<Pokemon> _catches = [];

  SafariPhase get phase => _phase;
  bool get isRunning => _phase == SafariPhase.running;

  /// Por qué terminó (null si no ha terminado).
  SafariEnd? get end => _end;

  int get ballsLeft => _ballsLeft;

  /// Lo capturado en este reto, en orden.
  List<Pokemon> get catches => List.unmodifiable(_catches);

  /// Empieza un reto nuevo (si no hay uno en marcha).
  void start() {
    if (isRunning) return;
    _phase = SafariPhase.running;
    _end = null;
    _ballsLeft = ballCount;
    _thrown = 0;
    _resolved = 0;
    _catches.clear();
    notifyListeners();
  }

  /// Saca una bola del reto para lanzarla (null si no quedan o no hay
  /// reto).
  PokeBallType? takeBall() {
    if (!isRunning || _ballsLeft == 0) return null;
    _ballsLeft--;
    _thrown++;
    notifyListeners();
    return ball;
  }

  /// Abandonar: termina ya, sin penalización.
  void abandon() => _finish(SafariEnd.abandoned);

  /// Cierra el resumen: vuelta al modo libre.
  void close() {
    if (_phase != SafariPhase.finished) return;
    _phase = SafariPhase.off;
    notifyListeners();
  }

  /// Lo que pasa en el mundo (solo cuenta con el reto en marcha). Cada bola
  /// lanzada acaba de una sola manera: capturando, escapándose el Pokémon
  /// o fallando.
  void onWorldEvent(World3DEvent event) {
    if (!isRunning) return;
    switch (event) {
      case PokemonCaught(:final wild):
        _catches.add(wild.pokemon);
        _resolve();
      case PokemonBrokeFree() || BallMissed():
        _resolve();
      case SafariTimeUp():
        _finish(SafariEnd.timeUp);
      default:
        break;
    }
  }

  void _resolve() {
    _resolved++;
    if (_ballsLeft == 0 && _resolved >= _thrown) {
      _finish(SafariEnd.outOfBalls);
    } else {
      notifyListeners();
    }
  }

  void _finish(SafariEnd why) {
    if (!isRunning) return;
    _phase = SafariPhase.finished;
    _end = why;
    notifyListeners();
  }
}
