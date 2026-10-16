import 'package:flutter/foundation.dart';

/// Milestone tiers for streak progression (water-drop badge).
enum StreakBadgeTier {
  /// 0 days (no streak active).
  none(0, 0),

  /// 1-2 days.
  tier1(1, 2),

  /// 3-6 days.
  tier2(3, 6),

  /// 7-13 days.
  tier3(7, 13),

  /// 14-29 days.
  tier4(14, 29),

  /// 30+ days.
  tier5(30, null);

  const StreakBadgeTier(this.minDays, this.maxDays);

  final int minDays;
  final int? maxDays;

  static StreakBadgeTier fromDays(int days) {
    if (days <= 0) return StreakBadgeTier.none;
    if (days <= 2) return StreakBadgeTier.tier1;
    if (days <= 6) return StreakBadgeTier.tier2;
    if (days <= 13) return StreakBadgeTier.tier3;
    if (days <= 29) return StreakBadgeTier.tier4;
    return StreakBadgeTier.tier5;
  }

  /// Calculates the days required to reach the next tier from [currentDays].
  /// Returns 0 when already at [StreakBadgeTier.tier5].
  static int daysToNextTier(int currentDays) {
    if (currentDays < 1) return 1;
    if (currentDays <= 2) return 3 - currentDays;
    if (currentDays <= 6) return 7 - currentDays;
    if (currentDays <= 13) return 14 - currentDays;
    if (currentDays <= 29) return 30 - currentDays;
    return 0;
  }
}

/// Represents the calculated streak metrics for a user's hydration journey.
///
/// **Units & Semantics**:
/// - [currentStreak]: Count of contiguous consecutive days up to today or yesterday
///   where daily intake was greater than or equal to the daily goal.
/// - [bestStreak]: Maximum consecutive days goal was met across historical records.
@immutable
class StreakResult {
  const StreakResult({required this.currentStreak, required this.bestStreak})
    : assert(currentStreak >= 0, 'currentStreak must be non-negative'),
      assert(bestStreak >= 0, 'bestStreak must be non-negative'),
      assert(
        bestStreak >= currentStreak,
        'bestStreak cannot be less than currentStreak',
      );

  /// Current active streak length in days.
  final int currentStreak;

  /// All-time best streak length in days.
  final int bestStreak;

  StreakBadgeTier get currentTier => StreakBadgeTier.fromDays(currentStreak);
  StreakBadgeTier get bestTier => StreakBadgeTier.fromDays(bestStreak);

  /// Days remaining to unlock the next milestone badge tier.
  int get daysToNextTier => StreakBadgeTier.daysToNextTier(currentStreak);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakResult &&
          runtimeType == other.runtimeType &&
          currentStreak == other.currentStreak &&
          bestStreak == other.bestStreak;

  @override
  int get hashCode => Object.hash(currentStreak, bestStreak);

  @override
  String toString() =>
      'StreakResult(current: $currentStreak days, best: $bestStreak days)';
}
