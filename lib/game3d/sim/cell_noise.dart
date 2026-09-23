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
