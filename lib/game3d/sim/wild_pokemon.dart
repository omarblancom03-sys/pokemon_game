import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import '../../models/pokemon.dart';
import 'berries.dart';
import 'cell_noise.dart';

/// Carácter de un Pokémon salvaje: qué hace cuando te descubre.
enum Temperament {
  /// Huye (la mayoría): hay que acercarse con sigilo.
  skittish,

  /// Se acerca a mirar y se queda cerca.
  curious,

  /// Carga contra ti; si te alcanza empieza un encuentro (combate).
  aggressive;

  /// El carácter depende de la especie (siempre el mismo para cada una).
  static Temperament forSpecies(int id) {
    final n = cellNoise(id, 17, 3);
    if (n < 0.5) return skittish;
    if (n < 0.85) return curious;
    return aggressive;
  }
}

/// Un Pokémon salvaje VISIBLE en el mundo 3D (estilo Leyendas/Escarlata):
/// deambula por la hierba alta, puede descubrirte (?/!) y reaccionar según
/// su carácter, y se le puede lanzar una Poké Ball.
class WildPokemon {
  WildPokemon({
    required this.id,
    required this.pokemon,
    required Vector3 position,
    this.captureRate = 45,
    this.facing = 0,
    Temperament? temperament,
    this.shiny = false,
  }) : _position = position.clone(),
       temperament = temperament ?? Temperament.forSpecies(pokemon.id);

  final String id;
  final Pokemon pokemon;

  /// Ratio de captura real de la especie (PokeAPI, 3..255).
  final int captureRate;
  final Temperament temperament;

  /// VARIOCOLOR (shiny): colores raros. Solo cosmético: se captura igual.
  final bool shiny;

  /// Ya lo vio el jugador (se avisa una sola vez) y en qué segundo del
  /// juego (para el destello grande de ese momento).
  bool shinySpotted = false;
  double? shinySpottedAt;

  Vector3 _position;
  Vector3 get position => _position.clone();
  set position(Vector3 value) => _position = value.clone();

  /// Hacia dónde mira (0 = +Z), como el jugador.
  double facing;

  /// Velocidad actual en el suelo (m/s): la mira la usa para adelantarse.
  Vector3 velocity = Vector3.zero();

  /// Punto al que se dirige, o null si está parado.
  Vector3? target;

  /// Segundos que le quedan de descanso antes de elegir otro destino.
  double idleTime = 0;

  /// Metros recorridos: marca el ritmo de los saltitos.
  double distanceMoved = 0;

  /// Segundos desde que apareció (para la animación de entrada).
  double age = 0;

  /// Ya disparó su encuentro (combate): no vuelve a dispararlo.
  bool engaged = false;

  /// Sospecha 0..1: sube si te ve u oye; al llegar a 1 te descubre.
  double awareness = 0;

  /// Segundos que le quedan de alerta (0 = tranquilo).
  double alertTime = 0;

  /// Id de la Poké Ball que lo tiene dentro (null = libre).
  String? capturedBy;

  /// Segundos desde que salió de una bola (animación de "pop").
  double? releasedFor;

  /// Escondido en la hierba alta: no se ve, solo se agita la hierba
  /// donde está. Sale al acercarte (ver World3DSim).
  bool hidden = false;

  /// Segundos desde que salió de la hierba (animación del salto).
  double? revealedFor;

  /// Segundos que lleva escondido (si nadie lo encuentra, se va).
  double hiddenTime = 0;

  /// Baya del suelo a la que va o que se está comiendo (null = ninguna).
  LooseBerry? bait;

  /// Segundos que lleva yendo hacia su baya (si se atasca, se rinde).
  double baitTime = 0;

  /// Segundos que lleva comiendo (null = no está comiendo). Mientras
  /// come apenas se entera de nada: no ve y casi no oye.
  double? eatingFor;

  /// ESQUIVA: segundos desde que empezó a apartarse de una bola de un
  /// salto lateral (null = no esquiva). Va de [dodgeFrom] a [dodgeTo] en
  /// [dodgeTime].
  double? dodgingFor;
  Vector3 dodgeFrom = Vector3.zero();
  Vector3 dodgeTo = Vector3.zero();

  /// Bola por la que ya decidió si esquivar (se decide una vez por bola).
  String? dodgeCheckedBall;

  bool get isDodging => dodgingFor != null;

  /// Lo que dura el salto de la esquiva (s) y cuánto se aparta (m).
  static const dodgeTime = 0.3;
  static const dodgeDistance = 1.6;

  /// Altura extra del salto de la esquiva (0 si no esquiva).
  double get dodgeJump {
    final t = dodgingFor;
    if (t == null || t >= dodgeTime) return 0;
    final s = t / dodgeTime;
    return 4 * s * (1 - s) * 0.45;
  }

  /// Se PASA DE LARGO: embestía y rodaste a un lado; corre recto hasta este
  /// punto (donde estabas, y algo más) y queda aturdido. null = no.
  Vector3? overshootTo;

