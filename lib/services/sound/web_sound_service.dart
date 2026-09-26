import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'sound_service.dart';

/// SONIDO EN LA WEB: todo se SINTETIZA con Web Audio (osciladores y ruido
/// filtrado, estilo chiptune): no hay archivos de sonido que cargar ni
/// licencias que cumplir. Los gritos son los .ogg de PokeAPI.
///
/// El contexto de audio se crea con el primer sonido: el navegador solo lo
/// deja sonar tras un gesto del usuario, y para entonces ya lo hubo (tocar
/// "Jugar 3D"). Si algo falla (navegador sin Web Audio), no suena y ya.
class WebSoundService implements SoundService {
  web.AudioContext? _context;
  web.GainNode? _master;
  web.AudioBuffer? _noise;
  final _random = math.Random();

  @override
  bool muted = false;

  /// Volumen general de los efectos y de los gritos.
  static const volume = 0.5;
  static const cryVolume = 0.35;

  web.AudioContext? _ready() {
    try {
      var ctx = _context;
      if (ctx == null) {
        ctx = web.AudioContext();
        final master = ctx.createGain();
        master.gain.setValueAtTime(volume, 0);
        master.connect(ctx.destination);
        _context = ctx;
        _master = master;
      }
      if (ctx.state == 'suspended') {
        unawaited(ctx.resume().toDart.then((_) {}, onError: (Object _) {}));
      }
      return ctx;
    } on Object {
      return null;
    }
  }

  /// Volumen del sonido que se está sintetizando (ver [play]).
  double _level = 1;

  @override
  void play(GameSound sound, {double volume = 1}) {
    if (muted || volume <= 0) return;
    final ctx = _ready();
    if (ctx == null) return;
    _level = volume.clamp(0.0, 1.0);
    try {
      switch (sound) {
        case GameSound.stepDirt:
          _hiss(ctx, 450, q: 0.8, duration: 0.07, gain: 0.07);
          _tone(ctx, 'sine', 95, to: 60, duration: 0.06, gain: 0.12);
        case GameSound.stepStone:
          _hiss(ctx, 2200, q: 4, duration: 0.035, gain: 0.07);
          _tone(ctx, 'triangle', 190, to: 150, duration: 0.04, gain: 0.07);
        case GameSound.stepGrass:
          _hiss(ctx, 1400, q: 0.7, duration: 0.06, gain: 0.035);
        case GameSound.stepTallGrass:
          _hiss(ctx, 900, to: 2600, q: 0.9, duration: 0.2, gain: 0.09);
          _hiss(ctx, 3500, q: 2, duration: 0.08, at: 0.05, gain: 0.03);
        case GameSound.throwBall:
          _tone(ctx, 'sine', 500, to: 1500, duration: 0.2, gain: 0.18);
          _hiss(ctx, 900, to: 2500, duration: 0.25, gain: 0.12);
        case GameSound.throwBerry:
          _tone(ctx, 'sine', 650, to: 1100, duration: 0.14, gain: 0.12);
          _hiss(ctx, 1200, duration: 0.16, gain: 0.06);
        case GameSound.hit:
          _tone(ctx, 'square', 220, to: 1100, duration: 0.28, gain: 0.07);
          _tone(ctx, 'sine', 440, to: 1760, duration: 0.3, gain: 0.1);
          _hiss(ctx, 3000, duration: 0.1, gain: 0.08);
        case GameSound.shake:
          _knock(ctx, gain: 1);
        case GameSound.criticalShake:
          _knock(ctx, gain: 1.4);
          _sparkle(ctx, at: 0.02);
        case GameSound.caught:
          _caught(ctx);
        case GameSound.criticalCaught:
          _caught(ctx);
          _sparkle(ctx, at: 0.2);
        case GameSound.brokeFree:
          _tone(ctx, 'sine', 900, to: 180, duration: 0.16, gain: 0.25);
          _hiss(ctx, 800, duration: 0.12, gain: 0.15);
        case GameSound.pickUp:
          _tone(ctx, 'sine', 880, duration: 0.09, gain: 0.14);
          _tone(ctx, 'sine', 1318.5, duration: 0.14, at: 0.07, gain: 0.14);
        case GameSound.bushRustle:
          _hiss(ctx, 700, to: 1600, q: 0.6, duration: 0.35, gain: 0.18);
          _hiss(ctx, 2500, duration: 0.25, at: 0.1, gain: 0.08);
        case GameSound.dodge:
          _hiss(ctx, 2600, to: 700, q: 1.2, duration: 0.2, gain: 0.14);
          _tone(ctx, 'triangle', 420, to: 780, duration: 0.12, gain: 0.1);
        case GameSound.dazed:
          _tone(ctx, 'triangle', 1200, to: 500, duration: 0.18, gain: 0.12);
          _tone(
            ctx,
            'triangle',
            1000,
            to: 420,
            duration: 0.18,
            at: 0.16,
            gain: 0.1,
          );
          _tone(
            ctx,
            'triangle',
            850,
            to: 350,
            duration: 0.24,
            at: 0.32,
            gain: 0.08,
          );
        case GameSound.shiny:
          _sparkle(ctx);
          _sparkle(ctx, at: 0.22);
          _tone(ctx, 'triangle', 1568, to: 3136, duration: 0.5, gain: 0.08);
      }
    } on Object {
      // Un navegador raro: mejor sin sonido que romper el juego.
    }
  }

