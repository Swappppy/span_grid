import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'cell_rect.dart';
import 'span_grid_packer.dart';
import 'span_spec.dart';

/// Physical size of a grid cell, used to turn [CellRect]s into distances.
@immutable
class SpanGridCellMetrics {
  /// Creates cell metrics.
  const SpanGridCellMetrics({
    required this.cellCrossExtent,
    required this.cellMainExtent,
    this.crossGap = 0,
    this.mainGap = 0,
  })  : assert(cellCrossExtent >= 0),
        assert(cellMainExtent >= 0),
        assert(crossGap >= 0),
        assert(mainGap >= 0);

  /// Width of one cell.
  final double cellCrossExtent;

  /// Height of one cell.
  final double cellMainExtent;

  /// Gap between columns.
  final double crossGap;

  /// Gap between rows.
  final double mainGap;

  /// Distance between the starts of two adjacent columns.
  double get crossStride => cellCrossExtent + crossGap;

  /// Distance between the starts of two adjacent rows.
  double get mainStride => cellMainExtent + mainGap;

  /// Horizontal center of [rect], in the same coordinate space as
  /// [SpanGridDragTargetResolver.resolve]'s pointers.
  double crossCenter(CellRect rect) {
    final extent =
        rect.columnSpan * cellCrossExtent + (rect.columnSpan - 1) * crossGap;
    return rect.column * crossStride + extent / 2;
  }

  /// Vertical center of [rect].
  double mainCenter(CellRect rect) {
    final extent = rect.rowSpan * cellMainExtent + (rect.rowSpan - 1) * mainGap;
    return rect.row * mainStride + extent / 2;
  }
}

/// Chooses where a dragged item should be inserted.
///
/// Rather than guessing from the pointer's cell, the resolver evaluates
/// hypothetical orders: it moves the dragged item to each candidate index,
/// packs the result, and measures the distance between the pointer and the
/// center of the dragged item's resulting rectangle. The closest candidate
/// wins.
///
/// [hysteresis] is a distance in the same units as the pointer (normally
/// logical pixels). The current index is kept unless another candidate is
/// closer by more than this amount. This prevents the common flip-flop where
/// moving a tile changes the layout under the pointer and immediately undoes
/// the move.
class SpanGridDragTargetResolver {
  /// Creates a resolver.
  const SpanGridDragTargetResolver({
    this.dense = false,
    this.maxCandidates = 10,
    this.hysteresis = 0,
  }) : assert(maxCandidates == null || maxCandidates > 0);

  /// Whether hypothetical layouts are packed densely.
  final bool dense;

  /// How many indices on each side of the current index are evaluated.
  ///
  /// `null` evaluates every index. Evaluating a window keeps pointer handling
  /// cheap for large grids; the window is wide enough for normal drags because
  /// pointer events arrive continuously.
  final int? maxCandidates;

  /// Minimum distance improvement required to leave the current index.
  final double hysteresis;

  /// Returns the index where the dragged item should be inserted.
  ///
  /// [order] contains the dragged item at [draggedIndex]. [pointerCross] and
  /// [pointerMain] are in local grid coordinates: `0, 0` is the top-left
  /// corner of the first cell. [metrics] converts cell rectangles to the same
  /// coordinate space.
  ///
  /// Passing [currentLayout] avoids one pack operation; it must be the layout
  /// of [order]. It is only an optimization.
  int resolve({
    required List<SpanSpec> order,
    required int columns,
    required int draggedIndex,
    required double pointerCross,
    required double pointerMain,
    required SpanGridCellMetrics metrics,
    Map<Object, CellRect>? currentLayout,
  }) {
    if (order.isEmpty) {
      throw ArgumentError.value(order, 'order', 'must not be empty');
    }
    if (draggedIndex < 0 || draggedIndex >= order.length) {
      throw RangeError.index(draggedIndex, order, 'draggedIndex');
    }

    final current = draggedIndex;
    final count = order.length;
    final distances = <int, double>{};

    double distanceAt(int index) {
      final cached = distances[index];
      if (cached != null) {
        return cached;
      }

      final Map<Object, CellRect> layout;
      if (index == current && currentLayout != null) {
        layout = currentLayout;
      } else {
        layout = const SpanGridPacker().pack(
          moveSpanSpec(order, from: current, to: index),
          columns,
          dense: dense,
        );
      }
      final rect = layout[order[current].id];
      if (rect == null) {
        throw StateError('The dragged item is missing from the layout.');
      }
      final dx = metrics.crossCenter(rect) - pointerCross;
      final dy = metrics.mainCenter(rect) - pointerMain;
      final result = math.sqrt(dx * dx + dy * dy);
      distances[index] = result;
      return result;
    }

    final currentDistance = distanceAt(current);
    var bestIndex = current;
    var bestDistance = currentDistance;

    for (final candidate in _candidates(count, current)) {
      if (candidate == current) {
        continue;
      }
      final candidateDistance = distanceAt(candidate);
      if (candidateDistance < bestDistance) {
        bestDistance = candidateDistance;
        bestIndex = candidate;
      }
    }

    if (bestIndex == current) {
      return current;
    }
    if (currentDistance - bestDistance <= hysteresis) {
      return current;
    }
    return bestIndex;
  }

  Iterable<int> _candidates(int count, int current) sync* {
    final window = maxCandidates;
    if (window == null || window >= count) {
      for (var i = 0; i < count; i++) {
        yield i;
      }
      return;
    }
    final first = math.max(0, current - window);
    final last = math.min(count - 1, current + window);
    for (var i = first; i <= last; i++) {
      yield i;
    }
  }
}

/// Returns a copy of [order] with the item at [from] inserted at [to].
///
/// [to] is the final index in the returned list, in `0..order.length - 1`.
List<SpanSpec> moveSpanSpec(
  List<SpanSpec> order, {
  required int from,
  required int to,
}) {
  if (from < 0 || from >= order.length) {
    throw RangeError.index(from, order, 'from');
  }
  if (to < 0 || to >= order.length) {
    throw RangeError.index(to, order, 'to');
  }
  if (from == to) {
    return List<SpanSpec>.of(order);
  }
  final result = List<SpanSpec>.of(order);
  final spec = result.removeAt(from);
  result.insert(to, spec);
  return result;
}
