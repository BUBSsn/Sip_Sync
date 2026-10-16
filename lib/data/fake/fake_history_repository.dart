import 'dart:async';

import '../../domain/domain.dart';
import 'seed_data.dart';

/// Fake implementation of [HistoryRepository] seeded with reference data.
///
/// Pre-seeded with:
/// - 1450 ml today (sips at 11:15 120ml, 10:30 45ml, 08:00 250ml, plus earlier morning intake)
/// - History week (Monday 2100ml, Sunday 1950ml, Saturday 1600ml, 12.9L weekly total, 1850ml average)
/// - Historical contiguous 5-day best streak.
class FakeHistoryRepository implements HistoryRepository {
  FakeHistoryRepository({
    List<SipEvent>? initialSips,
    List<DailySummary>? initialSummaries,
    DateTime? anchorDate,
  }) : _todaySips = initialSips != null
           ? List<SipEvent>.from(initialSips)
           : SeedData.createSeedTodaySips(anchorDate),
       _summaries = initialSummaries != null
           ? List<DailySummary>.from(initialSummaries)
           : SeedData.createSeedHistory(anchorDate),
       _anchorDate = normalizeDate(anchorDate ?? DateTime.now()) {
    _ensureTodaySummary();
  }

  DateTime _anchorDate;
  final List<SipEvent> _todaySips;
  final List<DailySummary> _summaries;

  final StreamController<List<DailySummary>> _summariesController =
      StreamController<List<DailySummary>>.broadcast();
  final StreamController<List<SipEvent>> _todaySipsController =
      StreamController<List<SipEvent>>.broadcast();

  /// Calculates the sum of volumeMl for today's sips and ensures a matching
  /// [DailySummary] exists in [_summaries].
  void _ensureTodaySummary() {
    final todayTotal = _todaySips.fold<int>(0, (sum, s) => sum + s.volumeMl);
    final existingIndex = _summaries.indexWhere(
      (s) => normalizeDate(s.date).isAtSameMomentAs(_anchorDate),
    );

    if (existingIndex >= 0) {
      final existing = _summaries[existingIndex];
      _summaries[existingIndex] = existing.copyWith(totalMl: todayTotal);
    } else {
      _summaries.add(
        DailySummary(
          date: _anchorDate,
          totalMl: todayTotal,
          goalMl: SeedData.defaultDailyGoalMl,
        ),
      );
    }
  }

  @override
  Future<List<DailySummary>> getDailySummaries({
    DateTime? start,
    DateTime? end,
  }) async {
    var filtered = List<DailySummary>.from(_summaries);

    if (start != null) {
      final normStart = normalizeDate(start);
      filtered = filtered
          .where((s) => !normalizeDate(s.date).isBefore(normStart))
          .toList();
    }

    if (end != null) {
      final normEnd = normalizeDate(end);
      filtered = filtered
          .where((s) => !normalizeDate(s.date).isAfter(normEnd))
          .toList();
    }

    filtered.sort((a, b) => a.date.compareTo(b.date));
    return filtered;
  }

  @override
  Stream<List<DailySummary>> watchDailySummaries() =>
      _summariesController.stream;

  @override
  List<DailySummary> get currentSummaries => List.unmodifiable(_summaries);

  @override
  Future<List<SipEvent>> getSipsForDay(DateTime date) async {
    final targetNorm = normalizeDate(date);
    if (targetNorm.isAtSameMomentAs(_anchorDate)) {
      // Sips for today, sorted newest first
      final sips = List<SipEvent>.from(_todaySips)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return sips;
    }
    // Return empty for past days in this fake unless specifically seeded
    return [];
  }

  @override
  List<SipEvent> get currentTodaySips => List.unmodifiable(_todaySips);

  @override
  Stream<List<SipEvent>> watchTodaySips() => _todaySipsController.stream;

  @override
  Future<void> recordSip(SipEvent sip) async {
    _todaySips.insert(0, sip);
    _todaySips.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _ensureTodaySummary();

    _todaySipsController.add(List.unmodifiable(_todaySips));
    _summariesController.add(List.unmodifiable(_summaries));
  }

  @override
  Future<void> deleteSip(String sipId) async {
    _todaySips.removeWhere((s) => s.id == sipId);
    _ensureTodaySummary();

    _todaySipsController.add(List.unmodifiable(_todaySips));
    _summariesController.add(List.unmodifiable(_summaries));
  }

  @override
  Future<void> updateSipVolume(String sipId, int newVolumeMl) async {
    assert(newVolumeMl > 0, 'newVolumeMl must be positive');
    final index = _todaySips.indexWhere((s) => s.id == sipId);
    if (index >= 0) {
      _todaySips[index] = _todaySips[index].copyWith(volumeMl: newVolumeMl);
      _ensureTodaySummary();

      _todaySipsController.add(List.unmodifiable(_todaySips));
      _summariesController.add(List.unmodifiable(_summaries));
    }
  }

  /// Replaces today's sips (useful for testing day rollover or batch resets).
  Future<void> replaceTodaySips(List<SipEvent> sips) async {
    _todaySips.clear();
    _todaySips.addAll(sips);
    _ensureTodaySummary();

    _todaySipsController.add(List.unmodifiable(_todaySips));
    _summariesController.add(List.unmodifiable(_summaries));
  }

  /// Sets historical summaries from a [HistoryPreset] and broadcasts to subscribers.
  Future<void> setHistoryPreset(HistoryPreset preset) async {
    _summaries.clear();
    switch (preset) {
      case HistoryPreset.reference:
        _summaries.addAll(SeedData.createSeedHistory(_anchorDate));
        break;
      case HistoryPreset.empty:
        _todaySips.clear();
        _todaySipsController.add(const []);
        break;
      case HistoryPreset.partial:
        _summaries.addAll(SeedData.createPartialHistory(_anchorDate));
        break;
      case HistoryPreset.highStreak:
        _summaries.addAll(SeedData.createHighStreakHistory(_anchorDate));
        break;
    }
    if (preset != HistoryPreset.empty) {
      _ensureTodaySummary();
    }
    _summariesController.add(List.unmodifiable(_summaries));
  }

  /// Simulates midnight day rollover: archives today's final intake into yesterday's DailySummary,
  /// clears today's sips to empty, advances anchor date, creates a new 0ml summary for today,
  /// and broadcasts updates to both sips and summary streams.
  Future<void> simulateMidnightRollover([DateTime? newDate]) async {
    final nextDate = newDate != null
        ? normalizeDate(newDate)
        : _anchorDate.add(const Duration(days: 1));

    // Ensure today's sips are permanently captured in the existing summary
    _ensureTodaySummary();

    // Clear today's sips for the brand new day
    _todaySips.clear();

    // Update anchor date to nextDate
    _anchorDate = nextDate;

    // Create fresh 0ml summary for the new day
    _ensureTodaySummary();

    _todaySipsController.add(List.unmodifiable(_todaySips));
    _summariesController.add(List.unmodifiable(_summaries));
  }

  @override
  Future<void> checkDayRolloverTrigger([DateTime? now]) async {
    final current = now ?? DateTime.now();
    if (checkDayRollover(_anchorDate, current)) {
      await simulateMidnightRollover(current);
    }
  }

  void dispose() {
    _summariesController.close();
    _todaySipsController.close();
  }
}
