import 'dart:math';

import '../models/daily_summary.dart';
import '../models/freshness_phase.dart';
import '../models/hydration_state.dart';
import '../models/seal_tier.dart';
import '../models/sip_event.dart';
import '../models/streak_result.dart';

/// Pure domain logic functions for the SipSync hydration lifecycle.
///
/// All functions in this file are deterministic, free of external side effects,
/// and independent of Flutter/Riverpod frameworks.

/// Computes the user's current [HydrationState] based on [totalMl] consumed
/// and the active [goalMl].
///
/// Progress brackets:
/// - 0% - 24%: [HydrationState.gettingStarted] ("Just Getting Started")
/// - 25% - 49%: [HydrationState.steadyStream] ("Steady Stream")
/// - 50% - 79%: [HydrationState.optimalFlow] ("Optimal Flow")
/// - 80% - 99%: [HydrationState.nearlyFull] ("Nearly Full")
/// - 100%+: [HydrationState.fullReservoir] ("Full Reservoir")
///
/// Edge cases:
/// - If [goalMl] <= 0, returns [HydrationState.gettingStarted] safely.
/// - If [totalMl] <= 0, returns [HydrationState.gettingStarted].
HydrationState getHydrationState(int totalMl, int goalMl) {
  if (goalMl <= 0 || totalMl <= 0) {
    return HydrationState.gettingStarted;
  }

  final progress = totalMl / goalMl;

  if (progress < 0.25) {
    return HydrationState.gettingStarted;
  } else if (progress < 0.50) {
    return HydrationState.steadyStream;
  } else if (progress < 0.80) {
    return HydrationState.optimalFlow;
  } else if (progress < 1.00) {
    return HydrationState.nearlyFull;
  } else {
    return HydrationState.fullReservoir;
  }
}

/// Evaluates the [FreshnessPhase] representing how recently the user drank water.
///
/// - 0% - 50% of [threshold]: [FreshnessPhase.fresh]
/// - >50% - 100% of [threshold]: [FreshnessPhase.fading]
/// - >100% of [threshold]: [FreshnessPhase.dry]
///
/// Edge cases:
/// - If [threshold] <= Duration.zero, returns [FreshnessPhase.dry].
/// - If [elapsed] < Duration.zero (clock drift/reversion), falls back to [FreshnessPhase.fresh].
FreshnessPhase getFreshnessPhase(Duration elapsed, Duration threshold) {
  if (threshold <= Duration.zero) {
    return FreshnessPhase.dry;
  }

  if (elapsed < Duration.zero) {
    return FreshnessPhase.fresh;
  }

  final ratio = elapsed.inMicroseconds / threshold.inMicroseconds;

  if (ratio <= 0.50) {
    return FreshnessPhase.fresh;
  } else if (ratio <= 1.00) {
    return FreshnessPhase.fading;
  } else {
    return FreshnessPhase.dry;
  }
}

/// Determines the archive [SealTier] from daily intake vs goal.
///
/// - 100%+: [SealTier.goalMet] ("Goal Met!")
/// - 80% - 99%: [SealTier.almostThere] ("Almost there!")
/// - <80%: [SealTier.underGoal] ("In Progress")
///
/// Edge cases:
/// - If [goalMl] <= 0 or [totalMl] < 0, returns [SealTier.underGoal].
SealTier getSealTier(int totalMl, int goalMl) {
  if (goalMl <= 0 || totalMl < 0) {
    return SealTier.underGoal;
  }

  final ratio = totalMl / goalMl;

  if (ratio >= 1.0) {
    return SealTier.goalMet;
  } else if (ratio >= 0.80) {
    return SealTier.almostThere;
  } else {
    return SealTier.underGoal;
  }
}

