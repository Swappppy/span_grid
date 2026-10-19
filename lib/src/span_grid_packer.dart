import 'dart:typed_data';

import 'cell_rect.dart';
import 'span_spec.dart';

/// Packs [SpanSpec]s into a fixed number of columns.
///
/// Placement is deterministic: the same input always produces the same output.
/// Items are laid out in list order, scanning cells row by row.
///
/// With `dense: false` the scan cursor never moves backwards, so holes left by
/// spanning items are only filled by later items that happen to reach them.
/// With `dense: true` every item is placed in the first free position from the
/// top-left corner, which mirrors CSS `grid-auto-flow: dense`.
class SpanGridPacker {
  /// Creates a packer.
  const SpanGridPacker();

  /// Lays out [order] in a grid with [columns] columns.
  ///
  /// Items whose [SpanSpec.crossSpan] is larger than [columns] are clipped to
  /// the available width, which makes responsive layouts work without changing
  /// the specs.
  ///
  /// Throws an [ArgumentError] if [columns] is less than one, if two specs
  /// share an id, or if a span is less than one.
  Map<Object, CellRect> pack(
    List<SpanSpec> order,
    int columns, {
    bool dense = false,
  }) {
    if (columns < 1) {
      throw ArgumentError.value(columns, 'columns', 'must be at least 1');
    }

    final occupancy = <Uint8List>[];
    final result = <Object, CellRect>{};
    var cursorRow = 0;
    var cursorColumn = 0;

    for (final spec in order) {
      if (spec.crossSpan < 1) {
        throw ArgumentError.value(
          spec.crossSpan,
          'crossSpan',
          'must be at least 1 (item ${spec.id})',
        );
      }
      if (spec.mainSpan < 1) {
        throw ArgumentError.value(
          spec.mainSpan,
          'mainSpan',
          'must be at least 1 (item ${spec.id})',
        );
      }
      if (result.containsKey(spec.id)) {
        throw ArgumentError.value(
          spec.id,
          'order',
          'contains the same id more than once',
        );
      }

      final crossSpan = spec.crossSpan > columns ? columns : spec.crossSpan;
      final mainSpan = spec.mainSpan;

      final int row;
      final int column;
      if (dense) {
        final position = _firstFit(
          occupancy,
          columns,
          startRow: 0,
          startColumn: 0,
          crossSpan: crossSpan,
          mainSpan: mainSpan,
        );
        row = position.row;
        column = position.column;
      } else {
        final position = _firstFit(
          occupancy,
          columns,
          startRow: cursorRow,
          startColumn: cursorColumn,
          crossSpan: crossSpan,
          mainSpan: mainSpan,
        );
        row = position.row;
        column = position.column;

        if (column + crossSpan >= columns) {
          cursorRow = row + 1;
          cursorColumn = 0;
        } else {
          cursorRow = row;
          cursorColumn = column + crossSpan;
        }
      }

      _occupy(
        occupancy,
        columns,
        row: row,
        column: column,
        crossSpan: crossSpan,
        mainSpan: mainSpan,
      );
      result[spec.id] = CellRect(
        row: row,
        column: column,
        rowSpan: mainSpan,
        columnSpan: crossSpan,
      );
    }

    return result;
  }

  ({int row, int column}) _firstFit(
    List<Uint8List> occupancy,
    int columns, {
    required int startRow,
    required int startColumn,
    required int crossSpan,
    required int mainSpan,
  }) {
    var row = startRow;
    var column = startColumn;

    while (true) {
      if (column + crossSpan > columns) {
        row++;
        column = 0;
        continue;
      }
      if (_fits(
        occupancy,
        row: row,
        column: column,
        crossSpan: crossSpan,
        mainSpan: mainSpan,
      )) {
        return (row: row, column: column);
      }
      column++;
      if (column + crossSpan > columns) {
        row++;
        column = 0;
      }
    }
  }

  bool _fits(
    List<Uint8List> occupancy, {
    required int row,
    required int column,
    required int crossSpan,
    required int mainSpan,
  }) {
    final lastRow = row + mainSpan;
    for (var r = row; r < lastRow; r++) {
      if (r >= occupancy.length) {
        continue;
      }
      final cells = occupancy[r];
      for (var c = column; c < column + crossSpan; c++) {
        if (cells[c] != 0) {
          return false;
        }
      }
    }
    return true;
  }

  void _occupy(
    List<Uint8List> occupancy,
    int columns, {
    required int row,
    required int column,
    required int crossSpan,
    required int mainSpan,
  }) {
    final lastRow = row + mainSpan;
    while (occupancy.length < lastRow) {
      occupancy.add(Uint8List(columns));
    }
    for (var r = row; r < lastRow; r++) {
      final cells = occupancy[r];
      for (var c = column; c < column + crossSpan; c++) {
        cells[c] = 1;
      }
    }
  }
}
