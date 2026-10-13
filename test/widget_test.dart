import 'package:alarm_clock/models/alarm_model.dart';
import 'package:alarm_clock/services/alarm_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_clock/main.dart';

void main() {
  testWidgets('First screen shows empty state and add button',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Поки що немає будильників'), findsOneWidget);
    expect(find.text('Додати'), findsOneWidget);
  });

  group('AlarmService.occurrences', () {
    final service = AlarmService.instance;

    test('disabled alarm never rings', () {
      final a = AlarmModel(id: 1, hour: 17, minute: 30, enabled: false);
      expect(service.occurrences(a, DateTime(2026, 10, 13, 8)), isEmpty);
    });

    test('one-off alarm rings once at its scheduled moment', () {
      final at = DateTime(2026, 10, 13, 17, 30);
      final a = AlarmModel(id: 1, hour: 17, minute: 30, onceAt: at);
      expect(service.occurrences(a, DateTime(2026, 10, 13, 8)), [at]);
      // Час уже минув — спрацювань немає.
      expect(service.occurrences(a, DateTime(2026, 10, 13, 18)), isEmpty);
    });

    test('repeating alarm lists only selected weekdays', () {
      // 2026-10-13 — вівторок.
      final a = AlarmModel(
        id: 1,
        hour: 6,
        minute: 30,
        days: {DateTime.monday, DateTime.friday},
      );
      final result = service.occurrences(
        a,
        DateTime(2026, 10, 13, 8),
        windowDays: 14,
      );
      expect(result.map((d) => d.weekday).toSet(),
          {DateTime.monday, DateTime.friday});
      expect(result.first, DateTime(2026, 10, 16, 6, 30));
      expect(result.length, 4);
    });

    test("today's repeating alarm is skipped once its time has passed", () {
      final a = AlarmModel(id: 1, hour: 6, minute: 30, days: {DateTime.tuesday});
      final result = service.occurrences(
        a,
        DateTime(2026, 10, 13, 8),
        windowDays: 8,
      );
      expect(result, [DateTime(2026, 10, 20, 6, 30)]);
    });

    test('ids stay unique within the scheduling window', () {
      final start = DateTime(2026, 10, 13);
      final ids = {
        for (var i = 0; i < 14; i++)
          service.idFor(5, DateTime(start.year, start.month, start.day + i)),
      };
      expect(ids.length, 14);
      expect(ids.every((id) => id ~/ 16 == 5 && id % 16 != 15), isTrue);
    });
  });
}
