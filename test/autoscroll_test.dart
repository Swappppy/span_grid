import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:span_grid/span_grid.dart';

void main() {
  testWidgets('auto-scrolls the nearest scrollable while dragging',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: controller,
            children: [
              const SizedBox(height: 20),
              SpanGrid(
                crossAxisCount: 2,
                mainAxisCellExtent: 100,
                children: [
                  for (var i = 0; i < 30; i++)
                    SpanGridChild(
                      id: 'i$i',
                      child: Center(child: Text('i$i')),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, 0);

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('i8')));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(const Offset(400, 590));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.offset, greaterThan(0));

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
