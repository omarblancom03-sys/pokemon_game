import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

import 'grass_field.dart';

/// HIERBA PISADA (Dart puro): el rastro que deja un Pokémon que pasa
/// CORRIENDO por la hierba alta (huyendo o cargando). Las matas por las
/// que pasa quedan tumbadas hacia donde iba, siguen así un rato y luego se
/// levantan poco a poco: se puede ver por dónde se fue.
///
/// Se guarda POR MATA (dirección, fuerza y edad), así el renderer solo lee
/// un valor por mata y pisar solo mira las matas de las casillas vecinas.
class GrassTrampling {
  GrassTrampling(this.field, {required this.tileSize})
    : _dirX = Float64List(field.tufts.length),
      _dirZ = Float64List(field.tufts.length),
      _weight = Float64List(field.tufts.length),
      _age = Float64List(field.tufts.length) {
    for (var i = 0; i < field.tufts.length; i++) {
      final t = field.tufts[i];
      (_byCell[_cellOf(t.x, t.z)] ??= []).add(i);
    }
  }

  final GrassField field;
  final double tileSize;

  final Float64List _dirX;
  final Float64List _dirZ;
  final Float64List _weight;
  final Float64List _age;

  /// Matas de cada casilla (para no recorrerlas todas al pisar).
  final Map<(int, int), List<int>> _byCell = {};

  /// Matas pisadas que aún no se han levantado del todo.
  final Set<int> _active = {};

  /// Radio (m) de la pisada alrededor de quien pasa.
  static const radius = 0.9;

  /// Segundos que se quedan tumbadas del todo y los que tardan después en
  /// levantarse.
  static const holdTime = 10.0;
  static const recoverTime = 12.0;
  static const life = holdTime + recoverTime;

  /// Ángulo (rad) de una mata pisada de lleno.
  static const maxBend = 0.85;

  /// Lo que baja una mata pisada de lleno (0,55 = queda al 45 % de su
  /// altura): aplastada se nota mucho más que solo inclinada.
  static const flatten = 0.55;

  (int, int) _cellOf(double x, double z) =>
      ((x / tileSize).floor(), (z / tileSize).floor());

  /// Matas pisadas ahora (índices en [GrassField.tufts]).
  Iterable<int> get trampled => _active;

  /// Lo pisada que está la mata [i] ahora, 0..1.
  double amountOf(int i) {
    final w = _weight[i];
    if (w == 0) return 0;
    final age = _age[i];
    if (age <= holdTime) return w;
    return w * (1 - (age - holdTime) / recoverTime).clamp(0.0, 1.0);
  }

  /// Altura de la mata [i] respecto a la normal (1 = sin pisar).
  double heightOf(int i) => 1 - flatten * amountOf(i);

  /// Hacia dónde está tumbada la mata [i] y cuánto (cero si no lo está).
  GrassBend bendOf(int i) {
    final a = amountOf(i);
    if (a == 0) return (x: 0, z: 0);
    return (x: _dirX[i] * a * maxBend, z: _dirZ[i] * a * maxBend);
  }

  /// Alguien pasa corriendo por [at] yendo hacia [direction]: las matas a
  /// menos de [radius] quedan tumbadas hacia allí (del todo en el centro
  /// de su paso, menos en los bordes). Una pisada nueva solo cambia una
  /// mata si la tumba más de lo que ya estaba.
  void trample(Vector3 at, Vector3 direction) {
    final len = math.sqrt(
      direction.x * direction.x + direction.z * direction.z,
    );
    if (len < 1e-9) return;
    final dx = direction.x / len, dz = direction.z / len;
    final (col, row) = _cellOf(at.x, at.z);
    for (var r = row - 1; r <= row + 1; r++) {
      for (var c = col - 1; c <= col + 1; c++) {
        for (final i in _byCell[(c, r)] ?? const <int>[]) {
          final t = field.tufts[i];
          final d = math.sqrt(
            (t.x - at.x) * (t.x - at.x) + (t.z - at.z) * (t.z - at.z),
          );
          if (d >= radius) continue;
          final w = math.min(1.0, 1.5 * (1 - d / radius));
          if (w < amountOf(i)) continue;
          _weight[i] = w;
          _age[i] = 0;
          _dirX[i] = dx;
          _dirZ[i] = dz;
          _active.add(i);
        }
      }
    }
  }

  /// Pasa el tiempo: las pisadas envejecen y las que ya se levantaron
  /// salen de la lista.
  void update(double dt) {
    _active.removeWhere((i) {
      _age[i] += dt;
      if (_age[i] < life) return false;
      _weight[i] = 0;
      return true;
    });
  }
}
