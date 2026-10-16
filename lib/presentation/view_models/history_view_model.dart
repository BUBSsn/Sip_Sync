import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/domain.dart';

/// Single day bar representation for the weekly intake chart.
@immutable
class WeeklyDayColumn {
  const WeeklyDayColumn({
    required this.dayLabel,
    required this.date,
    required this.totalMl,
    required this.goalMl,
    required this.progress,
    required this.isToday,
  });

  /// Short weekday label (e.g., "Tue", "Wed", "Mon").
  final String dayLabel;

  /// Normalized calendar date.
  final DateTime date;

  /// Water intake in ml.
  final int totalMl;

  /// Goal in ml for that day.
  final int goalMl;

  /// Completion ratio (clamped 0.0 to 1.0 for visuals).
  final double progress;

  /// Whether this column corresponds to the active/current day.
  final bool isToday;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklyDayColumn &&
          runtimeType == other.runtimeType &&
          dayLabel == other.dayLabel &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day &&
          totalMl == other.totalMl &&
          goalMl == other.goalMl &&
          isToday == other.isToday;

  @override
  int get hashCode => Object.hash(
    dayLabel,
    date.year,
    date.month,
    date.day,
    totalMl,
    goalMl,
    isToday,
  );
}

/// Archive history row model with milestone seal tier.
@immutable
class ArchiveItem {
  const ArchiveItem({
    required this.dayName,
    required this.date,
    required this.totalMl,
    required this.goalMl,
    required this.sealTier,
    required this.statusText,
  });

  /// Full weekday or date name (e.g. "Monday", "Sunday").
  final String dayName;

  /// Normalized date.
  final DateTime date;

  /// Total intake in milliliters.
  final int totalMl;

  /// Target goal in milliliters.
  final int goalMl;

  /// Milestone seal tier (goalMet, almostThere, underGoal).
  final SealTier sealTier;

  /// Reference status text (e.g. "Goal Met!", "Almost there!").
  final String statusText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArchiveItem &&
          runtimeType == other.runtimeType &&
          dayName == other.dayName &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day &&
          totalMl == other.totalMl &&
          sealTier == other.sealTier;

  @override
  int get hashCode =>
      Object.hash(dayName, date.year, date.month, date.day, totalMl, sealTier);
}

/// Presentation state for the History screen.
@immutable
class HistoryViewState {
  const HistoryViewState({
    required this.weeklyColumns,
    required this.averageIntakeMl,
    required this.weeklyTotalDisplay,
    required this.currentStreakDays,
    required this.bestStreakDays,
    required this.currentTier,
    required this.bestTier,
    required this.daysToNextTier,
    required this.archiveEntries,
    required this.isEmpty,
    this.isLoading = false,
  });

  /// 7 rolling days ending on anchor day (rightmost column is always today/anchor).
  final List<WeeklyDayColumn> weeklyColumns;

  /// Average daily intake across the 7-day window in ml (Option A: sum / 7).
  final int averageIntakeMl;

  /// Formatted weekly total string (e.g. "12.9L").
  final String weeklyTotalDisplay;

  /// Active contiguous streak in days (drives droplet fill and glow).
  final int currentStreakDays;

  /// Best streak recorded in history in days (all-time achievement ribbon).
  final int bestStreakDays;

  /// Milestone badge tier corresponding to currentStreakDays.
  final StreakBadgeTier currentTier;

  /// Milestone badge tier corresponding to bestStreakDays.
  final StreakBadgeTier bestTier;

  /// Days remaining to unlock the next milestone badge tier.
  final int daysToNextTier;

  /// Archive entries sorted newest first.
  final List<ArchiveItem> archiveEntries;

  /// Whether history has zero records.
  final bool isEmpty;

  /// Whether history data is currently loading from repository.
  final bool isLoading;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryViewState &&
          runtimeType == other.runtimeType &&
          listEquals(weeklyColumns, other.weeklyColumns) &&
          averageIntakeMl == other.averageIntakeMl &&
          weeklyTotalDisplay == other.weeklyTotalDisplay &&
          currentStreakDays == other.currentStreakDays &&
          bestStreakDays == other.bestStreakDays &&
          currentTier == other.currentTier &&
          bestTier == other.bestTier &&
          daysToNextTier == other.daysToNextTier &&
          listEquals(archiveEntries, other.archiveEntries) &&
          isEmpty == other.isEmpty &&
          isLoading == other.isLoading;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(weeklyColumns),
    averageIntakeMl,
    weeklyTotalDisplay,
    currentStreakDays,
    bestStreakDays,
    currentTier,
    bestTier,
    daysToNextTier,
    Object.hashAll(archiveEntries),
    isEmpty,
    isLoading,
  );
}

