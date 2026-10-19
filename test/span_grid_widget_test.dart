import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:span_grid/span_grid.dart';

void main() {
  List<SpanGridChild> items({int count = 6}) {
    return [
      for (var i = 0; i < count; i++)
        SpanGridChild(
          id: 'item-$i',
          child: Center(
            child: Text(
              'item-$i',
              key: ValueKey<String>('text-item-$i'),
            ),
          ),
        ),
    ];
  }

  Widget app({
    required List<SpanGridChild> children,
    int columns = 3,
    double width = 300,
    TextDirection textDirection = TextDirection.ltr,
    bool dense = false,
    ValueChanged<List<Object>>? onOrderChanged,
    ReorderCallback? onReorder,
    Duration duration = const Duration(milliseconds: 200),
  }) {
    return MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: SpanGrid(
                children: children,
                crossAxisCount: columns,
                dense: dense,
                duration: duration,
                onOrderChanged: onOrderChanged,
                onReorder: onReorder,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset centerOf(WidgetTester tester, String id) {
    final gridOrigin = tester.getTopLeft(find.byType(SpanGrid));
    return tester.getCenter(find.byKey(ValueKey<String>('text-$id'))) -
        gridOrigin;
  }

  testWidgets('lays out spans and exposes the layout height', (tester) async {
    await tester.pumpWidget(
      app(
        children: [
          SpanGridChild(
            id: 'a',
            child: Center(
              child: Text('a', key: const ValueKey<String>('text-a')),
            ),
          ),
          SpanGridChild(
            id: 'b',
            crossSpan: 2,
            child: Center(
              child: Text('b', key: const ValueKey<String>('text-b')),
            ),
          ),
          SpanGridChild(
            id: 'c',
            mainSpan: 2,
            child: Center(
              child: Text('c', key: const ValueKey<String>('text-c')),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(SpanGrid)), const Size(300, 300));
    expect(centerOf(tester, 'a'), const Offset(50, 50));
    expect(centerOf(tester, 'b'), const Offset(200, 50));
    expect(centerOf(tester, 'c'), const Offset(50, 200));
  });

  testWidgets('lays out 1x1, 2x1, 1x2 and 2x2 items', (tester) async {
    await tester.pumpWidget(
      app(
        columns: 4,
        children: [
          SpanGridChild(
            id: 'one',
            child: Center(
              child: Text('one', key: const ValueKey<String>('text-one')),
            ),
          ),
          SpanGridChild(
            id: 'wide',
            crossSpan: 2,
            child: Center(
              child: Text('wide', key: const ValueKey<String>('text-wide')),
            ),
          ),
          SpanGridChild(
            id: 'big',
            crossSpan: 2,
            mainSpan: 2,
            child: Center(
              child: Text('big', key: const ValueKey<String>('text-big')),
            ),
          ),
          SpanGridChild(
            id: 'tall',
            mainSpan: 2,
            child: Center(
              child: Text('tall', key: const ValueKey<String>('text-tall')),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(SpanGrid)), const Size(300, 225));
    expect(centerOf(tester, 'one'), const Offset(37.5, 37.5));
    expect(centerOf(tester, 'wide'), const Offset(150, 37.5));
    expect(centerOf(tester, 'big'), const Offset(75, 150));
    expect(centerOf(tester, 'tall'), const Offset(187.5, 150));
  });

  testWidgets('mirrors columns in RTL', (tester) async {
    await tester.pumpWidget(
      app(
        textDirection: TextDirection.rtl,
        children: [
          SpanGridChild(
            id: 'a',
            child: Center(
              child: Text('a', key: const ValueKey<String>('text-a')),
            ),
          ),
          SpanGridChild(
            id: 'b',
            crossSpan: 2,
            child: Center(
              child: Text('b', key: const ValueKey<String>('text-b')),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(centerOf(tester, 'a'), const Offset(250, 50));
    expect(centerOf(tester, 'b'), const Offset(100, 50));
  });

  testWidgets('preserves child state when the order changes', (tester) async {
    final first = SpanGridChild(
        id: 'a',
        child: const _Counter(key: ValueKey<String>('counter-a'), label: 'a'));
    final second = SpanGridChild(
        id: 'b',
        child: const _Counter(key: ValueKey<String>('counter-b'), label: 'b'));

    await tester.pumpWidget(app(children: [first, second]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('counter-a')));
    await tester.pump();

    expect(find.text('a:1'), findsOneWidget);
    expect(centerOf(tester, 'a'), const Offset(50, 50));

    await tester.pumpWidget(app(children: [second, first]));
    await tester.pumpAndSettle();

    expect(find.text('a:1'), findsOneWidget);
    expect(centerOf(tester, 'a'), const Offset(150, 50));
  });

  testWidgets('reorders with a long press drag', (tester) async {
    List<Object>? changed;
    (int, int)? reordered;
    await tester.pumpWidget(
      app(
        children: items(),
        onOrderChanged: (order) => changed = order,
        onReorder: (oldIndex, newIndex) => reordered = (oldIndex, newIndex),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey<String>('text-item-0'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
        changed, ['item-1', 'item-2', 'item-3', 'item-0', 'item-4', 'item-5']);
    expect(reordered, (0, 4));
    expect(centerOf(tester, 'item-0'), const Offset(50, 150));
  });

  testWidgets('preserves child state while dragging', (tester) async {
    final a = SpanGridChild(
      id: 'a',
      child: const _Counter(key: ValueKey<String>('counter-a'), label: 'a'),
    );
    final b = SpanGridChild(
      id: 'b',
      child: const _Counter(key: ValueKey<String>('counter-b'), label: 'b'),
    );

    await tester.pumpWidget(app(children: [a, b]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('counter-a')));
    await tester.pump();
    expect(find.text('a:1'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey<String>('text-a'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(find.text('a:1'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('a:1'), findsOneWidget);
  });

  testWidgets('supports a controlled parent', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _ControlledHost()));
    await tester.pumpAndSettle();

    expect(centerOf(tester, 'a'), const Offset(75, 75));
    expect(centerOf(tester, 'b'), const Offset(225, 75));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey<String>('text-a'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(centerOf(tester, 'a'), const Offset(225, 75));
    expect(find.text('order: b,a'), findsOneWidget);
  });

  testWidgets('immediate drag keeps child taps working', (tester) async {
    var taps = 0;
    (int, int)? reordered;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: SpanGrid(
                crossAxisCount: 2,
                mainAxisCellExtent: 100,
                dragStartBehavior: SpanGridDragStartBehavior.immediate,
                onReorder: (oldIndex, newIndex) {
                  reordered = (oldIndex, newIndex);
                },
                children: [
                  SpanGridChild(
                    id: 'a',
                    child: GestureDetector(
                      onTap: () => taps++,
                      child: Center(
                        child: Text(
                          'a',
                          key: const ValueKey<String>('text-a'),
                        ),
                      ),
                    ),
                  ),
                  SpanGridChild(
                    id: 'b',
                    child: Center(
                      child: Text(
                        'b',
                        key: const ValueKey<String>('text-b'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('text-a')));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(reordered, isNull);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey<String>('text-a'))),
    );
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(reordered, (0, 2));
  });

  testWidgets('retains removed children until their exit animation ends',
      (tester) async {
    final a = SpanGridChild(
      id: 'a',
      child: const Text('a', key: ValueKey<String>('text-a')),
    );
    final b = SpanGridChild(
      id: 'b',
      child: const Text('b', key: ValueKey<String>('text-b')),
    );

    await tester.pumpWidget(app(children: [a, b]));
    await tester.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);

    await tester.pumpWidget(app(children: [b]));
    await tester.pump();
    expect(find.text('a'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('a'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('a'), findsNothing);
  });

  testWidgets('applies padding around the content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            child: SpanGrid(
              padding: const EdgeInsets.all(10),
              spacing: 10,
              crossAxisCount: 2,
              children: [
                SpanGridChild(
                  id: 'a',
                  child: Center(
                    child: Text('a', key: const ValueKey<String>('text-a')),
                  ),
                ),
                SpanGridChild(
                  id: 'b',
                  child: Center(
                    child: Text('b', key: const ValueKey<String>('text-b')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(SpanGrid)), const Size(300, 155));
    final origin = tester.getTopLeft(find.byType(SpanGrid));
    final a =
        tester.getCenter(find.byKey(const ValueKey<String>('text-a'))) - origin;
    final b =
        tester.getCenter(find.byKey(const ValueKey<String>('text-b'))) - origin;
    expect(a, const Offset(10 + 67.5, 10 + 67.5));
    expect(b, const Offset(10 + 145 + 67.5, 10 + 67.5));
  });

  testWidgets('moves items with accessibility actions', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        columns: 2,
        children: [
          SpanGridChild(
            id: 'a',
            child: Center(
              child: Text('a', key: const ValueKey<String>('text-a')),
            ),
          ),
          SpanGridChild(
            id: 'b',
            child: Center(
              child: Text('b', key: const ValueKey<String>('text-b')),
            ),
          ),
          SpanGridChild(
            id: 'c',
            child: Center(
              child: Text('c', key: const ValueKey<String>('text-c')),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(centerOf(tester, 'a'), const Offset(75, 75));
    expect(
      tester.getSemantics(find.text('a')),
      matchesSemantics(
        label: 'a',
        hasTapAction: false,
        customActions: const <CustomSemanticsAction>[
          CustomSemanticsAction(label: 'Move earlier'),
          CustomSemanticsAction(label: 'Move later'),
        ],
      ),
    );
    handle.dispose();
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key, required this.label});

  final String label;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int value = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => value++),
      child: Center(
        child: Text(
          '${widget.label}:$value',
          key: ValueKey<String>('text-${widget.label}'),
        ),
      ),
    );
  }
}

class _ControlledHost extends StatefulWidget {
  const _ControlledHost();

  @override
  State<_ControlledHost> createState() => _ControlledHostState();
}

class _ControlledHostState extends State<_ControlledHost> {
  List<String> order = ['a', 'b'];

  @override
  Widget build(BuildContext context) {
    final byId = <String, SpanGridChild>{
      'a': SpanGridChild(
        id: 'a',
        child: Center(
          child: Text('a', key: const ValueKey<String>('text-a')),
        ),
      ),
      'b': SpanGridChild(
        id: 'b',
        child: Center(
          child: Text('b', key: const ValueKey<String>('text-b')),
        ),
      ),
    };
    return Scaffold(
      body: Column(
        children: [
          Text('order: ${order.join(',')}'),
          SizedBox(
            width: 300,
            child: SpanGrid(
              crossAxisCount: 2,
              children: [for (final id in order) byId[id]!],
              onOrderChanged: (ids) {
                setState(() {
                  order = ids.cast<String>();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
