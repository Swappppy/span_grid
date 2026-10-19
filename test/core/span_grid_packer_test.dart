import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:span_grid/span_grid.dart';

void main() {
  const packer = SpanGridPacker();

  group('SpanGridPacker', () {
    test('fills rows in order', () {
      final layout = packer.pack(
        const [
          SpanSpec(id: 'a'),
          SpanSpec(id: 'b'),
          SpanSpec(id: 'c'),
        ],
        2,
      );

      expect(layout['a'], const CellRect(row: 0, column: 0));
      expect(layout['b'], const CellRect(row: 0, column: 1));
      expect(layout['c'], const CellRect(row: 1, column: 0));
    });

    test('clips spans wider than the grid', () {
      final layout = packer.pack(
        const [
          SpanSpec(id: 'wide', crossSpan: 5),
          SpanSpec(id: 'next'),
        ],
        3,
      );

      expect(layout['wide']!.columnSpan, 3);
      expect(layout['next'], const CellRect(row: 1, column: 0));
    });

    test('clips spans again when columns shrink', () {
      const specs = [
        SpanSpec(id: 'a', crossSpan: 3),
        SpanSpec(id: 'b', crossSpan: 2),
      ];

      final wide = packer.pack(specs, 4);
      final narrow = packer.pack(specs, 2);

      expect(wide['a']!.columnSpan, 3);
      expect(wide['b']!.columnSpan, 2);
      expect(narrow['a']!.columnSpan, 2);
      expect(narrow['b']!.columnSpan, 2);
      expect(narrow['b']!.row, 1);
    });

    test('non-dense leaves holes that the cursor has passed', () {
      final layout = packer.pack(
        const [
          SpanSpec(id: 'a', crossSpan: 2),
          SpanSpec(id: 'b', crossSpan: 3, mainSpan: 2),
          SpanSpec(id: 'c'),
        ],
        3,
      );

      expect(layout['a'], const CellRect(row: 0, column: 0, columnSpan: 2));
      expect(layout['b'],
          const CellRect(row: 1, column: 0, columnSpan: 3, rowSpan: 2));
      expect(layout['c'], const CellRect(row: 3, column: 0));
    });

    test('dense backfills holes', () {
      final layout = packer.pack(
        const [
          SpanSpec(id: 'a', crossSpan: 2),
          SpanSpec(id: 'b', crossSpan: 3, mainSpan: 2),
          SpanSpec(id: 'c'),
        ],
        3,
        dense: true,
      );

      expect(layout['c'], const CellRect(row: 0, column: 2));
    });

    test('supports row spans next to later items', () {
      final layout = packer.pack(
        const [
          SpanSpec(id: 'tall', mainSpan: 2),
          SpanSpec(id: 'side'),
          SpanSpec(id: 'bottom'),
        ],
        2,
      );

      expect(layout['tall'], const CellRect(row: 0, column: 0, rowSpan: 2));
      expect(layout['side'], const CellRect(row: 0, column: 1));
      expect(layout['bottom'], const CellRect(row: 1, column: 1));
    });

    test('is deterministic', () {
      final specs = _randomSpecs(Random(42), columns: 4, count: 40);
      final first = packer.pack(specs, 4);
      final second = packer.pack(specs, 4);
      expect(second, first);
    });

    test('never overlaps, stays in bounds, and is prefix independent', () {
      final random = Random(7);

      for (var round = 0; round < 200; round++) {
        final columns = 1 + random.nextInt(6);
        final count = random.nextInt(30);
        final specs = _randomSpecs(random, columns: columns, count: count);

        for (final dense in [false, true]) {
          final layout = packer.pack(specs, columns, dense: dense);
          _expectValidLayout(layout, specs, columns);

          for (final prefixLength in [0, count ~/ 2, count]) {
            final prefix = specs.take(prefixLength).toList();
            final prefixLayout = packer.pack(prefix, columns, dense: dense);
            for (final spec in prefix) {
              expect(
                prefixLayout[spec.id],
                layout[spec.id],
                reason: 'prefix $prefixLength, columns $columns, '
                    'dense $dense, id ${spec.id}',
              );
            }
          }
        }
      }
    });

    test('rejects invalid input', () {
      expect(
        () => packer.pack(const [], 0),
        throwsArgumentError,
      );
      expect(
        () => packer.pack(
          const [SpanSpec(id: 'a'), SpanSpec(id: 'a')],
          2,
        ),
        throwsArgumentError,
      );
    });
  });
}

List<SpanSpec> _randomSpecs(
  Random random, {
  required int columns,
  required int count,
}) {
  return [
    for (var i = 0; i < count; i++)
      SpanSpec(
        id: 'item-$i',
        crossSpan: 1 + random.nextInt(columns + 2),
        mainSpan: 1 + random.nextInt(3),
      ),
  ];
}

void _expectValidLayout(
  Map<Object, CellRect> layout,
  List<SpanSpec> specs,
  int columns,
) {
  expect(layout.length, specs.length);

  final rects = layout.values.toList(growable: false);
  for (var i = 0; i < rects.length; i++) {
    final rect = rects[i];
    expect(rect.row, greaterThanOrEqualTo(0));
    expect(rect.column, greaterThanOrEqualTo(0));
    expect(rect.rowSpan, greaterThanOrEqualTo(1));
    expect(rect.columnSpan, greaterThanOrEqualTo(1));
    expect(rect.columnEnd, lessThanOrEqualTo(columns));
  }

  for (var i = 0; i < rects.length; i++) {
    for (var j = i + 1; j < rects.length; j++) {
      expect(
        rects[i].overlaps(rects[j]),
        isFalse,
        reason: '${rects[i]} overlaps ${rects[j]}',
      );
    }
  }
}
