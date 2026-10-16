import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_store/domain/domain.dart';

void main() {
  group('getHydrationState', () {
    test('returns gettingStarted for 0% to 24%', () {
      expect(getHydrationState(0, 2000), HydrationState.gettingStarted);
      expect(getHydrationState(100, 2000), HydrationState.gettingStarted);
      expect(
        getHydrationState(499, 2000),
        HydrationState.gettingStarted,
      ); // 24.95%
    });

    test('returns steadyStream at exactly 25% up to 49%', () {
      expect(
        getHydrationState(500, 2000),
        HydrationState.steadyStream,
      ); // exactly 25%
      expect(
        getHydrationState(999, 2000),
        HydrationState.steadyStream,
      ); // 49.95%
    });

    test('returns optimalFlow at exactly 50% up to 79%', () {
      expect(
        getHydrationState(1000, 2000),
        HydrationState.optimalFlow,
      ); // exactly 50%
      expect(
        getHydrationState(1599, 2000),
        HydrationState.optimalFlow,
      ); // 79.95%
    });

    test('returns nearlyFull at exactly 80% up to 99%', () {
      expect(
        getHydrationState(1600, 2000),
        HydrationState.nearlyFull,
      ); // exactly 80%
      expect(
        getHydrationState(1999, 2000),
        HydrationState.nearlyFull,
      ); // 99.95%
    });

    test('returns fullReservoir at 100% and above', () {
      expect(
        getHydrationState(2000, 2000),
        HydrationState.fullReservoir,
      ); // exactly 100%
      expect(
        getHydrationState(2500, 2000),
        HydrationState.fullReservoir,
      ); // 125%
      expect(
        getHydrationState(4000, 2000),
        HydrationState.fullReservoir,
      ); // 200%
    });

    test('handles boundary and invalid values gracefully without crashing', () {
      expect(getHydrationState(0, 0), HydrationState.gettingStarted);
      expect(getHydrationState(500, -100), HydrationState.gettingStarted);
      expect(getHydrationState(-200, 2000), HydrationState.gettingStarted);
    });
  });

  group('getFreshnessPhase', () {
    const threshold = Duration(minutes: 45);

    test('returns fresh for 0% to 50% elapsed time', () {
      expect(getFreshnessPhase(Duration.zero, threshold), FreshnessPhase.fresh);
      expect(
        getFreshnessPhase(const Duration(minutes: 15), threshold),
        FreshnessPhase.fresh,
      );
      expect(
        getFreshnessPhase(const Duration(seconds: 1350), threshold),
        FreshnessPhase.fresh,
      ); // 22.5 min = 50%
    });

    test('returns fading for >50% up to 100% elapsed time', () {
      expect(
        getFreshnessPhase(const Duration(minutes: 23), threshold),
        FreshnessPhase.fading,
      );
      expect(
        getFreshnessPhase(const Duration(minutes: 45), threshold),
        FreshnessPhase.fading,
      ); // 100%
    });

    test('returns dry for >100% elapsed time', () {
      expect(
        getFreshnessPhase(const Duration(minutes: 46), threshold),
        FreshnessPhase.dry,
      );
      expect(
        getFreshnessPhase(const Duration(hours: 2), threshold),
        FreshnessPhase.dry,
      );
    });

    test('handles non-positive threshold and negative elapsed gracefully', () {
      expect(
        getFreshnessPhase(const Duration(minutes: 10), Duration.zero),
        FreshnessPhase.dry,
      );
      expect(
        getFreshnessPhase(
          const Duration(minutes: 10),
          const Duration(minutes: -10),
        ),
        FreshnessPhase.dry,
      );
      // Clock drift/skew into the past:
      expect(
        getFreshnessPhase(const Duration(seconds: -30), threshold),
        FreshnessPhase.fresh,
      );
    });
  });

  group('getSealTier', () {
    test('returns goalMet for 100% and greater', () {
      expect(getSealTier(2000, 2000), SealTier.goalMet);
      expect(getSealTier(2100, 2000), SealTier.goalMet);
    });

    test('returns almostThere for 80% to 99%', () {
      expect(getSealTier(1600, 2000), SealTier.almostThere); // 80%
      expect(getSealTier(1950, 2000), SealTier.almostThere); // 97.5%
    });

    test('returns underGoal for less than 80%', () {
      expect(getSealTier(1599, 2000), SealTier.underGoal);
      expect(getSealTier(0, 2000), SealTier.underGoal);
    });

    test('handles edge cases safely', () {
      expect(getSealTier(1000, 0), SealTier.underGoal);
      expect(getSealTier(-500, 2000), SealTier.underGoal);
    });
  });

  group('calculateStreaks', () {
    final today = DateTime(2026, 10, 9);

    test('returns 0 for empty history', () {
      final result = calculateStreaks([], today: today);
      expect(result.currentStreak, 0);
      expect(result.bestStreak, 0);
    });

    test('calculates active streak when today is already met', () {
      final history = [
        DailySummary(date: DateTime(2026, 10, 7), totalMl: 2000, goalMl: 2000),
        DailySummary(date: DateTime(2026, 10, 8), totalMl: 2100, goalMl: 2000),
        DailySummary(date: DateTime(2026, 10, 9), totalMl: 2050, goalMl: 2000),
      ];

      final result = calculateStreaks(history, today: today);
      expect(result.currentStreak, 3);
      expect(result.bestStreak, 3);
    });

    test('keeps streak alive from yesterday when today is not met yet', () {
      final history = [
        DailySummary(date: DateTime(2026, 10, 7), totalMl: 2000, goalMl: 2000),
        DailySummary(date: DateTime(2026, 10, 8), totalMl: 2100, goalMl: 2000),
        DailySummary(
          date: DateTime(2026, 10, 9),
          totalMl: 800,
          goalMl: 2000,
        ), // Today in progress
      ];

      final result = calculateStreaks(history, today: today);
      expect(result.currentStreak, 2); // alive from yesterday!
      expect(result.bestStreak, 2);
    });

    test(
      'resets current streak to 0 if yesterday was missed and today not met',
      () {
        final history = [
          DailySummary(
            date: DateTime(2026, 10, 7),
            totalMl: 2000,
            goalMl: 2000,
          ),
          DailySummary(
            date: DateTime(2026, 10, 8),
            totalMl: 1200,
            goalMl: 2000,
          ), // Yesterday missed
          DailySummary(
            date: DateTime(2026, 10, 9),
            totalMl: 1000,
            goalMl: 2000,
          ), // Today in progress
        ];

        final result = calculateStreaks(history, today: today);
        expect(result.currentStreak, 0);
        expect(result.bestStreak, 1);
      },
    );

    test('correctly calculates best streak larger than current streak', () {
      // 5-day best streak in past: 1st through 5th
      final history = [
        DailySummary(date: DateTime(2026, 10, 1), totalMl: 2000, goalMl: 2000),
        DailySummary(date: DateTime(2026, 10, 2), totalMl: 2200, goalMl: 2000),
        DailySummary(date: DateTime(2026, 10, 3), totalMl: 2100, goalMl: 2000),
        DailySummary(date: DateTime(2026, 10, 4), totalMl: 2050, goalMl: 2000),
        DailySummary(date: DateTime(2026, 10, 5), totalMl: 2300, goalMl: 2000),
        // Missed on the 6th
        DailySummary(date: DateTime(2026, 10, 6), totalMl: 1500, goalMl: 2000),
        // Restarted on 7th and 8th
        DailySummary(date: DateTime(2026, 10, 7), totalMl: 2000, goalMl: 2000),
        DailySummary(date: DateTime(2026, 10, 8), totalMl: 2000, goalMl: 2000),
      ];

      final result = calculateStreaks(history, today: today);
      expect(result.currentStreak, 2); // 7th and 8th
      expect(result.bestStreak, 5); // 1st through 5th
    });

    test('deduplicates duplicate dates gracefully', () {
      final history = [
        DailySummary(date: DateTime(2026, 10, 8), totalMl: 1200, goalMl: 2000),
        DailySummary(
          date: DateTime(2026, 10, 8),
          totalMl: 2100,
          goalMl: 2000,
        ), // Duplicate with higher total
        DailySummary(date: DateTime(2026, 10, 9), totalMl: 2000, goalMl: 2000),
      ];

      final result = calculateStreaks(history, today: today);
      expect(result.currentStreak, 2);
      expect(result.bestStreak, 2);
    });
  });

  group('groupSipMergeWindows', () {
    final baseTime = DateTime.utc(2026, 10, 9, 10, 0, 0);

    test('returns empty list for empty input', () {
      expect(groupSipMergeWindows([]), isEmpty);
    });

    test('merges sips within 2-minute window and sorts newest first', () {
      final sips = [
        SipEvent(id: '1', volumeMl: 50, timestamp: baseTime),
        SipEvent(
          id: '2',
          volumeMl: 60,
          timestamp: baseTime.add(const Duration(minutes: 1)),
        ),
      ];

      final merged = groupSipMergeWindows(sips);
      expect(merged.length, 1);
      expect(merged.first.volumeMl, 110);
      expect(merged.first.timestamp, baseTime.add(const Duration(minutes: 1)));
    });

    test('keeps sips separate when gap exceeds window', () {
      final sips = [
        SipEvent(id: '1', volumeMl: 50, timestamp: baseTime),
        SipEvent(
          id: '2',
          volumeMl: 60,
          timestamp: baseTime.add(const Duration(minutes: 10)),
        ),
      ];

      final merged = groupSipMergeWindows(sips);
      expect(merged.length, 2);
      // Newest first:
      expect(merged[0].id, '2');
      expect(merged[0].volumeMl, 60);
      expect(merged[1].id, '1');
      expect(merged[1].volumeMl, 50);
    });

    test('handles out-of-order timestamps correctly before merging', () {
      final sips = [
        SipEvent(
          id: '2',
          volumeMl: 60,
          timestamp: baseTime.add(const Duration(minutes: 1)),
        ),
        SipEvent(id: '1', volumeMl: 50, timestamp: baseTime),
      ];

      final merged = groupSipMergeWindows(sips);
      expect(merged.length, 1);
      expect(merged.first.volumeMl, 110);
    });
  });

  group('checkDayRollover', () {
    test('returns false when on the same calendar day', () {
      final t1 = DateTime(2026, 10, 9, 8, 30);
      final t2 = DateTime(2026, 10, 9, 23, 59);
      expect(checkDayRollover(t1, t2), isFalse);
    });

    test('returns true when crossing midnight', () {
      final t1 = DateTime(2026, 10, 9, 23, 59);
      final t2 = DateTime(2026, 10, 10, 0, 1);
      expect(checkDayRollover(t1, t2), isTrue);
    });

    test('returns true for multi-day app suspension', () {
      final t1 = DateTime(2026, 10, 6, 12, 0);
      final t2 = DateTime(2026, 10, 9, 14, 0);
      expect(checkDayRollover(t1, t2), isTrue);
    });
  });

  group('detectSipVolumeFromWeightDrop', () {
    test('detects sip volume when weight drops by at least threshold', () {
      expect(detectSipVolumeFromWeightDrop(450.0, 350.0), 100);
      expect(detectSipVolumeFromWeightDrop(350.0, 339.0), 11);
    });

    test('returns null for minor noise below threshold', () {
      expect(detectSipVolumeFromWeightDrop(350.0, 345.0), isNull); // 5g drop
    });

    test('returns null on vessel refill (weight increase)', () {
      expect(detectSipVolumeFromWeightDrop(350.0, 550.0), isNull);
    });
  });
}
