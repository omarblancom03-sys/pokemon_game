import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

/// EL VIENTO del campo (Dart puro): hacia dónde sopla y sus RÁFAGAS, que
/// son olas que avanzan con él. Lo comparten todos los que se mueven con
/// el viento (las copas de los árboles, la hierba alta, las hojas que
/// caen) y el sonido: así la ola que se ve cruzar el prado es la misma que
/// mece el bosque y la que se oye llegar.
abstract final class Wind {
  /// Hacia dónde sopla (en el suelo; las nubes también van hacia +X).
  static final direction = Vector3(1, 0, 0.25)..normalize();

  /// Las RÁFAGAS son olas que avanzan con el viento: una de [gustLength] m
  /// a [gustSpeed] m/s (una cada ~6 s en cada sitio) y otra más larga y
  /// lenta que hace que no todas sean iguales.
  static const gustSpeed = 7.0;
  static const gustLength = 45.0;

  /// Fuerza de la ráfaga (0 = calma … 1 = ráfaga fuerte) en (x, z).
  static double gustAt(double time, double x, double z) {
    final along = x * direction.x + z * direction.z;
    const k = 2 * math.pi / gustLength;
    final a = math.sin((gustSpeed * time - along) * k);
    final b = math.sin((gustSpeed * 0.7 * time - along) * k / 1.7 + 1.3);
    final u = (0.6 * a + 0.4 * b + 1) / 2;
    return u * u; // más rato en calma; las ráfagas, más cortas
  }
}
