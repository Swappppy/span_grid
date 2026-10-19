import 'package:flutter_test/flutter_test.dart';
import 'package:span_grid/span_grid.dart';
import 'package:span_grid_example/main.dart';

void main() {
  testWidgets('demo renders a span grid', (tester) async {
    await tester.pumpWidget(const SpanGridDemoApp());
    await tester.pumpAndSettle();

    expect(find.byType(SpanGrid), findsOneWidget);
    expect(find.text('Books read'), findsWidgets);
  });
}
