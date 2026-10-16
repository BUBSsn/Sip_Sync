import 'package:flutter/foundation.dart';

/// Normalizes a [DateTime] to local calendar date component (midnight YYYY-MM-DD),
/// stripping time elements and avoiding DST ambiguity.
DateTime normalizeDate(DateTime dt) {
  final local = dt.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Formats a [DateTime] into a stable date key `YYYY-MM-DD`.
String toDateKey(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Represents the aggregated water intake history for a single calendar day.
///
/// **Units & Semantics**:
/// - [date]: Local calendar date normalized to midnight (`DateTime(year, month, day)`).
/// - [totalMl]: Sum of water intake consumed on this date in milliliters (`ml`).
/// - [goalMl]: The daily goal in milliliters (`ml`) that was active on this date.
@immutable
class DailySummary {
  DailySummary({
    required DateTime date,
    required this.totalMl,
    required this.goalMl,
  }) : date = normalizeDate(date),
       assert(totalMl >= 0, 'totalMl must be non-negative'),
       assert(goalMl > 0, 'goalMl must be strictly positive');

  /// The normalized local calendar date.
  final DateTime date;

  /// Total intake in milliliters (ml).
  final int totalMl;

  /// Goal in milliliters (ml) for that date.
  final int goalMl;

  /// Ratio of intake to goal (0.0 to 1.0+).
  double get progress => goalMl > 0 ? totalMl / goalMl : 0.0;

  /// Whether the daily goal was met (100% or greater).
  bool get isGoalMet => totalMl >= goalMl;

  DailySummary copyWith({DateTime? date, int? totalMl, int? goalMl}) {
    return DailySummary(
      date: date ?? this.date,
      totalMl: totalMl ?? this.totalMl,
      goalMl: goalMl ?? this.goalMl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailySummary &&
          runtimeType == other.runtimeType &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day &&
          totalMl == other.totalMl &&
          goalMl == other.goalMl;

  @override
  int get hashCode =>
      Object.hash(date.year, date.month, date.day, totalMl, goalMl);

  @override
  String toString() =>
      'DailySummary(date: ${toDateKey(date)}, totalMl: ${totalMl}ml, goalMl: ${goalMl}ml, met: $isGoalMet)';
}
