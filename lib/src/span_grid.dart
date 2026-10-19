import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'cell_rect.dart';
import 'drag_target_resolver.dart';
import 'span_grid_child.dart';
import 'span_grid_packer.dart';
import 'span_spec.dart';

/// How a drag is started.
enum SpanGridDragStartBehavior {
  /// Dragging is disabled.
  disabled,

  /// Dragging starts after a long press. Good for touch.
  delayed,

  /// Dragging starts as soon as the pointer moves past the touch slop.
  ///
  /// Because the drag only wins the gesture arena once the pointer moves, taps
  /// on children keep working. Prefer this behavior for mouse input.
  immediate,
}

/// Builds the widget shown for an item.
///
/// [dragging] is true while the item is picked up, including the drop
/// animation. To preserve the child's state, the returned tree must keep the
/// same structure for both values of [dragging]; vary properties instead (for
/// example, animate a scale from 1 to 1.04).
typedef SpanGridFeedbackBuilder = Widget Function(
  BuildContext context,
  SpanGridChild item,
  Widget child,
  bool dragging,
);

/// Builds the placeholder shown in the slot where the dragged item will land.
typedef SpanGridPlaceholderBuilder = Widget Function(
  BuildContext context,
  SpanGridChild item,
);

/// A reorderable grid whose items can span multiple columns and rows.
///
/// The grid is a pure function of the order of [children] and of
/// [crossAxisCount]. It sizes itself to its layout, so it can live inside any
/// scroll view; it does not own a scrollable.
///
/// Children are keyed by [SpanGridChild.id]. Reordering never reparents them,
/// so their [State] is preserved.
///
/// While dragging, the order is updated internally and reported through
/// [onOrderChanged]. When the drop animation finishes, [onReorder] is called.
class SpanGrid extends StatefulWidget {
  /// Creates a span grid.
  const SpanGrid({
    super.key,
    required this.children,
    required this.crossAxisCount,
    this.mainAxisCellExtent,
    this.cellAspectRatio,
    this.spacing = 0,
    this.padding = EdgeInsets.zero,
    this.dense = false,
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.easeOutCubic,
    this.exitDuration,
    this.dragStartBehavior = SpanGridDragStartBehavior.delayed,
    this.onOrderChanged,
    this.onReorder,
    this.feedbackBuilder,
    this.placeholderBuilder,
    this.maxCandidateIndices = 10,
    this.hysteresis,
    this.autoScroll = true,
    this.autoScrollVelocityScalar = 50,
    this.enableHaptics = true,
    this.enableKeyboardReorder = false,
    this.moveEarlierSemanticsLabel = 'Move earlier',
    this.moveLaterSemanticsLabel = 'Move later',
  })  : assert(crossAxisCount >= 1, 'crossAxisCount must be at least one'),
        assert(
          mainAxisCellExtent == null || cellAspectRatio == null,
          'mainAxisCellExtent and cellAspectRatio are mutually exclusive',
        ),
        assert(
          mainAxisCellExtent == null || mainAxisCellExtent > 0,
          'mainAxisCellExtent must be positive',
        ),
        assert(
          cellAspectRatio == null || cellAspectRatio > 0,
          'cellAspectRatio must be positive',
        ),
        assert(spacing >= 0, 'spacing must be non-negative'),
        assert(
          maxCandidateIndices == null || maxCandidateIndices > 0,
          'maxCandidateIndices must be positive',
        ),
        assert(
            hysteresis == null || hysteresis >= 0, 'hysteresis must be >= 0'),
        assert(
          autoScrollVelocityScalar > 0,
          'autoScrollVelocityScalar must be positive',
        );

  /// The items, in order.
  ///
  /// Ids must be unique. When not dragging, this list is the source of truth
  /// for the order. A parent that reacts to [onOrderChanged] should rebuild
  /// this list with the new order.
  final List<SpanGridChild> children;

  /// Number of columns in the grid.
  final int crossAxisCount;

  /// Fixed height of one cell.
  ///
  /// Mutually exclusive with [cellAspectRatio]. Ignored if [cellAspectRatio] is
  /// provided.
  final double? mainAxisCellExtent;

  /// Width-to-height ratio of one cell.
  ///
  /// Defaults to 1 when [mainAxisCellExtent] is null.
  final double? cellAspectRatio;

  /// Gap between cells, in logical pixels.
  final double spacing;

