import 'package:meta/meta.dart';

/// The position and size of an item in a [SpanGridPacker] result.
///
/// All values are expressed in grid cells. [row] and [column] are zero-based.
/// [rowSpan] and [columnSpan] are always at least one.
@immutable
class CellRect {
  /// Creates a cell rectangle.
  const CellRect({
    required this.row,
    required this.column,
    this.rowSpan = 1,
    this.columnSpan = 1,
  })  : assert(row >= 0, 'row must be non-negative'),
        assert(column >= 0, 'column must be non-negative'),
        assert(rowSpan >= 1, 'rowSpan must be at least one'),
        assert(columnSpan >= 1, 'columnSpan must be at least one');

  /// The first row occupied by the item.
  final int row;

  /// The first column occupied by the item.
  final int column;

  /// The number of rows occupied by the item.
  final int rowSpan;

  /// The number of columns occupied by the item.
  final int columnSpan;

  /// The exclusive end row.
  int get rowEnd => row + rowSpan;

  /// The exclusive end column.
  int get columnEnd => column + columnSpan;

  /// The center of the rectangle, in cell units.
  ///
  /// The center of a single cell is `(column + 0.5, row + 0.5)`.
  double get centerColumn => column + columnSpan / 2;

  /// The center of the rectangle, in cell units.
  ///
  /// The center of a single cell is `(column + 0.5, row + 0.5)`.
  double get centerRow => row + rowSpan / 2;

  /// Whether this rectangle shares at least one cell with [other].
  bool overlaps(CellRect other) {
    return row < other.rowEnd &&
        other.row < rowEnd &&
        column < other.columnEnd &&
        other.column < columnEnd;
  }

  /// Returns a copy moved by [rowDelta] rows and [columnDelta] columns.
  CellRect translate(int rowDelta, int columnDelta) {
    return CellRect(
      row: row + rowDelta,
      column: column + columnDelta,
      rowSpan: rowSpan,
      columnSpan: columnSpan,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CellRect &&
        other.row == row &&
        other.column == column &&
        other.rowSpan == rowSpan &&
        other.columnSpan == columnSpan;
  }

  @override
  int get hashCode => Object.hash(row, column, rowSpan, columnSpan);

  @override
  String toString() => 'CellRect(row: $row, column: $column, '
      'rowSpan: $rowSpan, columnSpan: $columnSpan)';
}
