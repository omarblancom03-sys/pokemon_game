import 'dart:ui';

/// Qué hay en cada casilla del mapa. Cada tipo tiene su carácter en el
/// dibujo ASCII y sabe si se puede pisar.
enum TileKind {
  grass('.', walkable: true),
  flowers(',', walkable: true),
  tallGrass('"', walkable: true),
  path('=', walkable: true),
  stone('o', walkable: true),
  mushroom('m', walkable: true),
  tree('T', walkable: false),
  pine('P', walkable: false),
  autumnTree('A', walkable: false),
  bush('b', walkable: false),
  fence('#', walkable: false),
  sign('s', walkable: false),
  house('H', walkable: false);

  const TileKind(this.symbol, {required this.walkable});

  final String symbol;
  final bool walkable;
}

/// EL MAPA como datos: una cuadrícula de [TileKind] leída de un dibujo
/// ASCII (una cadena por fila). No sabe nada de Flame ni de imágenes; por
/// eso se puede probar con tests normales.
///
/// El carácter `@` marca dónde empieza Ash (esa casilla es camino).
class MapLayout {
  MapLayout._(this._cells, this.columns, this.rows, this.start);

  /// Lee el dibujo. Lanza [FormatException] si las filas no miden lo mismo,
  /// si hay un carácter desconocido o si no hay exactamente un `@`.
  factory MapLayout.parse(List<String> lines) {
    if (lines.isEmpty || lines.first.isEmpty) {
      throw const FormatException('El mapa está vacío');
    }
    final columns = lines.first.length;
    final bySymbol = {for (final k in TileKind.values) k.symbol: k};
    final cells = <TileKind>[];
    ({int col, int row})? start;

    for (var row = 0; row < lines.length; row++) {
      final line = lines[row];
      if (line.length != columns) {
        throw FormatException(
          'La fila $row mide ${line.length}, se esperaban $columns',
        );
      }
      for (var col = 0; col < columns; col++) {
        final symbol = line[col];
        if (symbol == '@') {
          if (start != null) {
            throw const FormatException('Hay más de un inicio (@)');
          }
          start = (col: col, row: row);
          cells.add(TileKind.path);
          continue;
        }
        final kind = bySymbol[symbol];
        if (kind == null) {
          throw FormatException('Carácter desconocido "$symbol" en $col,$row');
        }
        cells.add(kind);
      }
    }
    if (start == null) throw const FormatException('Falta el inicio (@)');
    return MapLayout._(List.unmodifiable(cells), columns, lines.length, start);
  }

  final List<TileKind> _cells;
  final int columns;
  final int rows;

  /// Casilla donde empieza Ash.
  final ({int col, int row}) start;

  bool contains(int col, int row) =>
      col >= 0 && col < columns && row >= 0 && row < rows;

  /// Lo que hay en la casilla. Fuera del mapa devuelve null.
  TileKind? tileAt(int col, int row) =>
      contains(col, row) ? _cells[row * columns + col] : null;

  /// Fuera del mapa cuenta como NO pisable.
  bool isWalkable(int col, int row) => tileAt(col, row)?.walkable ?? false;

  /// ¿Todas las casillas que toca este rectángulo (en píxeles) se pueden
  /// pisar? Lo usa Ash para no atravesar árboles ni casas.
  bool isAreaWalkable(Rect area, double tileSize) {
    final firstCol = (area.left / tileSize).floor();
    final lastCol = ((area.right - 0.001) / tileSize).floor();
    final firstRow = (area.top / tileSize).floor();
    final lastRow = ((area.bottom - 0.001) / tileSize).floor();
    for (var row = firstRow; row <= lastRow; row++) {
      for (var col = firstCol; col <= lastCol; col++) {
        if (!isWalkable(col, row)) return false;
      }
    }
    return true;
  }

  /// Todas las casillas pisables, en orden de lectura. Sirve para colocar
  /// humos solo donde Ash puede llegar.
  Iterable<({int col, int row})> get walkableCells sync* {
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        if (isWalkable(col, row)) yield (col: col, row: row);
      }
    }
  }
}
