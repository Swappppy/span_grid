import 'package:meta/meta.dart';

/// The layout description of one item in a span grid.
///
/// A spec only carries layout information. The item's widget lives in
/// [SpanGridChild].
@immutable
class SpanSpec {
  /// Creates a span specification.
  const SpanSpec({
    required this.id,
    this.crossSpan = 1,
    this.mainSpan = 1,
  })  : assert(crossSpan >= 1, 'crossSpan must be at least one'),
        assert(mainSpan >= 1, 'mainSpan must be at least one');

  /// Identity of the item. Must be unique within a grid.
  final Object id;

  /// How many columns the item wants to occupy.
  ///
  /// Values larger than the grid's column count are clipped by
  /// [SpanGridPacker.pack].
  final int crossSpan;

  /// How many rows the item wants to occupy.
  final int mainSpan;

  @override
  bool operator ==(Object other) {
    return other is SpanSpec &&
        other.id == id &&
        other.crossSpan == crossSpan &&
        other.mainSpan == mainSpan;
  }

  @override
  int get hashCode => Object.hash(id, crossSpan, mainSpan);

  @override
  String toString() =>
      'SpanSpec(id: $id, crossSpan: $crossSpan, mainSpan: $mainSpan)';
}
