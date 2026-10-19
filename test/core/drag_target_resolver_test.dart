import 'package:flutter_test/flutter_test.dart';
import 'package:span_grid/span_grid.dart';

void main() {
  const metrics = SpanGridCellMetrics(
    cellCrossExtent: 100,
    cellMainExtent: 100,
  );

  List<SpanSpec> grid(int count) {
    return [
      for (var i = 0; i < count; i++) SpanSpec(id: 'item-$i'),
    ];
  }

  group('SpanGridDragTargetResolver', () {
    test('finds the candidate under the pointer', () {
      const resolver = SpanGridDragTargetResolver(maxCandidates: null);

      final target = resolver.resolve(
        order: grid(6),
        columns: 3,
        draggedIndex: 0,
        pointerCross: 150,
        pointerMain: 150,
        metrics: metrics,
      );

      expect(target, 4);
    });

    test('keeps the current index without enough improvement', () {
      const resolver = SpanGridDragTargetResolver(
        maxCandidates: null,
        hysteresis: 1000,
      );

      final target = resolver.resolve(
        order: grid(6),
        columns: 3,
        draggedIndex: 0,
        pointerCross: 150,
        pointerMain: 150,
        metrics: metrics,
      );

      expect(target, 0);
    });

    test('honors the candidate window', () {
      const resolver = SpanGridDragTargetResolver(maxCandidates: 1);

      final target = resolver.resolve(
        order: grid(6),
        columns: 3,
        draggedIndex: 0,
        pointerCross: 150,
        pointerMain: 150,
        metrics: metrics,
      );

      expect(target, 1);
    });

    test('accounts for spans', () {
      const resolver = SpanGridDragTargetResolver(maxCandidates: null);

      final order = [
        const SpanSpec(id: 'wide', crossSpan: 2),
        const SpanSpec(id: 'a'),
        const SpanSpec(id: 'b'),
      ];

      final target = resolver.resolve(
        order: order,
        columns: 2,
        draggedIndex: 0,
        pointerCross: 50,
        pointerMain: 150,
        metrics: metrics,
      );

      expect(target, 1);
    });

    test('a smooth trajectory does not flip-flop', () {
      const resolver = SpanGridDragTargetResolver(
        maxCandidates: null,
        hysteresis: 30,
      );
      const columns = 3;
      final order = grid(12);
      var draggedIndex = 0;
      var changes = 0;
      int? previous;

      for (var y = 50.0; y <= 350.0; y += 1) {
        final target = resolver.resolve(
          order: _moved(order, draggedIndex),
          columns: columns,
          draggedIndex: draggedIndex,
          pointerCross: 50,
          pointerMain: y,
          metrics: metrics,
        );
        if (previous != null && target != previous) {
          changes++;
        }
        previous = target;
        draggedIndex = target;
      }

      expect(draggedIndex, 9);
      expect(changes, lessThanOrEqualTo(4));
    });

    test('supports dense packing', () {
      const resolver = SpanGridDragTargetResolver(
        maxCandidates: null,
        dense: true,
      );
      final order = [
        const SpanSpec(id: 'wide', crossSpan: 2),
        const SpanSpec(id: 'tall', crossSpan: 2, mainSpan: 2),
        const SpanSpec(id: 'a'),
        const SpanSpec(id: 'b'),
        const SpanSpec(id: 'c'),
      ];

      final target = resolver.resolve(
        order: order,
        columns: 2,
        draggedIndex: 0,
        pointerCross: 50,
        pointerMain: 250,
        metrics: metrics,
      );

      expect(target, greaterThanOrEqualTo(0));
      expect(target, lessThan(order.length));
    });

    test('rejects invalid input', () {
      const resolver = SpanGridDragTargetResolver();
      expect(
        () => resolver.resolve(
          order: const [],
          columns: 2,
          draggedIndex: 0,
          pointerCross: 0,
          pointerMain: 0,
          metrics: metrics,
        ),
        throwsArgumentError,
      );
      expect(
        () => resolver.resolve(
          order: grid(2),
          columns: 2,
          draggedIndex: 2,
          pointerCross: 0,
          pointerMain: 0,
          metrics: metrics,
        ),
        throwsRangeError,
      );
    });
  });

  group('moveSpanSpec', () {
    test('moves forward and backward', () {
      final order = grid(4);
      expect(
        moveSpanSpec(order, from: 0, to: 3).map((s) => s.id),
        ['item-1', 'item-2', 'item-3', 'item-0'],
      );
      expect(
        moveSpanSpec(order, from: 3, to: 0).map((s) => s.id),
        ['item-3', 'item-0', 'item-1', 'item-2'],
      );
      expect(moveSpanSpec(order, from: 2, to: 2), order);
    });

    test('validates indices', () {
      expect(
        () => moveSpanSpec(grid(3), from: -1, to: 1),
        throwsRangeError,
      );
      expect(
        () => moveSpanSpec(grid(3), from: 0, to: 3),
        throwsRangeError,
      );
    });
  });
}

List<SpanSpec> _moved(List<SpanSpec> order, int index) {
  final result = List<SpanSpec>.of(order);
  result.insert(index, result.removeAt(0));
  return result;
}
