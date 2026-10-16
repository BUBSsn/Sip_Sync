import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:liquid_store/data/local/sqlite_history_repository.dart';
import 'package:liquid_store/data/local/preferences_settings_repository.dart';
import 'package:liquid_store/domain/domain.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late PreferencesSettingsRepository settings;
  late SqliteHistoryRepository history;
  late DateTime now;
  String getPath() => '${directory.path}/history.db';
  Future<SqliteHistoryRepository> open() => SqliteHistoryRepository.open(
    settings: settings,
    factory: databaseFactoryFfi,
    databasePath: getPath(),
    clock: () => now,
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'liquid_store.daily_goal_ml': 2500,
    });
    settings = PreferencesSettingsRepository(
      await SharedPreferences.getInstance(),
    );
    directory = await Directory.systemTemp.createTemp('coaster_history_');
    now = DateTime(2026, 10, 14, 12);
    history = await open();
  });
  tearDown(() async {
    await history.dispose();
    settings.dispose();
    await directory.delete(recursive: true);
  });
  SipEvent sip(
    String id, {
    int volume = 120,
    DateTime? date,
    bool estimated = false,
  }) => SipEvent(
    id: id,
    volumeMl: volume,
    timestamp: (date ?? now).toUtc(),
    timestampEstimated: estimated,
  );

  test('new install is empty and loads the saved goal before any screen', () {
    expect(settings.currentSettings.dailyGoalMl, 2500);
    expect(history.currentTodaySips, isEmpty);
    expect(history.currentSummaries.single.totalMl, 0);
    expect(history.currentSummaries.single.goalMl, 2500);
  });
  test(
    'committed sips survive restart and concurrent replay is deduplicated',
    () async {
      final results = await Future.wait(
        List.generate(10, (_) => history.recordHardwareSip(sip('device:1'))),
      );
      expect(results.where((value) => value).length, 1);
      expect(history.currentSummaries.single.totalMl, 120);
      await history.dispose();
      history = await open();
      expect(history.currentTodaySips.single.id, 'device:1');
      expect(await history.recordHardwareSip(sip('device:1')), false);
    },
  );
  test(
    'edits and tombstones persist and replay never restores deletion',
    () async {
      await history.recordSip(sip('device:1'));
      await history.updateSipVolume('device:1', 80);
      await history.dispose();
      history = await open();
      expect(history.currentTodaySips.single.volumeMl, 80);
      expect(await history.recordHardwareSip(sip('device:1')), false);
      await history.deleteSip('device:1');
      await history.dispose();
      history = await open();
      expect(await history.recordHardwareSip(sip('device:1')), false);
      expect(history.currentTodaySips, isEmpty);
      expect(history.currentSummaries.single.totalMl, 0);
    },
  );
  test(
    'midnight keeps old records and delayed events retain their original day',
    () async {
      final yesterday = now;
      await history.recordSip(sip('old'));
      now = DateTime(2026, 10, 15, 0, 1);
      await history.checkDayRolloverTrigger();
      expect(history.currentTodaySips, isEmpty);
      await history.recordSip(sip('delayed', date: yesterday, volume: 50));
      await history.recordSip(sip('today', volume: 90));
      expect((await history.getSipsForDay(yesterday)).length, 2);
      expect(history.currentTodaySips.single.volumeMl, 90);
      expect(history.currentSummaries.map((s) => s.totalMl), [170, 90]);
    },
  );
  test('goal changes update today without changing previous goals', () async {
    await history.recordSip(sip('old'));
    now = DateTime(2026, 10, 15, 12);
    await history.checkDayRolloverTrigger();
    await settings.updateSettings(
      settings.currentSettings.copyWith(dailyGoalMl: 3000),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await history.checkDayRolloverTrigger();
    expect(history.currentSummaries.map((s) => s.goalMl), [2500, 3000]);
    await history.dispose();
    settings.dispose();
    settings = PreferencesSettingsRepository(
      await SharedPreferences.getInstance(),
    );
    history = await open();
    expect(settings.currentSettings.dailyGoalMl, 3000);
    expect(history.currentSummaries.last.goalMl, 3000);
  });
  test(
    'estimated event timestamps remain visibly identified after restart',
    () async {
      await history.recordSip(sip('estimated', estimated: true));
      await history.dispose();
      history = await open();
      expect(history.currentTodaySips.single.timestampEstimated, true);
    },
  );
  test('failed writes do not publish or acknowledge a record', () async {
    await history.database.execute(
      "CREATE TRIGGER reject_sip BEFORE INSERT ON sips BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
    );
    await expectLater(
      history.recordHardwareSip(sip('failure')),
      throwsA(isA<DatabaseException>()),
    );
    expect(history.currentTodaySips, isEmpty);
    await history.database.execute('DROP TRIGGER reject_sip');
    expect(await history.recordHardwareSip(sip('failure')), true);
  });
  test('offline days inherit the last goal active before that day', () async {
    now = DateTime(2026, 10, 16, 12);
    await history.checkDayRolloverTrigger();
    await settings.updateSettings(
      settings.currentSettings.copyWith(dailyGoalMl: 3000),
    );
    await history.recordSip(
      sip('offline', volume: 2700, date: DateTime(2026, 10, 15, 12)),
    );
    final previous = history.currentSummaries.singleWhere(
      (day) => day.date.day == 15,
    );
    expect(previous.goalMl, 2500);
    expect(previous.isGoalMet, true);
    expect(history.currentSummaries.last.goalMl, 3000);
  });

  test('failed goal transaction rolls back both setting and history', () async {
    await history.database.execute(
      "CREATE TRIGGER reject_goal BEFORE INSERT ON goals BEGIN SELECT RAISE(ABORT, 'write failed'); END",
    );
    await expectLater(
      settings.updateSettings(
        settings.currentSettings.copyWith(dailyGoalMl: 3000),
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(settings.currentSettings.dailyGoalMl, 2500);
    expect(history.currentSummaries.single.goalMl, 2500);
    expect(
      (await history.database.query('app_settings')).single['daily_goal_ml'],
      2500,
    );
    await history.database.execute('DROP TRIGGER reject_goal');
    await history.dispose();
    history = await open();
    expect(settings.currentSettings.dailyGoalMl, 2500);
    await settings.updateSettings(
      settings.currentSettings.copyWith(dailyGoalMl: 3000),
    );
    expect(settings.currentSettings.dailyGoalMl, 3000);
    expect(history.currentSummaries.single.goalMl, 3000);
  });

  test(
    'timezone changes preserve all intake and lifetime summary totals',
    () async {
      await history.dispose();
      var offset = 480;
      DateTime localDate(DateTime value) {
        final converted = value.isUtc
            ? value.add(Duration(minutes: offset))
            : value;
        return DateTime(converted.year, converted.month, converted.day);
      }

      Future<SqliteHistoryRepository> openInZone() =>
          SqliteHistoryRepository.open(
            settings: settings,
            factory: databaseFactoryFfi,
            databasePath: getPath(),
            clock: () => now,
            calendarDate: localDate,
          );
      history = await openInZone();
      await history.recordSip(
        SipEvent(
          id: 'travel',
          volumeMl: 120,
          timestamp: DateTime.utc(2026, 10, 14, 1),
        ),
      );
      expect(
        history.currentSummaries.fold<int>(0, (sum, day) => sum + day.totalMl),
        120,
      );
      await history.dispose();
      offset = -420;
      now = DateTime(2026, 10, 16, 12);
      history = await openInZone();
      expect(
        (await history.getSipsForDay(DateTime(2026, 10, 13))).single.volumeMl,
        120,
      );
      expect(
        history.currentSummaries.fold<int>(0, (sum, day) => sum + day.totalMl),
        120,
      );
    },
  );

  test(
    'moving back to an existing date keeps Home and History goals aligned',
    () async {
      await history.recordSip(sip('day-one'));
      now = DateTime(2026, 10, 15, 12);
      await history.checkDayRolloverTrigger();
      await settings.updateSettings(
        settings.currentSettings.copyWith(dailyGoalMl: 3000),
      );
      now = DateTime(2026, 10, 14, 23);
      await history.checkDayRolloverTrigger();
      final today = history.currentSummaries.singleWhere(
        (day) => day.date.day == 14,
      );
      expect(today.goalMl, settings.currentSettings.dailyGoalMl);
      expect(today.goalMl, 3000);
      expect(history.currentTodaySips.single.id, 'day-one');
    },
  );

  test(
    'device progress includes deleted IDs in its replay watermark',
    () async {
      await history.recordSip(sip('device:42'));
      await history.recordSip(sip('device:43', volume: 80));
      await history.deleteSip('device:43');
      final progress = await history.deviceProgress('device');
      expect(progress.totalMl, 120);
      expect(progress.throughSequence, 43);
    },
  );

  test('v1 upgrade retains sips and imports the legacy goal once', () async {
    final legacyPath = '${directory.path}/legacy.db';
    final legacy = await databaseFactoryFfi.openDatabase(
      legacyPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE sips (id TEXT PRIMARY KEY, volume_ml INTEGER NOT NULL, timestamp_ms INTEGER NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, time_estimated INTEGER NOT NULL DEFAULT 0)',
          );
          await db.execute(
            'CREATE TABLE goals (day TEXT PRIMARY KEY, goal_ml INTEGER NOT NULL)',
          );
          await db.insert('goals', {'day': '2026-10-13', 'goal_ml': 2000});
          await db.insert('goals', {'day': '2026-10-14', 'goal_ml': 2000});
          await db.insert('sips', {
            'id': 'existing',
            'volume_ml': 100,
            'timestamp_ms': now.toUtc().millisecondsSinceEpoch,
          });
        },
      ),
    );
    await legacy.close();
    final importedSettings = PreferencesSettingsRepository(
      await SharedPreferences.getInstance(),
    );
    final upgraded = await SqliteHistoryRepository.open(
      settings: importedSettings,
      factory: databaseFactoryFfi,
      databasePath: legacyPath,
      clock: () => now,
    );
    try {
      expect(upgraded.currentTodaySips.single.volumeMl, 100);
      expect(upgraded.currentSummaries.first.goalMl, 2000);
      expect(upgraded.currentSummaries.last.goalMl, 2500);
      await importedSettings.updateSettings(
        importedSettings.currentSettings.copyWith(dailyGoalMl: 3000),
      );
      expect(upgraded.currentSummaries.last.goalMl, 3000);
    } finally {
      await upgraded.dispose();
      importedSettings.dispose();
    }
  });
}
