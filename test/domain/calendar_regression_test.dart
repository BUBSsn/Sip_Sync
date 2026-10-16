import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_store/domain/domain.dart';

// Also run under TZ=America/New_York to exercise 23/25-hour local days.
void main() {
  for (final days in [
    [DateTime(2026, 3, 7), DateTime(2026, 3, 8), DateTime(2026, 3, 9)],
    [DateTime(2026, 10, 31), DateTime(2026, 11, 1), DateTime(2026, 11, 2)],
  ]) {
    test(
      'three consecutive calendar days keep their streak: ${days.first}',
      () {
        final summaries = days
            .map((day) => DailySummary(date: day, totalMl: 2000, goalMl: 2000))
            .toList();
        final streak = calculateStreaks(summaries, today: days.last);
        expect(streak.currentStreak, 3);
        expect(streak.bestStreak, 3);
        final nextDay = DateTime(
          days.last.year,
          days.last.month,
          days.last.day + 1,
        );
        expect(calculateStreaks(summaries, today: nextDay).currentStreak, 3);
      },
    );
  }
}
