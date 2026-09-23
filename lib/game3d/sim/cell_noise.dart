/// Número pseudoaleatorio estable por casilla (0..1): el mismo mapa
/// siempre genera los mismos árboles y matas de hierba, sin guardar nada.
///
/// Todo se hace en 32 bits (con [_mul32]) para que dé exactamente lo mismo
/// en Windows y en web, donde los enteros de Dart son doubles de 53 bits.
double cellNoise(int col, int row, [int salt = 0]) {
  var h =
      (_mul32(col, 73856093) ^ _mul32(row, 19349663) ^ _mul32(salt, 83492791)) &
      0xFFFFFFFF;
  h = _mul32(h ^ (h >> 13), 1274126177);
  h ^= h >> 16;
  return (h & 0xFFFF) / 0xFFFF;
}

/// Producto módulo 2^32 sin pasar nunca de 2^53 (seguro en web).
int _mul32(int a, int b) {
  final a32 = a & 0xFFFFFFFF;
  final lo = (a32 & 0xFFFF) * b;
  final hi = ((a32 >> 16) * b) & 0xFFFF;
  return (lo + (hi << 16)) & 0xFFFFFFFF;
}

/// Ruido SUAVE (0..1) en el plano: en los puntos enteros vale [cellNoise]
/// y entre ellos se mezcla con una curva suave, así que no tiene saltos.
/// Sirve para manchas grandes (dividir las coordenadas por el tamaño de
/// mancha deseado).
double smoothNoise(double x, double z, [int salt = 0]) {
  final x0 = x.floor();
  final z0 = z.floor();
  double ease(double t) => t * t * (3 - 2 * t);
  final tx = ease(x - x0);
  final tz = ease(z - z0);
  final a = cellNoise(x0, z0, salt);
  final b = cellNoise(x0 + 1, z0, salt);
  final c = cellNoise(x0, z0 + 1, salt);
  final d = cellNoise(x0 + 1, z0 + 1, salt);
  final top = a + (b - a) * tx;
  final bottom = c + (d - c) * tx;
  return top + (bottom - top) * tz;
}