  /// Padding around the grid.
  final EdgeInsetsGeometry padding;

  /// Whether holes are backfilled, like CSS `grid-auto-flow: dense`.
  final bool dense;

  /// Duration of layout changes.
  final Duration duration;

  /// Curve of layout changes.
  final Curve curve;

  /// Duration of the fade-out animation for removed children.
  ///
  /// Defaults to [duration].
  final Duration? exitDuration;

  /// How dragging starts.
  final SpanGridDragStartBehavior dragStartBehavior;

  /// Called whenever the internal order changes during or after a drag.
  ///
  /// The parent can use this to persist the new order immediately. The list is
  /// unmodifiable.
  final ValueChanged<List<Object>>? onOrderChanged;

  /// Called after the drop animation when a drag changed the order.
  ///
  /// Follows the same convention as `ReorderableListView.onReorder`: if
  /// [newIndex] is greater than [oldIndex], the item's final index is
  /// `newIndex - 1`.
  final ReorderCallback? onReorder;

  /// Wraps each child. Used to add elevation or a scale while dragging.
  final SpanGridFeedbackBuilder? feedbackBuilder;

  /// Builds the slot placeholder shown while dragging.
  final SpanGridPlaceholderBuilder? placeholderBuilder;

  /// How many candidate indices on each side of the current index are tested
  /// while dragging.
  ///
  /// `null` tests every index. The default keeps pointer handling cheap for
  /// large grids.
  final int? maxCandidateIndices;

  /// Minimum improvement, in logical pixels, required to change the target
  /// index.
  ///
  /// Defaults to 30% of the smaller cell stride. Increase it if a grid with
  /// very different spans flip-flops.
  final double? hysteresis;

  /// Whether to scroll the nearest ancestor scrollable when dragging near its
  /// edge.
  final bool autoScroll;

  /// Velocity scalar used by the auto scroller.
  final double autoScrollVelocityScalar;

  /// Whether to emit haptic feedback when picking up and changing slots.
  final bool enableHaptics;

  /// Whether arrow keys move the focused tile.
  ///
  /// This is opt-in because it can interfere with widgets that use arrow keys.
  final bool enableKeyboardReorder;

  /// Semantics label for the "move earlier" accessibility action.
  final String moveEarlierSemanticsLabel;

  /// Semantics label for the "move later" accessibility action.
  final String moveLaterSemanticsLabel;

  @override
  State<SpanGrid> createState() => _SpanGridState();
}

class _SpanGridState extends State<SpanGrid> {
  final GlobalKey _contentKey = GlobalKey();
  static final Object _placeholderKey = Object();

  late List<Object> _order;
  late Map<Object, SpanGridChild> _childrenById;
  final Map<Object, _ExitingItem> _exiting = <Object, _ExitingItem>{};
  Map<Object, Rect> _lastPixelRects = const <Object, Rect>{};

  _DragData? _drag;
  Timer? _dropTimer;
  EdgeDraggingAutoScroller? _autoScroller;

  @override
  void initState() {
    super.initState();
    _childrenById = _mapChildren(widget.children);
    _order = widget.children.map((child) => child.id).toList(growable: true);
  }

  @override
  void didUpdateWidget(SpanGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    final previousChildren = _childrenById;
    final newChildren = _mapChildren(widget.children);
    final removed = previousChildren.keys
        .where((id) => !newChildren.containsKey(id))
        .toList(growable: false);

    for (final id in removed) {
      final rect = _lastPixelRects[id];
      final item = previousChildren[id];
      final exitDuration = widget.exitDuration ?? widget.duration;
      if (rect != null && item != null && exitDuration > Duration.zero) {
        _exiting[id] = _ExitingItem(item: item, rect: rect);
      }
    }

    for (final id in newChildren.keys) {
      _exiting.remove(id);
    }

    if (_drag != null) {
      if (!newChildren.containsKey(_drag!.id)) {
        _abortDrag();
      } else {
        _order.removeWhere((id) => !newChildren.containsKey(id));
        for (final id in newChildren.keys) {
          if (!_order.contains(id)) {
            _order.add(id);
          }
        }
        _drag!.index = _order.indexOf(_drag!.id);
      }
    }
    if (_drag == null) {
      _order = widget.children.map((child) => child.id).toList(growable: true);
    }

    _childrenById = newChildren;
  }

