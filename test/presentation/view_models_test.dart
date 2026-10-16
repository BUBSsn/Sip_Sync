import '../support/test_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_store/data/fake/fake_coaster_repository.dart';
import 'package:liquid_store/data/fake/fake_history_repository.dart';
import 'package:liquid_store/data/fake/fake_settings_repository.dart';
import 'package:liquid_store/data/providers.dart';
import 'package:liquid_store/domain/domain.dart';
import 'package:liquid_store/presentation/theme/liquid_tokens.dart';
import 'package:liquid_store/presentation/view_models/view_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HydrationViewModel', () {
    test('counts saved intake immediately without cup calibration', () async {
      final history = FakeHistoryRepository(
        initialSips: [],
        initialSummaries: [],
      );
      final container = createTestContainer(
        overrides: [historyRepositoryProvider.overrideWithValue(history)],
      );
      addTearDown(container.dispose);
      addTearDown(history.dispose);
      expect(container.read(hydrationViewModelProvider).currentMl, 0);
      await history.recordSip(
        SipEvent(id: 'real', volumeMl: 250, timestamp: DateTime.now().toUtc()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container.read(hydrationViewModelProvider).currentMl, 250);
      expect(container.read(hydrationViewModelProvider).totalXp, 31);
      container
          .read(hydrationViewModelProvider.notifier)
          .updateScaleTared(false);
      expect(container.read(hydrationViewModelProvider).currentMl, 250);
    });

    test(
      'transitions to fullReservoir when intake exceeds goal (2100/2000ml)',
      () async {
        final historyRepo = FakeHistoryRepository();
        final container = createTestContainer(
          overrides: [
            historyRepositoryProvider.overrideWithValue(historyRepo),
            settingsViewModelProvider.overrideWith(
              (ref) => SettingsViewModel(
                settingsRepository: ref.read(settingsRepositoryProvider),
                coasterRepository: ref.read(coasterRepositoryProvider),
                isScaleTared: true,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(historyRepo.dispose);

        // Pre-warm provider
        container.read(hydrationViewModelProvider);

        // Log a 650 ml sip -> 1450 + 650 = 2100 ml
        await historyRepo.recordSip(
          SipEvent(
            id: 'extra_sip_over_goal',
            volumeMl: 650,
            timestamp: DateTime.now().toUtc(),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final snapshot = container.read(hydrationViewModelProvider);
        // Volume is strictly capped at goalMl (2000ml), raw tracks uncapped intake (2100ml)
        expect(snapshot.currentMl, 2100);
        expect(snapshot.rawCurrentMl, 2100);
        expect(snapshot.progress, 1.0);
        expect(snapshot.isOverGoal, isTrue);
        expect(snapshot.hydrationState, HydrationState.fullReservoir);
        expect(snapshot.stateLabel, 'Full Reservoir');
      },
    );

    test(
      'dynamically updates on mid-day goal change (2000 -> 2500 ml)',
      () async {
        final settingsRepo = FakeSettingsRepository();
        final container = createTestContainer(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
            settingsViewModelProvider.overrideWith(
              (ref) => SettingsViewModel(
                settingsRepository: ref.read(settingsRepositoryProvider),
                coasterRepository: ref.read(coasterRepositoryProvider),
                isScaleTared: true,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(settingsRepo.dispose);

        container.read(hydrationViewModelProvider);

        await settingsRepo.updateSettings(
          settingsRepo.currentSettings.copyWith(dailyGoalMl: 2500),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final snapshot = container.read(hydrationViewModelProvider);
        expect(snapshot.goalMl, 2500);
        expect(snapshot.progress, 1450 / 2500);
        expect(snapshot.progress, 0.58);
        expect(
          snapshot.hydrationState,
          HydrationState.optimalFlow,
        ); // 58% is optimalFlow (50%-79%)
      },
    );

    test(
      'triggers transient thirstQuenched state and resets after timer',
      () async {
        final coasterRepo = FakeCoasterRepository();
        final container = createTestContainer(
          overrides: [
            coasterRepositoryProvider.overrideWithValue(coasterRepo),
            settingsViewModelProvider.overrideWith(
              (ref) => SettingsViewModel(
                settingsRepository: ref.read(settingsRepositoryProvider),
                coasterRepository: ref.read(coasterRepositoryProvider),
                isScaleTared: true,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(coasterRepo.dispose);

        container.read(hydrationViewModelProvider);

        coasterRepo.simulateSip(50);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        var snapshot = container.read(hydrationViewModelProvider);
        expect(snapshot.isThirstQuenched, isTrue);
        expect(snapshot.hydrationState, HydrationState.thirstQuenched);
        expect(snapshot.stateLabel, 'Thirst Quenched');

        // Wait for the 3s quench timer to elapse
        await Future<void>.delayed(
          LiquidTokens.durationThirstQuenched +
              const Duration(milliseconds: 50),
        );

        snapshot = container.read(hydrationViewModelProvider);
        expect(snapshot.isThirstQuenched, isFalse);
        expect(snapshot.hydrationState, HydrationState.optimalFlow);
      },
    );

    test('rapid consecutive sips restart the thirstQuenched timer', () async {
      final coasterRepo = FakeCoasterRepository();
      final container = createTestContainer(
        overrides: [
          coasterRepositoryProvider.overrideWithValue(coasterRepo),
          settingsViewModelProvider.overrideWith(
            (ref) => SettingsViewModel(
              settingsRepository: ref.read(settingsRepositoryProvider),
              coasterRepository: ref.read(coasterRepositoryProvider),
              isScaleTared: true,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(coasterRepo.dispose);

      container.read(hydrationViewModelProvider);

      coasterRepo.simulateSip(40);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        container.read(hydrationViewModelProvider).isThirstQuenched,
        isTrue,
      );

      // 1.5 seconds later, second sip arrives (restarting the 3s timer)
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      coasterRepo.simulateSip(60);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        container.read(hydrationViewModelProvider).isThirstQuenched,
        isTrue,
      );

      // 2 seconds later (3.5s after first sip, but 2s after second sip): still quenched!
      await Future<void>.delayed(const Duration(milliseconds: 2000));
      expect(
        container.read(hydrationViewModelProvider).isThirstQuenched,
        isTrue,
      );

      // Wait another 1.5s (3.5s after second sip): now reverted
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(
        container.read(hydrationViewModelProvider).isThirstQuenched,
        isFalse,
      );
    });

    test(
      'resets currentMl to 0 when watchTodaySips emits empty list (day rollover)',
      () async {
        final historyRepo = FakeHistoryRepository();
        final container = createTestContainer(
          overrides: [historyRepositoryProvider.overrideWithValue(historyRepo)],
        );
        addTearDown(container.dispose);
        addTearDown(historyRepo.dispose);

        container.read(hydrationViewModelProvider);

        // Simulate day rollover by replacing today's sips with empty list
        await historyRepo.replaceTodaySips([]);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final snapshot = container.read(hydrationViewModelProvider);
        expect(snapshot.currentMl, 0);
        expect(snapshot.rawCurrentMl, 0);
        expect(snapshot.progress, 0.0);
        expect(snapshot.level, greaterThan(1));
        expect(
          snapshot.totalXp,
          historyRepo.currentSummaries.fold<int>(
                    0,
                    (sum, day) => sum + day.totalMl,
                  ) ~/
                  8 +
              BossRaidStatus.earnedRewardXp(
                historyRepo.currentSummaries.fold<int>(
                  0,
                  (sum, day) => sum + day.totalMl,
                ),
              ),
        );
        expect(snapshot.hydrationState, HydrationState.gettingStarted);
      },
    );

    test(
      'derives XP, Level, and remainingMl accurately starting from Level 1 with progressive scaling',
      () {
        // 0 ml intake: starts at Level 1 with 0 XP, needs 100 XP for next level (easy)
        final startState = HydrationSnapshot(
          currentMl: 0,
          goalMl: 2000,
          progress: 0.0,
          hydrationState: HydrationState.gettingStarted,
          stateLabel: 'Just Getting Started',
          isOverGoal: false,
          isThirstQuenched: false,
        );
        expect(startState.level, 1);
        expect(startState.currentLevelXp, 0);
        expect(startState.nextLevelXp, 100);
        expect(startState.totalXp, 0);
        expect(startState.remainingMl, 2000);
        expect(startState.bossRaid.act, 1);
        expect(startState.bossRaid.actName, 'ACT I');

        // Exactly reaching level 2 threshold (100 XP -> 800 ml intake: 800 ~/ 8 = 100 XP)
        // Level 1 is easy to beat (only 100 XP).
        // Level becomes 2, currentLevelXp resets to 0, nextLevelXp increases to 200 (harder!)
        final level2Threshold = HydrationSnapshot(
          currentMl: 800,
          goalMl: 2000,
          progress: 800 / 2000,
          hydrationState: HydrationState.steadyStream,
          stateLabel: 'Steady Stream',
          isOverGoal: false,
          isThirstQuenched: false,
        );
        expect(level2Threshold.totalXp, 100);
        expect(level2Threshold.level, 2);
        expect(
          level2Threshold.currentLevelXp,
          0,
        ); // XP resets to 0 when reaching another level!
        expect(
          level2Threshold.nextLevelXp,
          200,
        ); // Level 2 takes longer: 200 XP!

        // 1445 ml intake: totalXp = 1445 ~/ 8 = 180 XP -> Level 2, (180 - 100) = 80 XP
        final state = HydrationSnapshot(
          currentMl: 1445,
          goalMl: 2500,
          progress: 1445 / 2500,
          hydrationState: HydrationState.optimalFlow,
          stateLabel: 'Optimal Flow',
          isOverGoal: false,
          isThirstQuenched: false,
        );

        expect(state.xpToday, 180);
        expect(state.totalXp, 180);
        expect(state.level, 2);
        expect(state.currentLevelXp, 80);
        expect(state.nextLevelXp, 200);
        expect(state.remainingMl, 1055);

        // Level 3 threshold (100 + 200 = 300 XP -> 2400 ml intake)
        // Level becomes 3, currentLevelXp resets to 0, nextLevelXp increases to 300 (even harder!)
        final level3Threshold = HydrationSnapshot(
          currentMl: 2000,
          rawCurrentMl: 2400,
          goalMl: 2000,
          progress: 1.0,
          hydrationState: HydrationState.fullReservoir,
          stateLabel: 'Full Reservoir',
          isOverGoal: true,
          isThirstQuenched: false,
        );
        expect(level3Threshold.totalXp, 300);
        expect(level3Threshold.level, 3);
        expect(level3Threshold.currentLevelXp, 0); // XP resets to 0!
        expect(
          level3Threshold.nextLevelXp,
          300,
        ); // Level 3 takes even longer: 300 XP!

        // Over goal: remainingMl clamps to 0, currentMl does not exceed goal
        final overState = HydrationSnapshot(
          currentMl: 2500,
          rawCurrentMl: 2600,
          goalMl: 2500,
          progress: 1.0,
          hydrationState: HydrationState.fullReservoir,
          stateLabel: 'Full Reservoir',
          isOverGoal: true,
          isThirstQuenched: false,
        );
        expect(overState.currentMl, 2500); // capped at goal
        expect(overState.rawCurrentMl, 2600);
        expect(overState.remainingMl, 0);
        // totalXp = 2600 ~/ 8 = 325 XP -> Level 3 (300 XP consumed by L1 + L2), 25 XP into Level 3
        expect(overState.totalXp, 325);
        expect(overState.level, 3);
        expect(overState.currentLevelXp, 25);
        expect(overState.nextLevelXp, 300);

        // Verify that calculateLevelProgress scales progressively harder
        final l1 = HydrationSnapshot.calculateLevelProgress(0);
        expect(l1.level, 1);
        expect(l1.nextLevelXp, 100);

        final l2 = HydrationSnapshot.calculateLevelProgress(100);
        expect(l2.level, 2);
        expect(l2.nextLevelXp, 200);

        final l3 = HydrationSnapshot.calculateLevelProgress(300);
        expect(l3.level, 3);
        expect(l3.nextLevelXp, 300);

        final l4 = HydrationSnapshot.calculateLevelProgress(600);
        expect(l4.level, 4);
        expect(l4.nextLevelXp, 400);

        final l5 = HydrationSnapshot.calculateLevelProgress(1000);
        expect(l5.level, 5);
        expect(l5.nextLevelXp, 500);
      },
    );

    test(
      'boss raid scales across acts with increasing HP and resets on knockout',
      () {
        // Act 1: 0 - 1999 ml damage (Max HP 2000 ml)
        final act1 = BossRaidStatus.calculate(0);
        expect(act1.act, 1);
        expect(act1.actName, 'ACT I');
        expect(act1.maxHp, 2000);
        expect(act1.currentHp, 0);
        expect(act1.remainingMl, 2000);
        expect(act1.progress, 0.0);

        final act1Halfway = BossRaidStatus.calculate(1000);
        expect(act1Halfway.act, 1);
        expect(act1Halfway.currentHp, 1000);
        expect(act1Halfway.remainingMl, 1000);
        expect(act1Halfway.progress, 0.5);

        // Act 2: Exactly 2000 ml beats Act 1 -> advances to Act 2!
        // Act 2 has 2500 ml max HP, damage resets to 0 for Act 2
        final act2Start = BossRaidStatus.calculate(2000);
        expect(act2Start.act, 2);
        expect(act2Start.actName, 'ACT II');
        expect(act2Start.maxHp, 2500);
        expect(act2Start.currentHp, 0); // resets
        expect(act2Start.remainingMl, 2500);
        expect(act2Start.progress, 0.0);

        // Act 2 with 500 ml into the act (2500 ml total)
        final act2Mid = BossRaidStatus.calculate(2500);
        expect(act2Mid.act, 2);
        expect(act2Mid.currentHp, 500);
        expect(act2Mid.remainingMl, 2000);
        expect(act2Mid.progress, 0.2);

        // Act 3: 2000 (Act 1) + 2500 (Act 2) = 4500 ml -> advances to Act 3!
        // Act 3 has 3000 ml max HP
        final act3Start = BossRaidStatus.calculate(4500);
        expect(act3Start.act, 3);
        expect(act3Start.actName, 'ACT III');
        expect(act3Start.maxHp, 3000);
        expect(act3Start.currentHp, 0);
        expect(act3Start.remainingMl, 3000);
      },
    );
  });

  group('SipFeedbackViewModel', () {
    test('initial state has null latestSip and false active feedback', () {
      final coasterRepo = FakeCoasterRepository();
      final container = createTestContainer(
        overrides: [coasterRepositoryProvider.overrideWithValue(coasterRepo)],
      );
      addTearDown(container.dispose);
      addTearDown(coasterRepo.dispose);

      final feedback = container.read(sipFeedbackViewModelProvider);
      expect(feedback.latestSip, isNull);
      expect(feedback.mergedVolumeMl, 0);
      expect(feedback.timestamp, isNull);
      expect(feedback.hasActiveFeedback, isFalse);
      expect(feedback.comboCount, 0);
    });

    test(
      'increments comboCount across consecutive sips within 2-minute window',
      () async {
        final coasterRepo = FakeCoasterRepository();
        final container = createTestContainer(
          overrides: [coasterRepositoryProvider.overrideWithValue(coasterRepo)],
        );
        addTearDown(container.dispose);
        addTearDown(coasterRepo.dispose);

        container.read(sipFeedbackViewModelProvider);

        final now = DateTime.now().toUtc().subtract(
          const Duration(seconds: 45),
        );
        coasterRepo.simulateSip(40, now);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        var feedback = container.read(sipFeedbackViewModelProvider);
        expect(feedback.comboCount, 1);

        // 2nd sip within 2 minutes
        coasterRepo.simulateSip(30, now.add(const Duration(seconds: 30)));
        await Future<void>.delayed(const Duration(milliseconds: 20));

        feedback = container.read(sipFeedbackViewModelProvider);
        expect(feedback.comboCount, 2);

        // 3rd sip within 2 minutes
        coasterRepo.simulateSip(50, now.add(const Duration(seconds: 40)));
        await Future<void>.delayed(const Duration(milliseconds: 20));

        feedback = container.read(sipFeedbackViewModelProvider);
        expect(feedback.comboCount, 3);
      },
    );

    test('merges consecutive sips into aggregated feedback event', () async {
      final coasterRepo = FakeCoasterRepository();
      final container = createTestContainer(
        overrides: [coasterRepositoryProvider.overrideWithValue(coasterRepo)],
      );
      addTearDown(container.dispose);
      addTearDown(coasterRepo.dispose);

      container.read(sipFeedbackViewModelProvider);

      final now = DateTime.now().toUtc().subtract(const Duration(seconds: 45));
      coasterRepo.simulateSip(40, now);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      var feedback = container.read(sipFeedbackViewModelProvider);
      expect(feedback.hasActiveFeedback, isTrue);
      expect(feedback.mergedVolumeMl, 40);

      // Immediate subsequent sip within merge window (e.g. 15s later)
      coasterRepo.simulateSip(60, now.add(const Duration(seconds: 15)));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      feedback = container.read(sipFeedbackViewModelProvider);
      expect(feedback.hasActiveFeedback, isTrue);
      expect(feedback.mergedVolumeMl, 100); // 40 + 60 merged
    });

    test('clearFeedback manually deactivates feedback', () async {
      final coasterRepo = FakeCoasterRepository();
      final container = createTestContainer(
        overrides: [coasterRepositoryProvider.overrideWithValue(coasterRepo)],
      );
      addTearDown(container.dispose);
      addTearDown(coasterRepo.dispose);

      final vm = container.read(sipFeedbackViewModelProvider.notifier);
      coasterRepo.simulateSip(50);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        container.read(sipFeedbackViewModelProvider).hasActiveFeedback,
        isTrue,
      );
      vm.clearFeedback();
      expect(
        container.read(sipFeedbackViewModelProvider).hasActiveFeedback,
        isFalse,
      );
    });
  });

  group('FreshnessViewModel', () {
    test(
      'tracks elapsed duration and derives freshness phase from seed data',
      () {
        final container = createTestContainer();
        addTearDown(container.dispose);

        final state = container.read(freshnessViewModelProvider);
        expect(state.threshold, const Duration(minutes: 45));
        expect(state.lastSipTime, isNotNull);
        expect(state.elapsedDisplay, isNotEmpty);
      },
    );

    test(
      'calculates fresh, fading, and dry phases based on elapsed duration',
      () {
        final threshold = const Duration(minutes: 45);

        // 0 min -> fresh
        expect(
          getFreshnessPhase(Duration.zero, threshold),
          FreshnessPhase.fresh,
        );

        // 22.5 min (1350 sec) -> fresh (exactly 50%)
        expect(
          getFreshnessPhase(const Duration(seconds: 1350), threshold),
          FreshnessPhase.fresh,
        );

        // 23 min -> fading
        expect(
          getFreshnessPhase(const Duration(minutes: 23), threshold),
          FreshnessPhase.fading,
        );

        // 46 min -> dry
        expect(
          getFreshnessPhase(const Duration(minutes: 46), threshold),
          FreshnessPhase.dry,
        );
      },
    );

    test('reflects dry phase and No sips yet when history is empty', () {
      final emptyHistoryRepo = FakeHistoryRepository(
        initialSips: [],
        initialSummaries: [],
      );
      final container = createTestContainer(
        overrides: [
          historyRepositoryProvider.overrideWithValue(emptyHistoryRepo),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(emptyHistoryRepo.dispose);

      final state = container.read(freshnessViewModelProvider);
      expect(state.phase, FreshnessPhase.dry);
      expect(state.elapsedDisplay, 'No sips yet');
      expect(state.lastSipTime, isNull);
    });
  });

  group('ConnectionViewModel', () {
    test('synchronously snapshots initial connection state from repo', () {
      final coasterRepo = FakeCoasterRepository();
      // Even without running the event loop, initial state is connected
      final container = createTestContainer(
        overrides: [coasterRepositoryProvider.overrideWithValue(coasterRepo)],
      );
      addTearDown(container.dispose);
      addTearDown(coasterRepo.dispose);

      final state = container.read(connectionViewModelProvider);
      expect(state.isConnected, isTrue);
      expect(state.label, 'Connected');
    });

    test('updates on connection stream changes', () async {
      final coasterRepo = FakeCoasterRepository();
      final container = createTestContainer(
        overrides: [coasterRepositoryProvider.overrideWithValue(coasterRepo)],
      );
      addTearDown(container.dispose);
      addTearDown(coasterRepo.dispose);

      container.read(connectionViewModelProvider);

      coasterRepo.simulateConnection(ConnectionStatus.disconnected);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(container.read(connectionViewModelProvider).isConnected, isFalse);
      expect(container.read(connectionViewModelProvider).label, 'Disconnected');
    });
  });

  group('HistoryViewModel', () {
    test(
      'derives 7-day columns, weekly total 12.9L, 5-day best streak, and 1843ml average',
      () {
        final container = createTestContainer();
        addTearDown(container.dispose);

        final history = HistoryViewModel(
          historyRepository: container.read(historyRepositoryProvider),
          anchorDate: DateTime.now().subtract(const Duration(days: 1)),
        ).state;
        expect(history.isEmpty, isFalse);
        expect(history.weeklyColumns.length, 7);
        expect(history.weeklyTotalDisplay, '12.9L');
        // 12900 ml / 7 = 1842.86 -> 1843 ml
        expect(history.averageIntakeMl, 1843);
        expect(history.bestStreakDays, 5);
        expect(history.archiveEntries, isNotEmpty);

        // Verify reference archive row status text and seal tiers
        final monday = history.archiveEntries.firstWhere(
          (e) => e.totalMl == 2100,
        );
        expect(monday.sealTier, SealTier.goalMet);
        expect(monday.statusText, 'Goal Met!');

        final sunday = history.archiveEntries.firstWhere(
          (e) => e.totalMl == 1950,
        );
        expect(sunday.sealTier, SealTier.almostThere);
        expect(sunday.statusText, 'Almost there!');

        final tuesday = history.archiveEntries.firstWhere(
          (e) => e.totalMl == 1200,
        );
        expect(tuesday.sealTier, SealTier.underGoal);
      },
    );

    test('handles completely empty summaries gracefully', () {
      final emptyHistoryRepo = _MockEmptyHistoryRepository();
      final container = createTestContainer(
        overrides: [
          historyRepositoryProvider.overrideWithValue(emptyHistoryRepo),
        ],
      );
      addTearDown(container.dispose);

      final history = container.read(historyViewModelProvider);
      expect(history.isEmpty, isTrue);
      expect(history.weeklyColumns, isEmpty);
      expect(history.averageIntakeMl, 0);
      expect(history.weeklyTotalDisplay, '0.0L');
      expect(history.bestStreakDays, 0);
      expect(history.archiveEntries, isEmpty);
    });

    test('handles brand new user history with zero sips gracefully', () {
      final freshRepo = FakeHistoryRepository(
        initialSips: [],
        initialSummaries: [],
      );
      final container = createTestContainer(
        overrides: [historyRepositoryProvider.overrideWithValue(freshRepo)],
      );
      addTearDown(container.dispose);
      addTearDown(freshRepo.dispose);

      final history = container.read(historyViewModelProvider);
      expect(history.isEmpty, isTrue);
      expect(history.weeklyColumns, isEmpty);
      expect(history.averageIntakeMl, 0);
      expect(history.weeklyTotalDisplay, '0.0L');
      expect(history.bestStreakDays, 0);
    });
  });

  group('SettingsViewModel', () {
    test('updates daily goal and inactivity threshold', () async {
      final container = createTestContainer();
      addTearDown(container.dispose);

      final vm = container.read(settingsViewModelProvider.notifier);
      await vm.updateDailyGoal(2500);
      await vm.updateInactivityThreshold(60);
      await vm.toggleAdaptiveReminders(false);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = container.read(settingsViewModelProvider);
      expect(state.dailyGoalMl, 2500);
      expect(state.inactivityThresholdMinutes, 60);
      expect(state.adaptiveRemindersEnabled, isFalse);
    });

    test('tare ritual steps through prompt -> measuring -> success', () async {
      final container = createTestContainer();
      addTearDown(container.dispose);

      final vm = container.read(settingsViewModelProvider.notifier);
      expect(
        container.read(settingsViewModelProvider).tareState,
        TareState.idle,
      );

      vm.promptTare();
      expect(
        container.read(settingsViewModelProvider).tareState,
        TareState.prompting,
      );

      final calibrationFuture = vm.confirmTare();
      expect(
        container.read(settingsViewModelProvider).tareState,
        TareState.measuring,
      );

      await calibrationFuture;
      expect(
        container.read(settingsViewModelProvider).tareState,
        TareState.success,
      );
      expect(container.read(settingsViewModelProvider).calibratedGrams, 350.0);

      vm.resetTare();
      expect(
        container.read(settingsViewModelProvider).tareState,
        TareState.idle,
      );
    });

    test('handles calibration failure with error message', () async {
      final coasterRepo = FakeCoasterRepository();
      coasterRepo.setNextCalibrationOutcome(
        status: CalibrationStatus.failure,
        errorMessage: 'Unstable surface detected',
      );
      final container = createTestContainer(
        overrides: [coasterRepositoryProvider.overrideWithValue(coasterRepo)],
      );
      addTearDown(container.dispose);
      addTearDown(coasterRepo.dispose);

      final vm = container.read(settingsViewModelProvider.notifier);
      await vm.confirmTare();

      final state = container.read(settingsViewModelProvider);
      expect(state.tareState, TareState.failure);
      expect(state.tareErrorMessage, 'Unstable surface detected');

      vm.cancelTare();
      expect(
        container.read(settingsViewModelProvider).tareState,
        TareState.idle,
      );
    });

    test('handles calibration timeout with error message', () async {
      final coasterRepo = FakeCoasterRepository();
      coasterRepo.setNextCalibrationOutcome(
        status: CalibrationStatus.timeout,
        errorMessage: 'Hardware tare timed out',
      );
      final container = createTestContainer(
        overrides: [coasterRepositoryProvider.overrideWithValue(coasterRepo)],
      );
      addTearDown(container.dispose);
      addTearDown(coasterRepo.dispose);

      final vm = container.read(settingsViewModelProvider.notifier);
      await vm.confirmTare();

      final state = container.read(settingsViewModelProvider);
      expect(state.tareState, TareState.timeout);
      expect(state.tareErrorMessage, 'Hardware tare timed out');
    });

    test(
      'adjustPortionLimit adjusts value, clamps to 50..500 bounds, and persists',
      () async {
        final settingsRepo = FakeSettingsRepository();
        final container = createTestContainer(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(settingsRepo.dispose);

        final vm = container.read(settingsViewModelProvider.notifier);
        expect(container.read(settingsViewModelProvider).portionLimitMl, 250);

        // Increment by 50 -> 300
        await vm.adjustPortionLimit(50);
        expect(container.read(settingsViewModelProvider).portionLimitMl, 300);
        expect(settingsRepo.currentSettings.portionLimitMl, 300);

        // Decrement by 50 -> 250
        await vm.adjustPortionLimit(-50);
        expect(container.read(settingsViewModelProvider).portionLimitMl, 250);

        // Decrement past minimum (50) -> clamps to 50
        await vm.adjustPortionLimit(-300);
        expect(container.read(settingsViewModelProvider).portionLimitMl, 50);

        // Increment past maximum (500) -> clamps to 500
        await vm.adjustPortionLimit(600);
        expect(container.read(settingsViewModelProvider).portionLimitMl, 500);
      },
    );
  });

  group(
    'Cup Empty Detection & Water Volume (isCupEmptyProvider & cupWaterVolumeMlProvider)',
    () {
      test('reports cup as empty when no cup is on the coaster (< 100g)', () {
        final coasterRepo = FakeCoasterRepository(initialWeightGrams: 0.0);
        final container = createTestContainer(
          overrides: [coasterRepositoryProvider.overrideWithValue(coasterRepo)],
        );
        addTearDown(container.dispose);
        addTearDown(coasterRepo.dispose);

        expect(container.read(isCupEmptyProvider), isTrue);
        expect(container.read(cupWaterVolumeMlProvider), 0);
      });

      test(
        'reports cup as empty when weight matches fixed empty cup weight (258g)',
        () {
          final coasterRepo = FakeCoasterRepository(initialWeightGrams: 258.0);
          final container = createTestContainer(
            overrides: [
              coasterRepositoryProvider.overrideWithValue(coasterRepo),
            ],
          );
          addTearDown(container.dispose);
          addTearDown(coasterRepo.dispose);

          expect(container.read(isCupEmptyProvider), isTrue);
          expect(container.read(cupWaterVolumeMlProvider), 0);
        },
      );

      test(
        'reports cup as empty with minor sensor jitter (<= 5g over tare)',
        () {
          final coasterRepo = FakeCoasterRepository(initialWeightGrams: 262.0);
          final container = createTestContainer(
            overrides: [
              coasterRepositoryProvider.overrideWithValue(coasterRepo),
            ],
          );
          addTearDown(container.dispose);
          addTearDown(coasterRepo.dispose);

          expect(container.read(isCupEmptyProvider), isTrue);
          expect(container.read(cupWaterVolumeMlProvider), 4);
        },
      );

      test(
        'reports cup as not empty when water is present and calculates volume',
        () {
          final coasterRepo = FakeCoasterRepository(initialWeightGrams: 508.0);
          final container = createTestContainer(
            overrides: [
              coasterRepositoryProvider.overrideWithValue(coasterRepo),
            ],
          );
          addTearDown(container.dispose);
          addTearDown(coasterRepo.dispose);

          expect(container.read(isCupEmptyProvider), isFalse);
          expect(container.read(cupWaterVolumeMlProvider), 250);
        },
      );

      test(
        'refillCup adds water volume and transitions isCupEmpty to false',
        () async {
          final coasterRepo = FakeCoasterRepository(initialWeightGrams: 258.0);
          final container = createTestContainer(
            overrides: [
              coasterRepositoryProvider.overrideWithValue(coasterRepo),
            ],
          );
          addTearDown(container.dispose);
          addTearDown(coasterRepo.dispose);

          expect(container.read(isCupEmptyProvider), isTrue);
          expect(container.read(cupWaterVolumeMlProvider), 0);

          coasterRepo.refillCup(300);
          await Future<void>.delayed(const Duration(milliseconds: 20));

          expect(container.read(isCupEmptyProvider), isFalse);
          expect(container.read(cupWaterVolumeMlProvider), 300);
        },
      );
    },
  );
}

class _MockEmptyHistoryRepository implements HistoryRepository {
  @override
  List<DailySummary> get currentSummaries => [];

  @override
  List<SipEvent> get currentTodaySips => [];

  @override
  Future<void> deleteSip(String sipId) async {}

  @override
  Future<List<DailySummary>> getDailySummaries({
    DateTime? start,
    DateTime? end,
  }) async => [];

  @override
  Future<List<SipEvent>> getSipsForDay(DateTime date) async => [];

  @override
  Future<void> recordSip(SipEvent sip) async {}

  @override
  Future<void> updateSipVolume(String sipId, int newVolumeMl) async {}

  @override
  Stream<List<DailySummary>> watchDailySummaries() => const Stream.empty();

  @override
  Stream<List<SipEvent>> watchTodaySips() => const Stream.empty();

  @override
  Future<void> checkDayRolloverTrigger([DateTime? now]) async {}
}
