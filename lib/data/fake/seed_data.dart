import '../../domain/domain.dart';

/// Seed fixtures faithfully reproducing the visual reference screens and specs:
/// - 1450 ml intake today
/// - 350 g empty cup weight
/// - Sips: 45 ml at 10:30 AM, 120 ml at 11:15 AM, 250 ml at 08:00 AM (plus earlier morning intake totaling 1450 ml)
/// - History week matching:
///   - Monday: 2100 ml (Goal Met!)
///   - Sunday: 1950 ml (Almost there!)
///   - Saturday: 1600 ml
///   - Weekly total: 12.9L (12,900 ml)
///   - Average intake: 1850 ml
///   - Best streak: 5 Days
class SeedData {
  static const double defaultCupWeightGrams = 350.0;
  static const int defaultDailyGoalMl = 2000;
  static const int defaultInactivityThresholdMinutes = 45;

  /// Generates the initial sips for today, totaling exactly 1450 ml,
  /// containing the reference sips (08:00: 250ml, 10:30: 45ml, 11:15: 120ml).
  ///
  /// Returned in newest-first chronological order.
  static List<SipEvent> createSeedTodaySips([DateTime? anchorDate]) {
    final now = anchorDate ?? DateTime.now();
    final todayUtc = DateTime.utc(now.year, now.month, now.day);

    return [
      SipEvent(
        id: 'sip_seed_today_1115',
        volumeMl: 120,
        timestamp: todayUtc.add(const Duration(hours: 11, minutes: 15)),
      ),
      SipEvent(
        id: 'sip_seed_today_1030',
        volumeMl: 45,
        timestamp: todayUtc.add(const Duration(hours: 10, minutes: 30)),
      ),
      SipEvent(
        id: 'sip_seed_today_0800',
        volumeMl: 250,
        timestamp: todayUtc.add(const Duration(hours: 8)),
      ),
      SipEvent(
        id: 'sip_seed_today_0730',
        volumeMl: 535,
        timestamp: todayUtc.add(const Duration(hours: 7, minutes: 30)),
      ),
      SipEvent(
        id: 'sip_seed_today_0645',
        volumeMl: 500,
        timestamp: todayUtc.add(const Duration(hours: 6, minutes: 45)),
      ),
    ];
  }

  /// Generates 4+ weeks of historical daily summaries matching the reference screen:
  /// - Monday: 2100 ml (Goal Met!)
  /// - Sunday: 1950 ml (Almost there!)
  /// - Saturday: 1600 ml
  /// - Preceding Tue-Fri yielding 12.9L total and 1850 ml average.
  /// - Prior history contains a contiguous 5-day streak of meeting goal,
  ///   yielding a verified Best Streak of 5 Days.
  /// - 4+ weeks of continuous historical daily summaries.
  static List<DailySummary> createSeedHistory([DateTime? anchorDate]) {
    final now = anchorDate ?? DateTime.now();
    final today = normalizeDate(now);

    // Reference completed week ending on yesterday (Monday):
    final monday = today.subtract(const Duration(days: 1));
    final sunday = today.subtract(const Duration(days: 2));
    final saturday = today.subtract(const Duration(days: 3));
    final friday = today.subtract(const Duration(days: 4));
    final thursday = today.subtract(const Duration(days: 5));
    final wednesday = today.subtract(const Duration(days: 6));
    final tuesday = today.subtract(const Duration(days: 7));

    // Earlier history providing a contiguous 5-day best streak:
    final prior5 = today.subtract(const Duration(days: 8));
    final prior4 = today.subtract(const Duration(days: 9));
    final prior3 = today.subtract(const Duration(days: 10));
    final prior2 = today.subtract(const Duration(days: 11));
    final prior1 = today.subtract(const Duration(days: 12));
    final priorGap = today.subtract(const Duration(days: 13));

    final list = <DailySummary>[
      // Additional older weeks (days 14 through 30) ensuring 4+ full weeks:
      for (int d = 30; d >= 14; d--)
        DailySummary(
          date: today.subtract(Duration(days: d)),
          totalMl: (d % 3 == 0) ? 2100 : ((d % 2 == 0) ? 1800 : 1500),
          goalMl: 2000,
        ),
      DailySummary(date: priorGap, totalMl: 1400, goalMl: 2000),
      DailySummary(date: prior1, totalMl: 2050, goalMl: 2000),
      DailySummary(date: prior2, totalMl: 2100, goalMl: 2000),
      DailySummary(date: prior3, totalMl: 2000, goalMl: 2000),
      DailySummary(date: prior4, totalMl: 2200, goalMl: 2000),
      DailySummary(
        date: prior5,
        totalMl: 2050,
        goalMl: 2000,
      ), // 5-day best streak
      // 7 days of weekly history matching reference:
      DailySummary(date: tuesday, totalMl: 1200, goalMl: 2000),
      DailySummary(date: wednesday, totalMl: 2000, goalMl: 2000),
      DailySummary(date: thursday, totalMl: 2050, goalMl: 2000),
      DailySummary(date: friday, totalMl: 2000, goalMl: 2000),
      DailySummary(date: saturday, totalMl: 1600, goalMl: 2000),
      DailySummary(date: sunday, totalMl: 1950, goalMl: 2000),
      DailySummary(date: monday, totalMl: 2100, goalMl: 2000),
    ];

    return list;
  }

  /// Partial history preset (only 3 days logged).
  static List<DailySummary> createPartialHistory([DateTime? anchorDate]) {
    final now = anchorDate ?? DateTime.now();
    final today = normalizeDate(now);
    return [
      DailySummary(
        date: today.subtract(const Duration(days: 2)),
        totalMl: 1600,
        goalMl: 2000,
      ),
      DailySummary(
        date: today.subtract(const Duration(days: 1)),
        totalMl: 2100,
        goalMl: 2000,
      ),
      DailySummary(date: today, totalMl: 800, goalMl: 2000),
    ];
  }

  /// 35-day contiguous streak preset unlocking Tier 5 (30+ days).
  static List<DailySummary> createHighStreakHistory([DateTime? anchorDate]) {
    final now = anchorDate ?? DateTime.now();
    final today = normalizeDate(now);
    return [
      for (int d = 35; d >= 1; d--)
        DailySummary(
          date: today.subtract(Duration(days: d)),
          totalMl: 2050 + (d % 4) * 50,
          goalMl: 2000,
        ),
    ];
  }
}

/// History presets for debug simulator.
enum HistoryPreset { reference, empty, partial, highStreak }
