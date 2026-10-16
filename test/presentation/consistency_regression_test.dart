import 'package:flutter/material.dart';
import '../support/test_providers.dart';
import 'package:liquid_store/data/providers.dart';
import 'package:liquid_store/data/fake/fake_history_repository.dart';
import 'package:liquid_store/data/fake/fake_settings_repository.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:liquid_store/data/local/preferences_settings_repository.dart';
import 'package:liquid_store/data/local/sqlite_history_repository.dart';
import 'package:liquid_store/data/fake/fake_coaster_repository.dart';
import 'package:liquid_store/domain/domain.dart';
import 'package:liquid_store/presentation/home/widgets/beaker_vessel.dart';
import 'package:liquid_store/presentation/view_models/hydration_view_model.dart';

void main() {
  sqfliteFfiInit();
  test('gauge labels match 1000, 2000 and 4000 ml goal fill fractions', () {
    expect(beakerScaleMarks(1000).map((m) => m.label), [
      '1000',
      '750',
      '500',
      '0 ml',
    ]);
    expect(beakerScaleMarks(2000).map((m) => m.label), [
      '2000',
      '1500',
      '1000',
      '0 ml',
    ]);
    expect(beakerScaleMarks(4000).map((m) => m.label), [
      '4000',
      '3000',
      '2000',
      '0 ml',
    ]);
    expect(beakerScaleMarks(4000)[2].ratio, beakerFillScale / 2);
  });
  testWidgets('changing the daily goal updates the actual gauge painter', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = FakeSettingsRepository();
    final history = FakeHistoryRepository(
      initialSips: [],
      initialSummaries: [],
    );
    addTearDown(settings.dispose);
    addTearDown(history.dispose);
    await tester.pumpWidget(
      TestProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          historyRepositoryProvider.overrideWithValue(history),
        ],
        child: const MaterialApp(home: Scaffold(body: BeakerVessel())),
      ),
    );
    await tester.pump();
    final canvas = find.descendant(
      of: find.byType(BeakerVessel),
      matching: find.byType(CustomPaint),
    );
    final oldPainter = tester.widget<CustomPaint>(canvas).painter!;
    expect((oldPainter as dynamic).goalMl, 2000);
    await settings.updateSettings(
      settings.currentSettings.copyWith(dailyGoalMl: 4000),
    );
    await tester.pump();
    final newPainter = tester.widget<CustomPaint>(canvas).painter!;
    expect((newPainter as dynamic).goalMl, 4000);
    expect(newPainter.shouldRepaint(oldPainter), true);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('boss rewards match completed encounters at exact boundaries', () {
    expect(BossRaidStatus.earnedRewardXp(1999), 0);
    expect(BossRaidStatus.earnedRewardXp(2000), 250);
    expect(BossRaidStatus.earnedRewardXp(4499), 250);
    expect(BossRaidStatus.earnedRewardXp(4500), 550);
  });
  test(
    'saved boss rewards survive restart and reverse on intake correction',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = PreferencesSettingsRepository(
        await SharedPreferences.getInstance(),
      );
      final directory = await Directory.systemTemp.createTemp(
        'coaster_rewards_',
      );
      final coaster = FakeCoasterRepository();
      Future<SqliteHistoryRepository> open() => SqliteHistoryRepository.open(
        settings: settings,
        factory: databaseFactoryFfi,
        databasePath: '${directory.path}/history.db',
      );
      var history = await open();
      var vm = HydrationViewModel(
        historyRepository: history,
        settingsRepository: settings,
        coasterRepository: coaster,
      );
      try {
        await history.recordSip(
          SipEvent(
            id: 'boss',
            volumeMl: 2000,
            timestamp: DateTime.now().toUtc(),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(vm.state.totalXp, 500); // 250 intake + 250 completed boss
        expect(vm.state.xpToday, 500);
        expect(vm.state.copyWith(isThirstQuenched: true).totalXp, 500);
        vm.dispose();
        await history.dispose();
        history = await open();
        vm = HydrationViewModel(
          historyRepository: history,
          settingsRepository: settings,
          coasterRepository: coaster,
        );
        expect(vm.state.totalXp, 500);
        await history.recordSip(
          SipEvent(
            id: 'boss',
            volumeMl: 2000,
            timestamp: DateTime.now().toUtc(),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(vm.state.totalXp, 500);
        await history.updateSipVolume('boss', 1000);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(vm.state.totalXp, 125);
        await history.deleteSip('boss');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(vm.state.totalXp, 0);
      } finally {
        vm.dispose();
        await history.dispose();
        settings.dispose();
        coaster.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
}