  @override
  void dispose() {
    _dropTimer?.cancel();
    _autoScroller?.stopAutoScroll();
    super.dispose();
  }

  Map<Object, SpanGridChild> _mapChildren(List<SpanGridChild> children) {
    final result = <Object, SpanGridChild>{};
    for (final item in children) {
      if (result.containsKey(item.id)) {
        throw ArgumentError.value(
          item.id,
          'children',
          'contains the same id more than once',
        );
      }
      if (item.crossSpan < 1 || item.mainSpan < 1) {
        throw ArgumentError.value(
          item.id,
          'children',
          'spans must be at least one',
        );
      }
      result[item.id] = item;
    }
    return result;
  }

  SpanGridPacker get _packer => const SpanGridPacker();

  List<SpanSpec> get _specs => <SpanSpec>[
        for (final id in _order)
          if (_childrenById[id] case final item?) item.spec,
      ];

  Map<Object, CellRect> _pack() {
    return _packer.pack(
      _specs,
      widget.crossAxisCount,
      dense: widget.dense,
    );
  }

  _CellGeometry _geometry(double contentWidth) {
    final columns = widget.crossAxisCount;
    final gap = widget.spacing;
    final available = contentWidth - gap * (columns - 1);
    final cellWidth = math.max(0.0, available / columns);
    final cellHeight =
        widget.mainAxisCellExtent ?? cellWidth / (widget.cellAspectRatio ?? 1);
    return _CellGeometry(
      contentWidth: contentWidth,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      gap: gap,
    );
  }

  Rect _pixelRect(CellRect rect, _CellGeometry geometry, bool rtl) {
    final left = rect.column * (geometry.cellWidth + geometry.gap);
    final top = rect.row * (geometry.cellHeight + geometry.gap);
    final width = rect.columnSpan * geometry.cellWidth +
        (rect.columnSpan - 1) * geometry.gap;
    final height =
        rect.rowSpan * geometry.cellHeight + (rect.rowSpan - 1) * geometry.gap;
    if (rtl) {
      return Rect.fromLTWH(
        geometry.contentWidth - left - width,
        top,
        width,
        height,
      );
    }
    return Rect.fromLTWH(left, top, width, height);
  }

  SpanGridCellMetrics _metrics(_CellGeometry geometry) {
    return SpanGridCellMetrics(
      cellCrossExtent: geometry.cellWidth,
      cellMainExtent: geometry.cellHeight,
      crossGap: geometry.gap,
      mainGap: geometry.gap,
    );
  }

  RenderBox? get _contentBox {
    final context = _contentKey.currentContext;
    if (context == null) {
      return null;
    }
    return context.findRenderObject() as RenderBox?;
  }

