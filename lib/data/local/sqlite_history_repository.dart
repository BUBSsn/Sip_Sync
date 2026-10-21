import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../../domain/domain.dart';
import 'preferences_settings_repository.dart';

/// Durable records. Deleted IDs remain as tombstones so device replay cannot
/// resurrect records. Summaries are derived from the same authoritative rows.
class SqliteHistoryRepository implements HistoryRepository {
  SqliteHistoryRepository._(
    this.database,
    this.settings,
    this._clock,
    this._calendarDate,
  );
  final Database database;
  final PreferencesSettingsRepository settings;
  final DateTime Function() _clock;
  final DateTime Function(DateTime) _calendarDate;
  List<SipEvent> _sips = [];
  List<DailySummary> _summaries = [];
  Map<String, int> _restoredDailyTotals = {};
  bool initialHistoryRestored = false;
  late DateTime _today;
  final _sipChanges = StreamController<List<SipEvent>>.broadcast();
  final _summaryChanges = StreamController<List<DailySummary>>.broadcast();
  Future<void> _pending = Future.value();

  static Future<SqliteHistoryRepository> open({
    required PreferencesSettingsRepository settings,
    DatabaseFactory? factory,
    String? databasePath,
    DateTime Function()? clock,
    DateTime Function(DateTime)? calendarDate,
    List<DailySummary> initialDailyTotals = const [],
    int? initialDailyGoalMl,
  }) async {
    if (initialDailyGoalMl != null &&
        (initialDailyGoalMl < 1000 || initialDailyGoalMl > 4000)) {
      throw ArgumentError('Daily goal must be between 1000 and 4000 ml');
    }
    if (initialDailyTotals.any(
      (day) => day.totalMl < 0 || day.goalMl < 1000 || day.goalMl > 4000,
    )) {
      throw ArgumentError('Invalid initial daily totals');
    }
    var restoredOnCreate = false;
    final dbFactory = factory ?? databaseFactory;
    final dbPath =
        databasePath ??
        path.join(await dbFactory.getDatabasesPath(), 'liquid_store.db');
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE sips (id TEXT PRIMARY KEY, volume_ml INTEGER NOT NULL CHECK(volume_ml > 0), timestamp_ms INTEGER NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, time_estimated INTEGER NOT NULL DEFAULT 0)',
          );
          await db.execute('CREATE INDEX sip_time ON sips(timestamp_ms)');
          await db.execute(
            'CREATE TABLE goals (day TEXT PRIMARY KEY, goal_ml INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE app_settings (id INTEGER PRIMARY KEY CHECK(id = 1), daily_goal_ml INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE restored_daily_totals (day TEXT PRIMARY KEY, total_ml INTEGER NOT NULL CHECK(total_ml >= 0))',
          );
          // Applied only on database creation: updates/restarts never import again.
          if (initialDailyTotals.isNotEmpty) {
            for (final day in initialDailyTotals) {
              final date = normalizeDate(day.date);
              final key =
                  '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              await db.insert('restored_daily_totals', {
                'day': key,
                'total_ml': day.totalMl,
              });
              await db.insert('goals', {'day': key, 'goal_ml': day.goalMl});
            }
            await db.insert('app_settings', {
              'id': 1,
              'daily_goal_ml':
                  initialDailyGoalMl ?? settings.currentSettings.dailyGoalMl,
            });
            restoredOnCreate = true;
          }
        },
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) {
            await db.execute(
              'CREATE TABLE app_settings (id INTEGER PRIMARY KEY CHECK(id = 1), daily_goal_ml INTEGER NOT NULL)',
            );
          }
          if (oldVersion < 3) {
            await db.execute(
              'CREATE TABLE restored_daily_totals (day TEXT PRIMARY KEY, total_ml INTEGER NOT NULL CHECK(total_ml >= 0))',
            );
          }
        },
      ),
    );
    final repository = SqliteHistoryRepository._(
      db,
      settings,
      clock ?? DateTime.now,
      calendarDate ?? normalizeDate,
    );
    repository.initialHistoryRestored = restoredOnCreate;
    try {
      repository._today = normalizeDate(repository._clock());
      final currentGoal = await db.transaction((txn) async {
        final stored = await txn.query('app_settings', where: 'id = 1');
        if (stored.isNotEmpty) return stored.single['daily_goal_ml'] as int;
        final goal = settings.currentSettings.dailyGoalMl;
        await txn.insert('app_settings', {'id': 1, 'daily_goal_ml': goal});
        // Import the legacy preference once, repairing a previously interrupted
        // preference/history update for today without rewriting older goals.
        await txn.insert('goals', {
          'day': repository._dayKey(repository._today),
          'goal_ml': goal,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        return goal;
      });
      await repository._ensureCurrentGoal(db, repository._today);
      await repository._reload();
      settings.attachGoalStore(currentGoal, repository._updateDailyGoal);
    } catch (_) {
      await db.close();
      rethrow;
    }
    return repository;
  }

  String _dayKey(DateTime date) {
    final local = _calendarDate(date);
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  Future<void> _ensureGoal(DatabaseExecutor db, DateTime date) async {
    final key = _dayKey(date);
    if ((await db.query(
      'goals',
      where: 'day = ?',
      whereArgs: [key],
    )).isNotEmpty) {
      return;
    }
    var previous = await db.query(
      'goals',
      where: 'day <= ?',
      whereArgs: [key],
      orderBy: 'day DESC',
      limit: 1,
    );
    // A delayed record before installation uses the earliest known goal.
    if (previous.isEmpty) {
      previous = await db.query('goals', orderBy: 'day ASC', limit: 1);
    }
    final goal = previous.isEmpty
        ? settings.currentSettings.dailyGoalMl
        : previous.single['goal_ml'] as int;
    await db.insert('goals', {
      'day': key,
      'goal_ml': goal,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _ensureCurrentGoal(DatabaseExecutor db, DateTime date) async {
    final current = await db.query('app_settings', where: 'id = 1');
    final goal = current.single['daily_goal_ml'] as int;
    final existing = await db.query(
      'goals',
      where: 'day = ?',
      whereArgs: [_dayKey(date)],
    );
    if (existing.isNotEmpty && existing.single['goal_ml'] == goal) return;
    await db.insert('goals', {
      'day': _dayKey(date),
      'goal_ml': goal,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _updateDailyGoal(int goal) => _enqueue(() async {
    if (goal < 1000 || goal > 4000) {
      throw ArgumentError('Daily goal must be between 1000 and 4000 ml');
    }
    final today = normalizeDate(_clock());
    await database.transaction((txn) async {
      await txn.update('app_settings', {
        'daily_goal_ml': goal,
      }, where: 'id = 1');
      await txn.insert('goals', {
        'day': _dayKey(today),
        'goal_ml': goal,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    // No fallible second persistence step after commit. Publish from the same
    // transaction's known values; preferences publishes only after this returns.
    _today = today;
    final summary = DailySummary(
      date: today,
      totalMl:
          (_restoredDailyTotals[_dayKey(today)] ?? 0) +
          currentTodaySips.fold<int>(0, (sum, sip) => sum + sip.volumeMl),
      goalMl: goal,
    );
    _summaries = [
      ..._summaries.where((day) => _dayKey(day.date) != _dayKey(today)),
      summary,
    ]..sort((a, b) => a.date.compareTo(b.date));
    _sipChanges.add(currentTodaySips);
    _summaryChanges.add(currentSummaries);
  });

  /// Snapshot and save share the same serialized queue. Include tombstones in
  /// the delivery watermark so deleted records cannot inflate device progress.
  Future<({int totalMl, int throughSequence})> deviceProgress(
    String deviceId,
  ) => _enqueue(() async {
    final prefix = '$deviceId:';
    final todayKey = _dayKey(_clock());
    final rows = await database.query('sips', columns: ['id']);
    int sequence = 0;
    for (final row in rows) {
      final id = row['id'] as String;
      if (id.startsWith(prefix)) {
        final value = int.tryParse(id.substring(prefix.length)) ?? 0;
        if (value > sequence) sequence = value;
      }
    }
    return (
      totalMl:
          (_restoredDailyTotals[todayKey] ?? 0) +
          _sips
              .where((sip) => _dayKey(sip.timestamp) == todayKey)
              .fold<int>(0, (sum, sip) => sum + sip.volumeMl),
      throughSequence: sequence,
    );
  });

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _reload() async {
    final rows = await database.query(
      'sips',
      where: 'deleted = 0',
      orderBy: 'timestamp_ms DESC, id DESC',
    );
    _sips = rows
        .map(
          (r) => SipEvent(
            id: r['id'] as String,
            volumeMl: r['volume_ml'] as int,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              r['timestamp_ms'] as int,
              isUtc: true,
            ),
            timestampEstimated: r['time_estimated'] == 1,
          ),
        )
        .toList();
    final restored = await database.query('restored_daily_totals');
    _restoredDailyTotals = {
      for (final row in restored) row['day'] as String: row['total_ml'] as int,
    };
    final totals = Map<String, int>.from(_restoredDailyTotals);
    for (final sip in _sips) {
      final key = _dayKey(sip.timestamp);
      totals[key] = (totals[key] ?? 0) + sip.volumeMl;
    }
    // Current-local-date aggregation can move records after a timezone change.
    // Materialize every intake date before projecting summaries, never just the
    // dates on which the app happened to be opened.
    await database.transaction((txn) async {
      for (final day in totals.keys) {
        await _ensureGoal(txn, DateTime.parse(day));
      }
    });
    final goals = await database.query('goals', orderBy: 'day ASC');
    _summaries = goals.map((r) {
      final day = r['day'] as String;
      return DailySummary(
        date: DateTime.parse(day),
        totalMl: totals[day] ?? 0,
        goalMl: r['goal_ml'] as int,
      );
    }).toList();
    _sipChanges.add(currentTodaySips);
    _summaryChanges.add(currentSummaries);
  }

  /// True only for a new row. Return after the transaction commits; callers
  /// acknowledge duplicates and tombstones too, without replaying feedback.
  Future<bool> recordHardwareSip(SipEvent sip) => _enqueue(() async {
    if (sip.id.isEmpty || sip.volumeMl <= 0) throw ArgumentError('Invalid sip');
    _today = normalizeDate(_clock());
    final inserted = await database.transaction((txn) async {
      await _ensureCurrentGoal(txn, _today);
      final existing = await txn.query(
        'sips',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [sip.id],
      );
      if (existing.isNotEmpty) return false;
      await _ensureGoal(txn, sip.timestamp);
      await txn.insert('sips', {
        'id': sip.id,
        'volume_ml': sip.volumeMl,
        'timestamp_ms': sip.timestamp.toUtc().millisecondsSinceEpoch,
        'time_estimated': sip.timestampEstimated ? 1 : 0,
      });
      return true;
    });
    // A previous attempt may have committed but failed during cache refresh.
    // Replay must repair the cache before it can be acknowledged.
    await _reload();
    return inserted;
  });
  @override
  Future<void> recordSip(SipEvent sip) async {
    await recordHardwareSip(sip);
  }

  @override
  Future<void> deleteSip(String sipId) => _enqueue(() async {
    await database.update(
      'sips',
      {'deleted': 1},
      where: 'id = ?',
      whereArgs: [sipId],
    );
    await _reload();
  });
  @override
  Future<void> updateSipVolume(String sipId, int newVolumeMl) =>
      _enqueue(() async {
        if (newVolumeMl < 5 || newVolumeMl > 1500) {
          throw ArgumentError('Volume must be between 5 and 1500 ml');
        }
        await database.update(
          'sips',
          {'volume_ml': newVolumeMl},
          where: 'id = ? AND deleted = 0',
          whereArgs: [sipId],
        );
        await _reload();
      });
  @override
  List<SipEvent> get currentTodaySips => List.unmodifiable(
    _sips.where((s) => _dayKey(s.timestamp) == _dayKey(_today)),
  );
  @override
  List<DailySummary> get currentSummaries => List.unmodifiable(_summaries);
  @override
  Stream<List<SipEvent>> watchTodaySips() => _sipChanges.stream;
  @override
  Stream<List<DailySummary>> watchDailySummaries() => _summaryChanges.stream;
  @override
  Future<List<SipEvent>> getSipsForDay(DateTime date) async =>
      _sips.where((s) => _dayKey(s.timestamp) == _dayKey(date)).toList();
  @override
  Future<List<DailySummary>> getDailySummaries({
    DateTime? start,
    DateTime? end,
  }) async => _summaries
      .where(
        (s) =>
            (start == null || !s.date.isBefore(normalizeDate(start))) &&
            (end == null || !s.date.isAfter(normalizeDate(end))),
      )
      .toList();
  @override
  Future<void> checkDayRolloverTrigger([DateTime? now]) => _enqueue(() async {
    _today = normalizeDate(now ?? _clock());
    await database.transaction((txn) => _ensureCurrentGoal(txn, _today));
    await _reload();
  });
  Future<void> dispose() async {
    await _pending;
    await _sipChanges.close();
    await _summaryChanges.close();
    await database.close();
  }
}
