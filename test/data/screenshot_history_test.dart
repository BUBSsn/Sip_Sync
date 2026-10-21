import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:liquid_store/data/fake/fake_coaster_repository.dart';
import 'package:liquid_store/data/local/preferences_settings_repository.dart';
import 'package:liquid_store/data/local/screenshot_history_profile.dart';
import 'package:liquid_store/data/local/sqlite_history_repository.dart';
import 'package:liquid_store/domain/domain.dart';
import 'package:liquid_store/presentation/view_models/history_view_model.dart';
import 'package:liquid_store/presentation/view_models/hydration_view_model.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late PreferencesSettingsRepository settings;
  SqliteHistoryRepository? history;
  final now = DateTime(2026, 10, 21, 12);

  Future<SqliteHistoryRepository> open({bool restore = true}) async {
    final result = await SqliteHistoryRepository.open(
      settings: settings,
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/history.db',
      clock: () => now,
      initialDailyTotals: restore ? ScreenshotHistoryProfile.days : const [],
      initialDailyGoalMl: restore ? 1500 : null,
    );
    history = result;
    return result;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = PreferencesSettingsRepository(
      await SharedPreferences.getInstance(),
    );
    directory = await Directory.systemTemp.createTemp('sipsync-screenshot-');
  });
  tearDown(() async {
    await history?.dispose();
    history = null;
    settings.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'two supplied daily totals reproduce the screenshot progression',
    () async {
      final repo = await open();
      expect(repo.initialHistoryRestored, isTrue);
      expect(settings.currentSettings.dailyGoalMl, 1500);
      final recordedDays = repo.currentSummaries
          .where((day) => day.totalMl > 0)
          .toList();
      expect(recordedDays.map((day) => day.totalMl), [1102, 3584]);
      expect(recordedDays.map((day) => day.goalMl), [2000, 2000]);
      expect(
        (recordedDays[0].totalMl / recordedDays[0].goalMl * 100).round(),
        55,
      );
      expect(
        (recordedDays[1].totalMl / recordedDays[1].goalMl * 100).round(),
        179,
      );
      expect(repo.currentTodaySips, isEmpty);
      expect(await repo.getSipsForDay(DateTime(2026, 10, 20)), isEmpty);
      final historyVm = HistoryViewModel(
        historyRepository: repo,
        anchorDate: now,
      );
      final coaster = FakeCoasterRepository();
      final hydrationVm = HydrationViewModel(
        historyRepository: repo,
        settingsRepository: settings,
        coasterRepository: coaster,
      );
      expect(historyVm.state.currentStreakDays, 1);
      expect(historyVm.state.weeklyTotalDisplay, '4.7L');
      expect(historyVm.state.averageIntakeMl, 669);
      expect(hydrationVm.state.level, 5);
      expect(hydrationVm.state.currentLevelXp, 135);
      expect(hydrationVm.state.nextLevelXp, 500);
      expect(hydrationVm.state.bossRaid.act, 3);
      expect(hydrationVm.state.bossRaid.remainingMl, 2814);
      expect(BossRaidStatus.defeatedCount(4686), 2);
      hydrationVm.dispose();
      historyVm.dispose();
      coaster.dispose();
    },
  );

  test(
    'reopening does not duplicate totals and new sips survive normally',
    () async {
      var repo = await open();
      final sip = SipEvent(
        id: 'coaster:1',
        volumeMl: 80,
        timestamp: now.toUtc(),
      );
      expect(await repo.recordHardwareSip(sip), isTrue);
      expect(await repo.recordHardwareSip(sip), isFalse);
      await repo.dispose();
      history = null;
      repo = await open();
      expect(repo.initialHistoryRestored, isFalse);
      expect(
        repo.currentSummaries.fold<int>(0, (sum, day) => sum + day.totalMl),
        4766,
      );
      expect(repo.currentTodaySips.single.volumeMl, 80);
      await repo.deleteSip('coaster:1');
      await repo.dispose();
      history = null;
      repo = await open();
      expect(repo.currentTodaySips, isEmpty);
      expect(
        repo.currentSummaries.fold<int>(0, (sum, day) => sum + day.totalMl),
        4686,
      );
    },
  );

  test(
    'existing installs are never seeded or have their goals replaced',
    () async {
      var repo = await open(restore: false);
      await settings.updateSettings(
        settings.currentSettings.copyWith(dailyGoalMl: 2700),
      );
      await repo.recordSip(
        SipEvent(id: 'existing', volumeMl: 200, timestamp: now.toUtc()),
      );
      await repo.dispose();
      history = null;
      repo = await open();
      expect(repo.initialHistoryRestored, isFalse);
      expect(settings.currentSettings.dailyGoalMl, 2700);
      expect(
        repo.currentSummaries.fold<int>(0, (sum, day) => sum + day.totalMl),
        200,
      );
      expect(repo.currentTodaySips.single.id, 'existing');
    },
  );
}
