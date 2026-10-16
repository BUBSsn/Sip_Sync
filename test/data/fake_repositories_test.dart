import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_store/data/fake/fake_coaster_repository.dart';
import 'package:liquid_store/data/fake/fake_history_repository.dart';
import 'package:liquid_store/data/fake/fake_settings_repository.dart';
import 'package:liquid_store/domain/domain.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FakeCoasterRepository', () {
    late FakeCoasterRepository repo;

    setUp(() {
      repo = FakeCoasterRepository();
    });

    tearDown(() {
      repo.dispose();
    });

    test('initial state is connected with 350g cup weight', () {
      expect(repo.currentConnection.isConnected, isTrue);
      expect(repo.lastReading?.grams, 350.0);
    });

    test('simulateSip emits event and decrements cup weight', () async {
      final sipFuture = repo.sipStream.first;
      final weightFuture = repo.weightStream.first;

      repo.simulateSip(50);

      final sip = await sipFuture;
      final weight = await weightFuture;

      expect(sip.volumeMl, 50);
      expect(weight.grams, 300.0); // 350 - 50 = 300g
      expect(repo.lastReading?.grams, 300.0);
    });

    test(
      'simulateWeightChange emits reading and updates lastReading',
      () async {
        final weightFuture = repo.weightStream.first;

        repo.simulateWeightChange(420.5);

        final reading = await weightFuture;
        expect(reading.grams, 420.5);
        expect(repo.lastReading?.grams, 420.5);
      },
    );

    test('simulateConnection emits status updates', () async {
      final connFuture = repo.connectionStream.first;

      repo.simulateConnection(ConnectionStatus.disconnected);

      final conn = await connFuture;
      expect(conn.status, ConnectionStatus.disconnected);
      expect(repo.currentConnection.isConnected, isFalse);
    });

    test('calibrate performs tare and returns success by default', () async {
      final result = await repo.calibrate();

      expect(result.isSuccess, isTrue);
      expect(result.status, CalibrationStatus.success);
      expect(result.measuredGrams, 350.0);
    });

    test('simulate calibration failure and timeout outcomes', () async {
      repo.setNextCalibrationOutcome(
        status: CalibrationStatus.failure,
        errorMessage: 'Scale unstable',
      );

      final failResult = await repo.calibrate();
      expect(failResult.status, CalibrationStatus.failure);
      expect(failResult.errorMessage, 'Scale unstable');

      repo.setNextCalibrationOutcome(
        status: CalibrationStatus.timeout,
        errorMessage: 'Timed out waiting for tare',
      );

      final timeoutResult = await repo.calibrate();
      expect(timeoutResult.status, CalibrationStatus.timeout);
      expect(timeoutResult.errorMessage, 'Timed out waiting for tare');
    });
  });

  group('FakeSettingsRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('reads defaults when storage is empty', () async {
      final repo = FakeSettingsRepository();
      final settings = await repo.getSettings();

      expect(settings.dailyGoalMl, 2000);
      expect(settings.inactivityThresholdMinutes, 45);
      expect(settings.adaptiveRemindersEnabled, isTrue);
      repo.dispose();
    });

    test('persists updates and notifies stream', () async {
      final repo = FakeSettingsRepository();
      await repo.getSettings();

      final streamFuture = repo.watchSettings().first;

      const newSettings = UserSettings(
        dailyGoalMl: 2500,
        inactivityThresholdMinutes: 60,
        adaptiveRemindersEnabled: false,
      );

      await repo.updateSettings(newSettings);

      final streamed = await streamFuture;
      expect(streamed.dailyGoalMl, 2500);
      expect(streamed.inactivityThresholdMinutes, 60);
      expect(streamed.adaptiveRemindersEnabled, isFalse);

      // Verify persistence in a fresh repository instance
      final freshRepo = FakeSettingsRepository();
      final loaded = await freshRepo.getSettings();
      expect(loaded.dailyGoalMl, 2500);
      expect(loaded.inactivityThresholdMinutes, 60);
      expect(loaded.adaptiveRemindersEnabled, isFalse);

      repo.dispose();
      freshRepo.dispose();
    });
  });

  group('FakeHistoryRepository & SeedData', () {
    final anchor = DateTime(2026, 10, 9); // Anchor date for testing
    late FakeHistoryRepository repo;

    setUp(() {
      repo = FakeHistoryRepository(anchorDate: anchor);
    });

    tearDown(() {
      repo.dispose();
    });

    test('seeds today intake matching 1450 ml with reference sips', () async {
      final todaySips = await repo.getSipsForDay(anchor);

      // Total ml must equal exactly 1450 ml
      final total = todaySips.fold<int>(0, (sum, s) => sum + s.volumeMl);
      expect(total, 1450);

      // Contains reference sips
      expect(todaySips.any((s) => s.volumeMl == 120), isTrue); // 11:15 sip
      expect(todaySips.any((s) => s.volumeMl == 45), isTrue); // 10:30 sip
      expect(todaySips.any((s) => s.volumeMl == 250), isTrue); // 08:00 sip
    });

    test(
      'seeds history matching reference figures (2100ml, 1950ml, 1600ml, best streak 5)',
      () async {
        final summaries = await repo.getDailySummaries();

        // Verify reference days exist
        expect(
          summaries.any((s) => s.totalMl == 2100 && s.isGoalMet),
          isTrue,
        ); // Monday
        expect(
          summaries.any((s) => s.totalMl == 1950 && !s.isGoalMet),
          isTrue,
        ); // Sunday
        expect(
          summaries.any((s) => s.totalMl == 1600 && !s.isGoalMet),
          isTrue,
        ); // Saturday

        // Verify 7-day weekly total of the completed week is 12.9L (12,900 ml)
        final weekDays = summaries.sublist(
          summaries.length - 8,
          summaries.length - 1,
        );
        final weekTotal = weekDays.fold<int>(0, (sum, s) => sum + s.totalMl);
        expect(weekTotal, 12900); // 12.9 L

        // Calculate streak on seed history
        final streak = calculateStreaks(summaries, today: anchor);
        expect(streak.bestStreak, 5); // Best streak of 5 days
      },
    );

    test('recordSip adds sip and updates daily summary total', () async {
      final initialTodaySips = await repo.getSipsForDay(anchor);
      final initialTotal = initialTodaySips.fold<int>(
        0,
        (sum, s) => sum + s.volumeMl,
      );
      expect(initialTotal, 1450);

      final newSip = SipEvent(
        id: 'new_sip_1',
        volumeMl: 100,
        timestamp: DateTime.now().toUtc(),
      );

      await repo.recordSip(newSip);

      final updatedSips = await repo.getSipsForDay(anchor);
      expect(updatedSips.length, initialTodaySips.length + 1);
      expect(updatedSips.first.id, 'new_sip_1');

      final summaries = await repo.getDailySummaries();
      final todaySummary = summaries.firstWhere(
        (s) => normalizeDate(s.date).isAtSameMomentAs(anchor),
      );
      expect(todaySummary.totalMl, 1550); // 1450 + 100
    });

    test('deleteSip removes sip and recalculates summary total', () async {
      final initialSips = await repo.getSipsForDay(anchor);
      final sipToDelete = initialSips.first;

      await repo.deleteSip(sipToDelete.id);

      final updatedSips = await repo.getSipsForDay(anchor);
      expect(updatedSips.length, initialSips.length - 1);
      expect(updatedSips.any((s) => s.id == sipToDelete.id), isFalse);

      final summaries = await repo.getDailySummaries();
      final todaySummary = summaries.firstWhere(
        (s) => normalizeDate(s.date).isAtSameMomentAs(anchor),
      );
      expect(todaySummary.totalMl, 1450 - sipToDelete.volumeMl);
    });

    test('updateSipVolume modifies volume and recalculates summary', () async {
      final initialSips = await repo.getSipsForDay(anchor);
      final sipToEdit = initialSips.first;
      final diff = 80 - sipToEdit.volumeMl;

      await repo.updateSipVolume(sipToEdit.id, 80);

      final summaries = await repo.getDailySummaries();
      final todaySummary = summaries.firstWhere(
        (s) => normalizeDate(s.date).isAtSameMomentAs(anchor),
      );
      expect(todaySummary.totalMl, 1450 + diff);
    });
  });
}
