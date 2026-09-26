import '../../models/throw_quality.dart';

/// EL ARO QUE SE ENCOGE al apuntar a un Pokémon (Dart puro). Empieza del
/// tamaño del anillo de la mira (1) y se encoge a ritmo constante hasta
/// [minSize] en [cycle] segundos; entonces vuelve a empezar. Lo pequeño
/// que esté al pulsar "lanzar" decide la calidad del tiro
/// ([ThrowQuality]). Cambiar de objetivo o dejar de apuntar lo reinicia.
class ThrowRing {
  /// Segundos que tarda en encogerse del todo.
  static const cycle = 1.6;

  /// Tamaño más pequeño (respecto al anillo de la mira).
  static const minSize = 0.12;

  /// Por debajo de estos tamaños el tiro es "¡Bien!", "¡Genial!" y
  /// "¡Excelente!". Con el ritmo de arriba: ~0,45 s para cada uno de los
  /// dos primeros y ~0,24 s para el excelente (el más difícil).
  static const niceBelow = 0.75;
  static const greatBelow = 0.5;
  static const excellentBelow = 0.25;

  String? _target;
  double _time = 0;

  /// Id del Pokémon al que se apunta (null = no hay aro).
  String? get target => _target;

  bool get active => _target != null;

  /// Tamaño ahora (1 = como el anillo de la mira).
  double get size => 1 - (1 - minSize) * ((_time % cycle) / cycle);

  /// Calidad que tendría un tiro ahora ([ThrowQuality.none] sin aro).
  ThrowQuality get quality => active ? qualityFor(size) : ThrowQuality.none;

  static ThrowQuality qualityFor(double size) {
    if (size < excellentBelow) return ThrowQuality.excellent;
    if (size < greatBelow) return ThrowQuality.great;
    if (size < niceBelow) return ThrowQuality.nice;
    return ThrowQuality.none;
  }

  /// Pasa el tiempo apuntando a [target] (null si no se apunta a nadie o
  /// no se puede lanzar). Un objetivo nuevo empieza con el aro grande.
  void update(double dt, {required String? target}) {
    if (target != _target) {
      _target = target;
      _time = 0;
      return;
    }
    if (target != null) _time += dt;
  }
}