/// Calculates [StreakResult] (current and best streak in consecutive days)
/// from a list of [DailySummary] records.
///
/// Rules:
/// - A day counts towards a streak if `totalMl >= goalMl`.
/// - Deduplicates multiple records for the same calendar day (picks highest totalMl).
/// - Current streak:
///   - If [today] meets the goal, counts backward starting from today.
///   - If [today] has not met the goal yet, checks if yesterday met the goal.
///     If yes, the streak is alive from yesterday and counts backward from yesterday.
///   - If neither today nor yesterday met the goal, current streak is 0.
/// - Best streak:
///   - Highest contiguous block of consecutive days with `totalMl >= goalMl`.
///   - Always >= current streak.
StreakResult calculateStreaks(List<DailySummary> history, {DateTime? today}) {
  if (history.isEmpty) {
    return const StreakResult(currentStreak: 0, bestStreak: 0);
  }

  // Deduplicate and group by normalized calendar date
  final Map<DateTime, DailySummary> dayMap = {};
  for (final summary in history) {
    final norm = normalizeDate(summary.date);
    final existing = dayMap[norm];
    if (existing == null || summary.totalMl > existing.totalMl) {
      dayMap[norm] = summary;
    }
  }

  final sortedDays = dayMap.keys.toList()..sort();

  // 1. Calculate best streak across all chronological entries
  int maxStreak = 0;
  int tempStreak = 0;
  DateTime? prevDate;

  for (final date in sortedDays) {
    final summary = dayMap[date]!;
    if (summary.isGoalMet) {
      if (prevDate != null &&
          DateTime.utc(date.year, date.month, date.day)
                  .difference(
                    DateTime.utc(prevDate.year, prevDate.month, prevDate.day),
                  )
                  .inDays ==
              1) {
        tempStreak++;
      } else {
        tempStreak = 1;
      }
      if (tempStreak > maxStreak) {
        maxStreak = tempStreak;
      }
    } else {
      tempStreak = 0;
    }
    prevDate = date;
  }

  // 2. Calculate current active streak
  final targetToday = normalizeDate(today ?? DateTime.now());
  final todaySummary = dayMap[targetToday];

  int currentStreak = 0;
  DateTime? startCountingFrom;

  if (todaySummary != null && todaySummary.isGoalMet) {
    startCountingFrom = targetToday;
  } else {
    final yesterday = DateTime(
      targetToday.year,
      targetToday.month,
      targetToday.day - 1,
    );
    final yesterdaySummary = dayMap[yesterday];
    if (yesterdaySummary != null && yesterdaySummary.isGoalMet) {
      startCountingFrom = yesterday;
    }
  }

  if (startCountingFrom != null) {
    currentStreak = 0;
    var checkDate = startCountingFrom;
    while (true) {
      final summary = dayMap[checkDate];
      if (summary != null && summary.isGoalMet) {
        currentStreak++;
        checkDate = DateTime(
          checkDate.year,
          checkDate.month,
          checkDate.day - 1,
        );
      } else {
        break;
      }
    }
  }

  final finalBestStreak = max(maxStreak, currentStreak);
  return StreakResult(
    currentStreak: currentStreak,
    bestStreak: finalBestStreak,
  );
}

/// Merges rapid consecutive sips occurring within [window] (default 2 minutes)
/// into consolidated sip events.
///
/// Rules:
/// - Sips are sorted chronologically ascending before grouping.
/// - If a sip occurs within [window] of the preceding sip, its volume is added
///   to the current group, and the group's timestamp is updated to the latest sip.
/// - Returns list of consolidated sips sorted newest-first.
List<SipEvent> groupSipMergeWindows(
  List<SipEvent> sips, {
  Duration window = const Duration(minutes: 2),
}) {
  if (sips.isEmpty) return const [];

  final sorted = List<SipEvent>.from(sips)
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final List<SipEvent> merged = [];
  SipEvent current = sorted.first;

  for (int i = 1; i < sorted.length; i++) {
    final next = sorted[i];
    final diff = next.timestamp.difference(current.timestamp).abs();

    if (diff <= window) {
      // Merge into current
      current = SipEvent(
        id: '${current.id}_${next.id}',
        volumeMl: current.volumeMl + next.volumeMl,
        timestamp: next.timestamp,
      );
    } else {
      merged.add(current);
      current = next;
    }
  }
  merged.add(current);

  // Return newest-first as specified by the master spec
  return merged.reversed.toList();
}

/// Detects whether calendar day rollover has occurred between [lastCheck] and [now].
///
/// Handles midnight transitions as well as multi-day app suspensions.
bool checkDayRollover(DateTime lastCheck, DateTime now) {
  final lastNorm = normalizeDate(lastCheck);
  final nowNorm = normalizeDate(now);
  return !lastNorm.isAtSameMomentAs(nowNorm);
}

/// Pure helper for firmware emitting raw weights rather than discrete sip events.
///
/// Infers liquid consumption from a weight drop between [previousGrams] and [currentGrams].
/// Returns volume in ml (assuming 1.0 g water ≈ 1.0 ml) if drop >= [minThresholdGrams].
int? detectSipVolumeFromWeightDrop(
  double previousGrams,
  double currentGrams, {
  double minThresholdGrams = 10.0,
}) {
  final drop = previousGrams - currentGrams;
  if (drop >= minThresholdGrams) {
    return drop.round();
  }
  return null;
}