  bool get _isRtl => Directionality.of(context) == TextDirection.rtl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedWidth,
          'SpanGrid needs a bounded width. Put it inside a SizedBox, Expanded, '
          'or a vertical scroll view.',
        );
        final contentWidth =
            constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
        final innerWidth =
            math.max(0.0, contentWidth - widget.padding.horizontal);
        final geometry = _geometry(innerWidth);
        final layout = _pack();
        final rtl = _isRtl;
        final pixelRects = <Object, Rect>{
          for (final entry in layout.entries)
            entry.key: _pixelRect(entry.value, geometry, rtl),
        };
        _lastPixelRects = pixelRects;

        var rows = 0;
        for (final rect in layout.values) {
          rows = math.max(rows, rect.rowEnd);
        }
        final height = rows == 0
            ? 0.0
            : rows * geometry.cellHeight + (rows - 1) * geometry.gap;

        final items = <SpanGridChild>[
          for (final id in _order)
            if (_childrenById[id] case final item?) item,
        ];
        final drag = _drag;
        final stackChildren = <Widget>[];

        for (final entry in _exiting.values) {
          stackChildren.add(_buildExitingItem(entry));
        }

        if (drag != null) {
          final slot = pixelRects[drag.id];
          final item = _childrenById[drag.id];
          if (slot != null && item != null) {
            final placeholder =
                widget.placeholderBuilder?.call(context, item) ??
                    _DefaultPlaceholder(item: item);
            stackChildren.add(
              AnimatedPositioned(
                key: ValueKey<Object>(_placeholderKey),
                duration: widget.duration,
                curve: widget.curve,
                left: slot.left,
                top: slot.top,
                width: slot.width,
                height: slot.height,
                child: IgnorePointer(child: placeholder),
              ),
            );
          }
        }

        if (drag != null) {
          final index = items.indexWhere((item) => item.id == drag.id);
          if (index != -1) {
            items.add(items.removeAt(index));
          }
        }

        final duration = widget.duration;
        for (final item in items) {
          final rect = pixelRects[item.id];
          if (rect == null) {
            continue;
          }
          final dragged = drag?.id == item.id ? drag : null;
          final isDragged = dragged != null;
          final settling = dragged?.settling ?? false;
          final visualRect =
              dragged != null && !settling ? _draggedRect(dragged, rect) : rect;
          stackChildren.add(
            AnimatedPositioned(
              key: ValueKey<Object>(item.id),
              duration: isDragged && !settling ? Duration.zero : duration,
              curve: widget.curve,
              left: visualRect.left,
              top: visualRect.top,
              width: visualRect.width,
              height: visualRect.height,
              onEnd: settling ? _completeDrop : null,
              child: _buildItem(item, isDragged),
            ),
          );
        }

        return Padding(
          padding: widget.padding,
          child: AnimatedSize(
            duration: duration,
            curve: widget.curve,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            child: SizedBox(
              key: _contentKey,
              width: innerWidth,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: stackChildren,
              ),
            ),
          ),
        );
      },
    );
  }

  Rect _draggedRect(_DragData drag, Rect slot) {
    return Rect.fromLTWH(
      drag.pointerLocal.dx - drag.grabOffset.dx,
      drag.pointerLocal.dy - drag.grabOffset.dy,
      slot.width,
      slot.height,
    );
  }

  Widget _buildItem(SpanGridChild item, bool dragging) {
    final feedback = widget.feedbackBuilder ?? _defaultFeedback;
    Widget result = _SpanGridDragDetector(
      behavior: widget.dragStartBehavior,
      enabled: item.draggable,
      onStart: (position) => _startDrag(item.id, position),
      onUpdate: _updateDragPosition,
      onEnd: _endDrag,
      onCancel: _endDrag,
      child: RepaintBoundary(
        child: feedback(context, item, item.child, dragging),
      ),
    );

    if (widget.enableKeyboardReorder && item.draggable) {
      result = Focus(
        canRequestFocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) {
            return KeyEventResult.ignored;
          }
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.arrowUp) {
            _moveItem(item.id, -1);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight ||
              key == LogicalKeyboardKey.arrowDown) {
            _moveItem(item.id, 1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: result,
      );
    }

    return Semantics(
      container: true,
      customSemanticsActions: item.draggable
          ? <CustomSemanticsAction, VoidCallback>{
              CustomSemanticsAction(
                label: widget.moveEarlierSemanticsLabel,
              ): () => _moveItem(item.id, -1),
              CustomSemanticsAction(
                label: widget.moveLaterSemanticsLabel,
              ): () => _moveItem(item.id, 1),
            }
          : null,
      child: result,
    );
  }

  Widget _buildExitingItem(_ExitingItem entry) {
    final exitDuration = widget.exitDuration ?? widget.duration;
    return Positioned(
      key: ValueKey<Object>(entry.token),
      left: entry.rect.left,
      top: entry.rect.top,
      width: entry.rect.width,
      height: entry.rect.height,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 1, end: 0),
            duration: exitDuration,
            curve: widget.curve,
            onEnd: () => _removeExiting(entry),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.96 + 0.04 * value,
                  child: child,
                ),
              );
            },
            child: RepaintBoundary(child: entry.item.child),
          ),
        ),
      ),
    );
  }

  void _removeExiting(_ExitingItem entry) {
    final current = _exiting[entry.item.id];
    if (current == null || !identical(current, entry)) {
      return;
    }
    setState(() {
      _exiting.remove(entry.item.id);
    });
  }

  void _startDrag(Object id, Offset globalPosition) {
    if (!mounted) {
      return;
    }
    final current = _drag;
    if (current != null) {
      if (!current.settling) {
        return;
      }
      _completeDrop();
    }
    final item = _childrenById[id];
    final box = _contentBox;
    final rect = _lastPixelRects[id];
    if (item == null || !item.draggable || box == null || rect == null) {
      return;
    }
    final index = _order.indexOf(id);
    if (index == -1) {
      return;
    }

    final local = box.globalToLocal(globalPosition);
    final drag = _DragData(
      id: id,
      startIndex: index,
      index: index,
      grabOffset: Offset(local.dx - rect.left, local.dy - rect.top),
      pointerLocal: local,
      pointerGlobal: globalPosition,
    );

    _dropTimer?.cancel();
    _autoScroller?.stopAutoScroll();
    _autoScroller = null;
    if (widget.autoScroll) {
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable != null) {
        _autoScroller = EdgeDraggingAutoScroller(
          scrollable,
          onScrollViewScrolled: _handleAutoScroll,
          velocityScalar: widget.autoScrollVelocityScalar,
        );
      }
    }

    setState(() {
      _drag = drag;
    });
    if (widget.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
    final targetRect = _globalDragRect(drag);
    if (targetRect != null) {
      _startAutoScroll(targetRect);
    }
  }

  void _startAutoScroll(Rect targetRect) {
    final scroller = _autoScroller;
    if (scroller == null) {
      return;
    }
    final box = scroller.scrollable.context.findRenderObject() as RenderBox?;
    if (box != null &&
        (targetRect.width > box.size.width ||
            targetRect.height > box.size.height)) {
      return;
    }
    scroller.startAutoScrollIfNecessary(targetRect);
  }

  void _updateDragPosition(Offset globalPosition) {
    _updateDrag(globalPosition, autoScroll: true);
  }

  void _updateDrag(Offset globalPosition, {required bool autoScroll}) {
    final drag = _drag;
    if (drag == null || drag.settling) {
      return;
    }
    final box = _contentBox;
    if (box == null) {
      return;
    }

    final local = box.globalToLocal(globalPosition);
    final width = box.size.width;
    final geometry = _geometry(width);
    final layout = _pack();
    final rtl = _isRtl;
    final pointerCross = rtl ? width - local.dx : local.dx;
    final metrics = _metrics(geometry);
    final hysteresis = widget.hysteresis ??
        0.3 * math.min(geometry.cellWidth, geometry.cellHeight);

    final target = SpanGridDragTargetResolver(
      dense: widget.dense,
      maxCandidates: widget.maxCandidateIndices,
      hysteresis: hysteresis,
    ).resolve(
      order: _specs,
      columns: widget.crossAxisCount,
      draggedIndex: drag.index,
      pointerCross: pointerCross,
      pointerMain: local.dy,
      metrics: metrics,
      currentLayout: layout,
    );

    final changed = target != drag.index;
    setState(() {
      if (local != drag.pointerLocal) {
        drag.moved = true;
      }
      drag.pointerLocal = local;
      drag.pointerGlobal = globalPosition;
      if (changed) {
        final spec = _order.removeAt(drag.index);
        _order.insert(target, spec);
        drag.index = target;
      }
    });

    if (changed) {
      _emitOrderChanged();
      if (widget.enableHaptics) {
        HapticFeedback.selectionClick();
      }
    }

    if (autoScroll) {
      final targetRect = _globalDragRect(drag);
      if (targetRect != null) {
        _startAutoScroll(targetRect);
      }
    }
  }

  Rect? _globalDragRect(_DragData drag) {
    final box = _contentBox;
    final slot = _lastPixelRects[drag.id];
    if (box == null || slot == null) {
      return null;
    }
    final local = _draggedRect(drag, slot);
    return box.localToGlobal(local.topLeft) & local.size;
  }

  void _handleAutoScroll() {
    final drag = _drag;
    if (drag == null || drag.settling) {
      return;
    }
    _updateDrag(drag.pointerGlobal, autoScroll: false);
    final targetRect = _globalDragRect(drag);
    if (targetRect != null) {
      _startAutoScroll(targetRect);
    }
  }

  void _endDrag() {
    final drag = _drag;
    if (drag == null || drag.settling) {
      return;
    }
    _autoScroller?.stopAutoScroll();
    _autoScroller = null;
    if (!drag.moved) {
      _completeDrop();
      return;
    }
    setState(() {
      drag.settling = true;
    });
    _dropTimer?.cancel();
    _dropTimer = Timer(
      widget.duration + const Duration(milliseconds: 32),
      _completeDrop,
    );
  }

  void _completeDrop() {
    _dropTimer?.cancel();
    _dropTimer = null;
    final drag = _drag;
    if (drag == null) {
      return;
    }
    final oldIndex = drag.startIndex;
    final newIndex = _order.indexOf(drag.id);
    setState(() {
      _drag = null;
    });
    if (newIndex != -1 && newIndex != oldIndex) {
      widget.onReorder?.call(
        oldIndex,
        newIndex > oldIndex ? newIndex + 1 : newIndex,
      );
    }
  }

  void _abortDrag() {
    _dropTimer?.cancel();
    _dropTimer = null;
    _autoScroller?.stopAutoScroll();
    _autoScroller = null;
    _drag = null;
  }

  void _moveItem(Object id, int delta) {
    if (_drag != null) {
      return;
    }
    final index = _order.indexOf(id);
    if (index == -1) {
      return;
    }
    final target = (index + delta).clamp(0, _order.length - 1);
    if (target == index) {
      return;
    }
    setState(() {
      final moved = _order.removeAt(index);
      _order.insert(target, moved);
    });
    _emitOrderChanged();
    widget.onReorder?.call(index, target > index ? target + 1 : target);
    if (widget.enableHaptics) {
      HapticFeedback.selectionClick();
    }
  }

  void _emitOrderChanged() {
    final callback = widget.onOrderChanged;
    if (callback != null) {
      callback(List<Object>.unmodifiable(_order));
    }
  }
}

