# span_grid

[![pub package](https://img.shields.io/pub/v/span_grid.svg)](https://pub.dev/packages/span_grid)

A deterministic, reorderable grid for Flutter where every child can span
multiple columns and rows.

`span_grid` lays out a list of keyed children in a fixed number of columns. The
layout is a pure function of the order and the spans, so previewing a reorder,
animating a column change, and testing the packer do not need a widget tree.

- Grid model by cells: `crossAxisCount` columns and per-child `crossSpan` /
  `mainSpan`.
- Responsive span clipping: a child wider than the grid is clipped to the
  available width.
- `dense: false` keeps CSS `grid-auto-flow: row` behavior; `dense: true`
  backfills holes like `grid-auto-flow: dense`.
- Animated layout changes, RTL support, and no reparenting: children keep their
  `State` while the order changes.
- Drag and drop with a live preview, a placeholder in the target slot,
  hysteresis against flip-flop, auto-scroll, haptics, and an exit animation for
  removed children.
- Accessibility actions to move an item earlier or later. Arrow-key reordering
  is available opt-in.
- The widget sizes itself from its layout and can live inside any scroll view.

## Status

This is `0.1.0`, published on [pub.dev](https://pub.dev/packages/span_grid).
It is compatible with the GPL-3.0 license of Openshelf; this package itself is
MIT.

## Install

```yaml
dependencies:
  span_grid: ^0.1.0
```

For local development, use a path dependency instead:

```yaml
dependencies:
  span_grid:
    path: ../span_grid
```

## Usage

```dart
import 'package:span_grid/span_grid.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final List<Stat> stats = [
    Stat('reads', 'Books read', '1,284', crossSpan: 2),
    Stat('pages', 'Pages', '312,480'),
    Stat('streak', 'Streak', '42 days'),
  ];

  @override
  Widget build(BuildContext context) {
    final byId = {for (final stat in stats) stat.id: stat};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SpanGrid(
        crossAxisCount: 4,
        spacing: 12,
        cellAspectRatio: 1.2,
        children: [
          for (final stat in stats)
            SpanGridChild(
              id: stat.id,
              crossSpan: stat.crossSpan,
              child: StatCard(stat: stat),
            ),
        ],
        onOrderChanged: (ids) {
          setState(() {
            final old = {for (final stat in stats) stat.id: stat};
            stats
              ..clear()
              ..addAll(ids.map((id) => old[id]!));
          });
        },
        onReorder: (oldIndex, newIndex) {
          // Same convention as ReorderableListView: when newIndex is greater
          // than oldIndex, the final index is newIndex - 1.
        },
      ),
    );
  }
}
```

`SpanGrid` needs a bounded width. A vertical scroll view, `SizedBox`, or
`Expanded` provides one; a horizontal scroll view does not.

### Drag behavior

- `SpanGridDragStartBehavior.delayed` (default) starts a drag after a long
  press, which keeps taps on child widgets working.
- `SpanGridDragStartBehavior.immediate` starts after the pointer moves past the
  touch slop. Prefer it for mouse input or for drag handles.
- `SpanGridDragStartBehavior.disabled` turns dragging off.

`onOrderChanged` is emitted whenever the internal order changes, including
while dragging, and receives the full list of ids. `onReorder` is emitted once,
after the drop animation, with `ReorderableListView` index semantics. A
controlled parent should rebuild `children` in the new order when it receives
`onOrderChanged`; otherwise the next external rebuild restores the order
provided by the parent.

`feedbackBuilder` wraps each tile. Its returned tree must keep the same
structure for both values of `dragging` so the child's `State` is preserved;
vary properties instead (for example, animate a scale).

### Layout

`mainAxisCellExtent` fixes the cell height. Alternatively `cellAspectRatio`
(default `1`) defines width-to-height. The grid height is
`rows * cellHeight + (rows - 1) * spacing`, plus `padding`.

### Accessibility and keyboard

Every draggable tile exposes "move earlier" and "move later" custom semantics
actions. Set `enableKeyboardReorder: true` to let arrow keys move the focused
tile; this is opt-in because it can interfere with widgets that use arrow keys.

## Design notes

The core is Flutter-free:

```dart
const packer = SpanGridPacker();
final layout = packer.pack(
  const [SpanSpec(id: 'a', crossSpan: 2), SpanSpec(id: 'b')],
  3,
);
// layout['a'] == CellRect(row: 0, column: 0, columnSpan: 2)
// layout['b'] == CellRect(row: 0, column: 2)
```

`SpanGridDragTargetResolver` evaluates hypothetical orders around the current
index, packs each one, and chooses the index whose dragged rectangle center is
closest to the pointer. `hysteresis` keeps the current index unless another one
is closer by a meaningful distance, which prevents the classic heterogeneous
grid flip-flop. `maxCandidateIndices` bounds the number of candidate packs per
pointer event.

Known limits, by design:

- No masonry / intrinsic-height mode.
- No lazy construction; all children are built. A dozen dashboard tiles is the
  intended use case. The example can load 100 and 500 tiles to make the ceiling
  measurable.
- Exit animations retain the last widget of a removed child for visual
  purposes. Its state is not kept because the parent has removed it.

## Performance

A rough pure-Dart measurement on the machine where this was developed
(Flutter 3.47, Dart 3.13):

- packing 500 single-cell items in 6 columns: ~0.1 ms;
- resolving one pointer event for those 500 items with the default +/-10
  candidate window: ~2.4 ms.

These are not a benchmark suite. The example's 12/100/500 buttons are the
manual check, and `maxCandidateIndices` is the knob if a large grid needs a
tighter frame budget.

## Development

```bash
flutter pub get
flutter analyze
flutter test
cd example && flutter pub get && flutter run
```

The example is the manual test bench: columns, dense mode, RTL, both drag start
behaviors, add/remove, local state in tiles, and 12/100/500 tile sets.

## License

MIT.
