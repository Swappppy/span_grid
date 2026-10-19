import 'package:flutter/widgets.dart';

import 'span_spec.dart';

/// A child of a [SpanGrid], together with its layout and drag metadata.
@immutable
class SpanGridChild {
  /// Creates a grid child.
  const SpanGridChild({
    required this.id,
    required this.child,
    this.crossSpan = 1,
    this.mainSpan = 1,
    this.draggable = true,
  })  : assert(crossSpan >= 1, 'crossSpan must be at least one'),
        assert(mainSpan >= 1, 'mainSpan must be at least one');

  /// Stable identity of the child.
  ///
  /// Ids must be unique within a grid. They are also used as widget keys, so
  /// reordering keeps the child's [State] alive.
  final Object id;

  /// The widget displayed in the grid.
  final Widget child;

  /// How many columns the child wants to occupy.
  final int crossSpan;

  /// How many rows the child wants to occupy.
  final int mainSpan;

  /// Whether this child can be picked up and dragged.
  ///
  /// Non-draggable children can still be displaced by other children.
  final bool draggable;

  /// The layout spec for this child.
  SpanSpec get spec => SpanSpec(
        id: id,
        crossSpan: crossSpan,
        mainSpan: mainSpan,
      );
}