Widget _defaultFeedback(
  BuildContext context,
  SpanGridChild item,
  Widget child,
  bool dragging,
) {
  return Transform.scale(
    scale: dragging ? 1.03 : 1.0,
    child: child,
  );
}

class _DefaultPlaceholder extends StatelessWidget {
  const _DefaultPlaceholder({required this.item});

  final SpanGridChild item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
      ),
    );
  }
}

class _CellGeometry {
  const _CellGeometry({
    required this.contentWidth,
    required this.cellWidth,
    required this.cellHeight,
    required this.gap,
  });

  final double contentWidth;
  final double cellWidth;
  final double cellHeight;
  final double gap;
}

class _DragData {
  _DragData({
    required this.id,
    required this.startIndex,
    required this.index,
    required this.grabOffset,
    required this.pointerLocal,
    required this.pointerGlobal,
  });

  final Object id;
  final int startIndex;
  final Offset grabOffset;
  int index;
  Offset pointerLocal;
  Offset pointerGlobal;
  bool moved = false;
  bool settling = false;
}

class _ExitingItem {
  _ExitingItem({required this.item, required this.rect});

  final SpanGridChild item;
  final Rect rect;
  final Object token = Object();
}

class _SpanGridDragDetector extends StatelessWidget {
  const _SpanGridDragDetector({
    required this.behavior,
    required this.enabled,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
    required this.child,
  });