  @override
  void playCry(int pokemonId) {
    if (muted) return;
    try {
      final audio = web.HTMLAudioElement()
        ..src = pokemonCryUrl(pokemonId)
        ..volume = cryVolume;
      // Si no carga (sin red) o el navegador no deja, no pasa nada.
      unawaited(audio.play().toDart.then((_) {}, onError: (Object _) {}));
    } on Object {
      // Igual que arriba.
    }
  }

  /// "Toc" de madera: una sacudida de la bola ([gain] = fuerza).
  void _knock(web.AudioContext ctx, {required double gain}) {
    _tone(ctx, 'triangle', 330, to: 260, duration: 0.09, gain: 0.35 * gain);
    _tone(ctx, 'sine', 660, to: 520, duration: 0.06, gain: 0.12 * gain);
    _hiss(ctx, 1500, q: 3, duration: 0.05, gain: 0.1 * gain);
  }

  /// Destellos: tres notas agudas muy rápidas.
  void _sparkle(web.AudioContext ctx, {double at = 0}) {
    const notes = [2093.0, 2637.0, 3136.0];
    for (var i = 0; i < notes.length; i++) {
      _tone(
        ctx,
        'sine',
        notes[i],
        duration: 0.2,
        at: at + i * 0.06,
        gain: 0.07,
      );
    }
  }

  /// "Clic, clic" (la bola se cierra) y una fanfarria corta: Do-Mi-Sol-Do.
  void _caught(web.AudioContext ctx) {
    _tone(ctx, 'square', 1900, duration: 0.035, gain: 0.12);
    _tone(ctx, 'square', 1900, duration: 0.035, at: 0.07, gain: 0.12);
    const notes = [523.25, 659.25, 783.99, 1046.5];
    for (var i = 0; i < notes.length; i++) {
      final at = 0.3 + i * 0.12;
      final last = i == notes.length - 1;
      final length = last ? 0.5 : 0.11;
      _tone(ctx, 'square', notes[i], duration: length, at: at, gain: 0.06);
      // El bajo, una octava por debajo y más suave.
      _tone(
        ctx,
        'triangle',
        notes[i] / 2,
        duration: length,
        at: at,
        gain: 0.12,
      );
    }
  }

  /// Una nota: onda [type] de [from] Hz (a [to] Hz si se da) que empieza
  /// dentro de [at] s y dura [duration] s, con ataque corto y caída.
  void _tone(
    web.AudioContext ctx,
    String type,
    double from, {
    double? to,
    required double duration,
    double at = 0,
    required double gain,
  }) {
    final t = ctx.currentTime + at;
    final osc = ctx.createOscillator()..type = type;
    osc.frequency.setValueAtTime(from, t);
    if (to != null) {
      osc.frequency.exponentialRampToValueAtTime(to, t + duration);
    }
    final amp = _envelope(ctx, t, duration, gain);
    osc.connect(amp);
    osc
      ..start(t)
      ..stop(t + duration + 0.02);
  }

  /// Un soplo: ruido blanco por un filtro de banda en [freq] Hz (que va a
  /// [to] Hz si se da).
  void _hiss(
    web.AudioContext ctx,
    double freq, {
    double? to,
    double q = 1,
    required double duration,
    double at = 0,
    required double gain,
  }) {
    final t = ctx.currentTime + at;
    final source = ctx.createBufferSource()..buffer = _noiseBuffer(ctx);
    final filter = ctx.createBiquadFilter()..type = 'bandpass';
    filter.frequency.setValueAtTime(freq, t);
    if (to != null) {
      filter.frequency.exponentialRampToValueAtTime(to, t + duration);
    }
    filter.Q.setValueAtTime(q, t);
    source.connect(filter);
    filter.connect(_envelope(ctx, t, duration, gain));
    source
      ..start(t)
      ..stop(t + duration + 0.02);
  }

  /// Volumen que sube en 10 ms hasta [gain] y cae hasta casi 0 al final.
  web.GainNode _envelope(
    web.AudioContext ctx,
    double t,
    double duration,
    double gain,
  ) {
    final amp = ctx.createGain();
    amp.gain
      ..setValueAtTime(0.0001, t)
      ..exponentialRampToValueAtTime(math.max(0.0002, gain * _level), t + 0.01)
      ..exponentialRampToValueAtTime(0.0001, t + duration);
    amp.connect(_master!);
    return amp;
  }

  /// Un segundo de ruido blanco (se crea una vez y se reutiliza).
  web.AudioBuffer _noiseBuffer(web.AudioContext ctx) {
    final cached = _noise;
    if (cached != null) return cached;
    final rate = ctx.sampleRate;
    final length = rate.round();
    final data = Float32List(length);
    for (var i = 0; i < length; i++) {
      data[i] = _random.nextDouble() * 2 - 1;
    }
    final buffer = ctx.createBuffer(1, length, rate);
    buffer.copyToChannel(data.toJS, 0);
    return _noise = buffer;
  }
}
