import '../models/daily_summary.dart';
import '../models/sip_event.dart';

/// Contract for querying and managing hydration logs and daily summaries.
abstract class HistoryRepository {
  /// Fetches daily summaries within an optional date range (inclusive).
  ///
  /// Dates are normalized to calendar days using [normalizeDate].
  Future<List<DailySummary>> getDailySummaries({
    DateTime? start,
    DateTime? end,
  });

  /// Broadcast stream emitting the full list of daily summaries on updates.
  Stream<List<DailySummary>> watchDailySummaries();

  /// Synchronous snapshot of all cached daily summaries.
  List<DailySummary> get currentSummaries;

  /// Fetches all individual sips recorded for a specific calendar [date],
  /// sorted newest-first.
  Future<List<SipEvent>> getSipsForDay(DateTime date);

  /// Synchronous snapshot of today's recorded sips (newest first).
  List<SipEvent> get currentTodaySips;

  /// Broadcast stream emitting today's recorded sips (newest first) whenever
  /// sips are added, edited, or removed.
  Stream<List<SipEvent>> watchTodaySips();

  /// Records a newly detected or manually added [sip].
  Future<void> recordSip(SipEvent sip);

  /// Deletes a previously logged sip by its [sipId].
  Future<void> deleteSip(String sipId);

  /// Adjusts the volume of a logged sip identified by [sipId] to [newVolumeMl].
  Future<void> updateSipVolume(String sipId, int newVolumeMl);

  /// Checks and synchronizes calendar day rollover against [now] (defaults to `DateTime.now()`).
  /// If calendar day has rolled over, archives previous day's intake and emits updated streams.
  Future<void> checkDayRolloverTrigger([DateTime? now]);
}