  /// ATURDIDO tras pasarse de largo: segundos que lleva (null = no). No se
  /// mueve ni se entera de nada: ¡la ocasión de lanzarle una bola!
  double? dazedFor;

  bool get isDazed => dazedFor != null;

  /// Lo que dura el aturdimiento (s) y la rapidez al pasarse de largo.
  static const dazeSeconds = 2.5;
  static const overshootSpeed = 5.0;

  /// MANADA a la que pertenece (null = va solo). Los de una manada son de
  /// la misma especie, pasean juntos y se avisan (ver World3DSim).
  String? herdId;

  /// Dónde está el guía de su manada, al que sigue al pasear (null = no
  /// sigue a nadie: va solo o es él quien guía). Lo pone la simulación.
  Vector3? herdHome;

  /// Segundos que faltan para que le llegue el aviso de alarma de su
  /// manada (null = ninguno): entonces te descubre él también ("!").
  double? alarmIn;

  /// Segundos que lleva YÉNDOSE para siempre (null = no se va): en el Reto
  /// Safari, tras escaparse de una bola, puede huir. Corre lejos de ti y
  /// desaparece (ver World3DSim).
  double? leavingFor;

  bool get isLeaving => leavingFor != null;

  /// Metros por segundo al deambular, huir y cargar.
  static const wanderSpeed = 1.3;
  static const fleeSpeed = 4.4;
  static const chargeSpeed = 3.6;

  bool get isAlert => alertTime > 0;
  bool get isFree => capturedBy == null;

  /// Se está comiendo una baya (distraído: más fácil de capturar).
  bool get isEating => eatingFor != null;

  /// Lo que tarda en comerse una baya (s).
  static const eatSeconds = 6.0;

  /// Rapidez (m/s) con la que va hacia una baya: con ganas.
  static const baitSpeed = 2.0;

  /// Mordiscos (0..1) para la animación: se agacha un poco a comer, unas
  /// tres veces por segundo. 0 si no está comiendo.
  double get munch {
    final t = eatingFor;
    return t == null ? 0 : math.sin(t * 9).abs();
  }

  /// DORMIDO ("Zzz"): no se mueve ni ve; solo le despierta el ruido cerca,
  /// que le toquen o una bola que cae al lado (ver World3DSim). Mientras
  /// duerme, [awareness] mide lo cerca que está de despertarse.
  bool asleep = false;

  /// Segundos que lleva dormido (si nadie le despierta, se despierta solo).
  double sleptFor = 0;

  /// Dormido está tumbado: su dibujo mide esta parte de lo normal.
  static const sleepSquash = 0.78;

  /// Se revuelve en sueños: algo le está despertando (¡quieto o agáchate!).
  bool get isStirring => asleep && awareness > 0.35;

  /// Segundos desde que se despertó (null = no se está despertando): se
  /// queda un momento espabilándose antes de reaccionar. [wokeStartled]:
  /// se despertó de golpe (por ti), con un respingo.
  double? wakingFor;
  bool wokeStartled = false;

  bool get isWaking => wakingFor != null;

  /// Lo que tarda en espabilarse (s).
  static const wakeSeconds = 0.8;

  /// Altura del respingo al despertarse de golpe (0 si no).
  double get wakeJump {
    final t = wakingFor;
    if (t == null || !wokeStartled || t >= 0.35) return 0;
    final s = t / 0.35;
    return 4 * s * (1 - s) * 0.35;
  }

  /// "?" en la cabeza: sospecha pero aún no te ha descubierto (dormido no
  /// sospecha: se revuelve, ver [isStirring]).
  bool get isSuspicious => !isAlert && !asleep && awareness > 0.35;

  /// Dirección a la que mira, en el suelo.
  Vector3 get facingDirection => Vector3(math.sin(facing), 0, math.cos(facing));

  /// Altura del dibujo en metros, a partir de la altura real del Pokémon
  /// (PokeAPI la da en decímetros). Se exagera un poco y se limita: un
  /// Pikachu de 0,4 m quedaría escondido en la hierba alta.
  double get displayHeight =>
      (pokemon.height / 10 * 1.3 + 0.5).clamp(1.1, 3.2).toDouble();

  /// Radio del "cilindro" que recibe los golpes de las Poké Balls.
  double get hitRadius => 0.3 + displayHeight * 0.22;

  /// Distancia (m) a la que el jugador "lo toca".
  double get contactRadius => 0.55 + displayHeight * 0.2;

  /// Altura del saltito ahora mismo (0 cuando está parado).
  double get hopHeight => target == null
      ? 0
      : (math.sin(distanceMoved * (isAlert ? 7 : 5)).abs() * 0.18);

  /// Duración del salto al salir de la hierba (s).
  static const revealJumpTime = 0.55;

  /// Altura extra del salto al salir de la hierba (0 si ya aterrizó).
  double get revealJump {
    final t = revealedFor;
    if (t == null || t >= revealJumpTime) return 0;
    final s = t / revealJumpTime;
    return 4 * s * (1 - s) * 0.9; // parábola: 0,9 m en lo más alto
  }
}