/// Reactive ViewModel deriving weekly statistics, best streaks, and archive rows.
class HistoryViewModel extends StateNotifier<HistoryViewState> {
  HistoryViewModel({required this.historyRepository, DateTime? anchorDate})
    : _dynamicAnchorDate = anchorDate,
      super(
        _computeStateFromSummaries(
          historyRepository.currentSummaries,
          anchorDate,
        ),
      ) {
    _init();
  }

  final HistoryRepository historyRepository;
  final DateTime? _dynamicAnchorDate;
  StreamSubscription<List<DailySummary>>? _sub;

  static HistoryViewState _computeStateFromSummaries(
    List<DailySummary> summaries,
    DateTime? anchorDate,
  ) {
    if (summaries.isEmpty || summaries.every((day) => day.totalMl == 0)) {
      return const HistoryViewState(
        weeklyColumns: [],
        averageIntakeMl: 0,
        weeklyTotalDisplay: '0.0L',
        currentStreakDays: 0,
        bestStreakDays: 0,
        currentTier: StreakBadgeTier.none,
        bestTier: StreakBadgeTier.none,
        daysToNextTier: 1,
        archiveEntries: [],
        isEmpty: true,
      );
    }

    final anchor = normalizeDate(anchorDate ?? DateTime.now());
    final Map<DateTime, DailySummary> dayMap = {
      for (final s in summaries) normalizeDate(s.date): s,
    };

    final List<WeeklyDayColumn> columns = [];
    int weeklySumMl = 0;

    for (int i = 6; i >= 0; i--) {
      final date = DateTime(anchor.year, anchor.month, anchor.day - i);
      final summary = dayMap[date];
      final totalMl = summary?.totalMl ?? 0;
      final goalMl = summary?.goalMl ?? UserSettings.defaultDailyGoalMl;
      final progress = goalMl > 0 ? (totalMl / goalMl).clamp(0.0, 1.0) : 0.0;
      final isToday = date.isAtSameMomentAs(anchor);

      weeklySumMl += totalMl;
      columns.add(
        WeeklyDayColumn(
          dayLabel: _getShortWeekday(date.weekday),
          date: date,
          totalMl: totalMl,
          goalMl: goalMl,
          progress: progress,
          isToday: isToday,
        ),
      );
    }

    final avgMl = (weeklySumMl / 7).round();
    final totalLiters = weeklySumMl / 1000.0;
    final totalDisplay = '${totalLiters.toStringAsFixed(1)}L';

    final streak = calculateStreaks(summaries, today: anchor);

    // Build archive entries (sorted newest first)
    final sortedSummaries = List<DailySummary>.from(summaries)
      ..sort((a, b) => b.date.compareTo(a.date));

    final archiveList = sortedSummaries.map((s) {
      final tier = getSealTier(s.totalMl, s.goalMl);
      return ArchiveItem(
        dayName: _getFullWeekday(s.date.weekday),
        date: s.date,
        totalMl: s.totalMl,
        goalMl: s.goalMl,
        sealTier: tier,
        statusText: tier.statusText,
      );
    }).toList();

    return HistoryViewState(
      weeklyColumns: columns,
      averageIntakeMl: avgMl,
      weeklyTotalDisplay: totalDisplay,
      currentStreakDays: streak.currentStreak,
      bestStreakDays: streak.bestStreak,
      currentTier: streak.currentTier,
      bestTier: streak.bestTier,
      daysToNextTier: streak.daysToNextTier,
      archiveEntries: archiveList,
      isEmpty: false,
    );
  }

  void _init() {
    _sub = historyRepository.watchDailySummaries().listen((summaries) {
      if (!mounted) return;
      state = _computeStateFromSummaries(summaries, _dynamicAnchorDate);
    });
  }

  static String _getShortWeekday(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1) % 7];
  }

  static String _getFullWeekday(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[(weekday - 1) % 7];
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Provider exposing [HistoryViewState].
final historyViewModelProvider =
    StateNotifierProvider<HistoryViewModel, HistoryViewState>((ref) {
      final historyRepo = ref.watch(historyRepositoryProvider);
      return HistoryViewModel(historyRepository: historyRepo);
    }, dependencies: [historyRepositoryProvider]);