  final SpanGridDragStartBehavior behavior;
  final bool enabled;
  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled || behavior == SpanGridDragStartBehavior.disabled) {
      return child;
    }

    final Map<Type, GestureRecognizerFactory> gestures;
    if (behavior == SpanGridDragStartBehavior.delayed) {
      gestures = <Type, GestureRecognizerFactory>{
        DelayedMultiDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            DelayedMultiDragGestureRecognizer>(
          () => DelayedMultiDragGestureRecognizer(
            delay: kLongPressTimeout,
            debugOwner: this,
          ),
          (recognizer) {
            recognizer.onStart = _handleStart;
          },
        ),
      };
    } else {
      gestures = <Type, GestureRecognizerFactory>{
        ImmediateMultiDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
                ImmediateMultiDragGestureRecognizer>(
          () => ImmediateMultiDragGestureRecognizer(debugOwner: this),
          (recognizer) {
            recognizer.onStart = _handleStart;
          },
        ),
      };
    }

    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: gestures,
      child: child,
    );
  }

  Drag _handleStart(Offset position) {
    onStart(position);
    return _GridDrag(
      initialPosition: position,
      onUpdate: onUpdate,
      onEnd: onEnd,
      onCancel: onCancel,
    );
  }
}

class _GridDrag extends Drag {
  _GridDrag({
    required Offset initialPosition,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  }) : _position = initialPosition;

  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;
  Offset _position;

  @override
  void update(DragUpdateDetails details) {
    // The first update sent by MultiDragGestureRecognizer carries the slop
    // distance in `delta` and the original press position in
    // `globalPosition`; accumulate deltas so that movement is never lost.
    _position += details.delta;
    onUpdate(_position);
  }

  @override
  void end(DragEndDetails details) {
    onEnd();
  }

  @override
  void cancel() {
    onCancel();
  }
}
