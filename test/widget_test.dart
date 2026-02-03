import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke: test harness can render a widget', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Not Alone'),
        ),
      ),
    );

    expect(find.text('Not Alone'), findsOneWidget);
  });
}
