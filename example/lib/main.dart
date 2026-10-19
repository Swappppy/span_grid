import 'package:flutter/material.dart';
import 'package:span_grid/span_grid.dart';

void main() => runApp(const SpanGridDemoApp());

class SpanGridDemoApp extends StatelessWidget {
  const SpanGridDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'span_grid demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF5B5BD6),
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final List<_DemoItem> _items = [];
  var _columns = 4;
  var _dense = false;
  var _rtl = false;
  var _immediateDrag = false;
  var _nextId = 0;

  @override
  void initState() {
    super.initState();
    _seed(12);
  }

  void _seed(int count) {
    _items.clear();
    _nextId = 0;
    for (var i = 0; i < count; i++) {
      _items.add(_createItem());
    }
  }

  _DemoItem _createItem() {
    final id = _nextId++;
    final stats = _stats[id % _stats.length];
    final wide = id % 6 == 2 && _columns > 1;
    return _DemoItem(
      id: 'item-$id',
      label: stats.$1,
      value: stats.$2,
      crossSpan: wide ? 2 : 1,
    );
  }

  int get count => _items.length;

  void _addOne() {
    setState(() => _items.add(_createItem()));
  }

  void _removeOne() {
    if (_items.isEmpty) {
      return;
    }
    setState(() => _items.removeLast());
  }

  void _setSeed(int count) {
    setState(() => _seed(count));
  }

  @override
  Widget build(BuildContext context) {
    final children = [
      for (final item in _items)
        SpanGridChild(
          id: item.id,
          crossSpan: item.crossSpan,
          child: _StatCard(item: item),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('span_grid'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '$count tiles',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Controls(
              columns: _columns,
              dense: _dense,
              rtl: _rtl,
              immediateDrag: _immediateDrag,
              onColumns: (value) => setState(() => _columns = value),
              onDense: (value) => setState(() => _dense = value),
              onRtl: (value) => setState(() => _rtl = value),
              onImmediate: (value) => setState(() => _immediateDrag = value),
              onAdd: _addOne,
              onRemove: _removeOne,
              onSeed: _setSeed,
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Directionality(
                  textDirection:
                      _rtl ? TextDirection.rtl : TextDirection.ltr,
                  child: SpanGrid(
                    children: children,
                    crossAxisCount: _columns,
                    spacing: 12,
                    cellAspectRatio: 1.15,
                    dense: _dense,
                    dragStartBehavior: _immediateDrag
                        ? SpanGridDragStartBehavior.immediate
                        : SpanGridDragStartBehavior.delayed,
                    feedbackBuilder: (context, item, child, dragging) {
                      return AnimatedScale(
                        scale: dragging ? 1.04 : 1,
                        duration: const Duration(milliseconds: 150),
                        child: Material(
                          color: Colors.transparent,
                          elevation: dragging ? 12 : 0,
                          borderRadius: BorderRadius.circular(16),
                          child: child,
                        ),
                      );
                    },
                    onOrderChanged: (ids) {
                      setState(() {
                        final current = {for (final item in _items) item.id: item};
                        _items
                          ..clear()
                          ..addAll(ids.map((id) => current[id]!));
                      });
                    },
                    onReorder: (oldIndex, newIndex) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 1),
                            content: Text(
                              'onReorder($oldIndex, $newIndex)',
                            ),
                          ),
                        );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.columns,
    required this.dense,
    required this.rtl,
    required this.immediateDrag,
    required this.onColumns,
    required this.onDense,
    required this.onRtl,
    required this.onImmediate,
    required this.onAdd,
    required this.onRemove,
    required this.onSeed,
  });

  final int columns;
  final bool dense;
  final bool rtl;
  final bool immediateDrag;
  final ValueChanged<int> onColumns;
  final ValueChanged<bool> onDense;
  final ValueChanged<bool> onRtl;
  final ValueChanged<bool> onImmediate;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final ValueChanged<int> onSeed;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Columns'),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: columns,
            onChanged: (value) {
              if (value != null) {
                onColumns(value);
              }
            },
            items: [
              for (var i = 1; i <= 6; i++)
                DropdownMenuItem(value: i, child: Text('$i')),
            ],
          ),
          const SizedBox(width: 12),
          FilterChip(
            label: const Text('Dense'),
            selected: dense,
            onSelected: onDense,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('RTL'),
            selected: rtl,
            onSelected: onRtl,
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Immediate drag'),
            selected: immediateDrag,
            onSelected: onImmediate,
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            tooltip: 'Add tile',
          ),
          IconButton.filledTonal(
            onPressed: onRemove,
            icon: const Icon(Icons.remove),
            tooltip: 'Remove last tile',
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => onSeed(12),
            child: const Text('12'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => onSeed(100),
            child: const Text('100'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => onSeed(500),
            child: const Text('500'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatefulWidget {
  const _StatCard({required this.item});

  final _DemoItem item;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  var _taps = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _taps++),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.insights, size: 18, color: colors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
              Text(
                widget.item.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                'local taps: $_taps',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoItem {
  const _DemoItem({
    required this.id,
    required this.label,
    required this.value,
    this.crossSpan = 1,
  });

  final String id;
  final String label;
  final String value;
  final int crossSpan;
}

const _stats = <(String, String)>[
  ('Books read', '1,284'),
  ('Pages', '312,480'),
  ('Streak', '42 days'),
  ('Highlights', '8,921'),
  ('Shelves', '17'),
  ('Authors', '286'),
  ('Finished', '96'),
  ('In progress', '7'),
  ('Wishlist', '53'),
];
