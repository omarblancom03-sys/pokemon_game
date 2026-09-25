import 'package:flutter/foundation.dart';

import '../game3d/sim/world3d_events.dart';
import '../game3d/sim/world3d_sim.dart' show WildSpawn;
import '../models/poke_ball.dart';
import '../models/pokemon.dart';
import '../services/poke_api_exception.dart';
import '../services/pokemon_repository.dart';
import '../services/random_pokemon_picker.dart';
import 'trainer_controller.dart';

/// Qué pasó, para el aviso que aparece en pantalla.
enum FieldNoticeKind {
  pickedUp,
  caught,
  brokeFree,
  missed,
  noBalls,

  /// Un Pokémon escondido salió de la hierba asustado.
  burstOut,

  /// Un Pokémon escondido se asomó sin verte (te acercaste con sigilo).
  peeked,

  /// Se recogieron bayas del suelo.
  berriesPickedUp,

  /// Se sacudió un arbusto que no tenía bayas.
  emptyBush,
}

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
    this.isNew = false,
    this.critical = false,
  });

  final int id;
  final FieldNoticeKind kind;
  final PokeBallType? ball;
  final int count;
  final Pokemon? pokemon;

  /// Sacudidas que aguantó la bola antes de abrirse (si se escapó).
  final int shakes;

  /// Captura de una especie que el entrenador aún no tenía.
  final bool isNew;

  /// Fue una captura crítica (una sola sacudida).
  final bool critical;
}

/// CONTROLADOR de una partida en el campo 3D: recibe lo que pasa en el
/// mundo (recogidas, capturas, fallos), lo apunta en la bolsa del
/// entrenador ([TrainerController], que vive en toda la app) y guarda los
/// avisos que la pantalla enseña unos segundos. También busca en PokeAPI
/// los Pokémon que aparecen en la hierba, con su ratio de captura real.
///
/// Se crea por partida (como el GameController): al salir, los avisos se
/// pierden pero la bolsa y los capturados se conservan.
class FieldController extends ChangeNotifier {
  FieldController({
    required this._trainer,
    required this._picker,
    required this._repository,
  });

  final TrainerController _trainer;
  final RandomPokemonPicker _picker;
  final PokemonRepository _repository;

  /// Ratio si PokeAPI no lo da (el de muchos Pokémon "normales").
  static const fallbackCaptureRate = 45;

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
      case PokemonCaught(:final wild, :final ball, :final result):
        final isNew = !_trainer.hasCaught(wild.pokemon.id);
        _trainer.registerCapture(wild.pokemon, ball);
        _post(
          FieldNoticeKind.caught,
          ball: ball,
          pokemon: wild.pokemon,
          isNew: isNew,
          critical: result.critical,
        );
      case PokemonBrokeFree(:final wild, :final ball, :final result):
        _post(
          FieldNoticeKind.brokeFree,
          ball: ball,
          pokemon: wild.pokemon,
          shakes: result.shakes,
        );
      case BerriesPickedUp(:final count):
        _trainer.addBerries(count);
        // Las bayas de una sacudida se recogen una tras otra: se suman en
        // el mismo aviso ("+3") en vez de enseñar tres "+1".
        final last = _notices.lastOrNull;
        var total = count;
        if (last?.kind == FieldNoticeKind.berriesPickedUp) {
          _notices.removeLast();
          total += last!.count;
        }
        _post(FieldNoticeKind.berriesPickedUp, count: total);
      case BushShaken(:final berries):
        if (berries == 0) _post(FieldNoticeKind.emptyBush);
      case PokemonRevealed(:final wild, :final startled):
        _post(
          startled ? FieldNoticeKind.burstOut : FieldNoticeKind.peeked,
          pokemon: wild.pokemon,
        );
    }
  }

  /// Un Pokémon al azar para la hierba, con su ratio de captura. Sin red
  /// devuelve null (el mundo lo reintentará); si solo falla el ratio, se
  /// usa [fallbackCaptureRate].
  Future<WildSpawn?> pickWildSpawn() async {
    final Pokemon pokemon;
    try {
      pokemon = await _picker.pick();
    } on PokeApiException {
      return null;
    }
    var rate = fallbackCaptureRate;
    try {
      rate = await _repository.getCaptureRate(pokemon.id);
    } on PokeApiException {
      // Se queda el de por defecto: mejor un ratio aproximado que nada.
    }
    return (pokemon: pokemon, captureRate: rate);
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
    bool isNew = false,
    bool critical = false,
  }) {
    _notices.add(
      FieldNotice(
        id: _nextId++,
        kind: kind,
        ball: ball,
        count: count,
        pokemon: pokemon,
        shakes: shakes,
        isNew: isNew,
        critical: critical,
      ),
    );
    if (_notices.length > maxNotices) _notices.removeAt(0);
    notifyListeners();
  }
}
