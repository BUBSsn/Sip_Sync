import '../../domain/domain.dart';

/// Daily totals supplied by the user. No individual sip times were supplied.
class ScreenshotHistoryProfile {
  ScreenshotHistoryProfile._();

  static const enabled = bool.fromEnvironment('RESTORE_SCREENSHOT_HISTORY');
  static const currentGoalMl = 1500;
  static List<DailySummary> get days => [
    DailySummary(date: DateTime(2026, 10, 19), totalMl: 1102, goalMl: 2000),
    DailySummary(date: DateTime(2026, 10, 20), totalMl: 3584, goalMl: 2000),
  ];
}
