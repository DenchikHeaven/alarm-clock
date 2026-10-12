import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_clock/main.dart';

void main() {
  testWidgets('First screen shows alarm list and add button',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Підйом · Пн – Пт'), findsOneWidget);
    expect(find.text('Додати'), findsOneWidget);
  });
}
