import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cash_tracker/main.dart';

void main() {
  testWidgets('CashTrackerApp integration test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CashTrackerApp());

    // Verify that the total amount is initially "0.00 €".
    final totalAmountFinder = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Text &&
          widget.data == '0.00 €' &&
          widget.style?.color == Colors.tealAccent,
    );
    expect(totalAmountFinder, findsOneWidget);

    // Find the add button for the € 500 denomination.
    final addButton = find.byIcon(Icons.add_circle_outline).first;

    // Tap the add button for the € 500 denomination.
    await tester.tap(addButton);
    await tester.pump();

    // Verify that the total amount is updated to "500.00 €".
    final updatedTotalAmountFinder = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Text &&
          widget.data == '500.00 €' &&
          widget.style?.color == Colors.tealAccent,
    );
    expect(updatedTotalAmountFinder, findsOneWidget);

    // Tap the "Limpiar" button to clear all counts.
    await tester.tap(find.text('Limpiar'));
    await tester.pump();

    // Verify that the total amount is "0.00 €" again.
    expect(totalAmountFinder, findsOneWidget);
  });
}
