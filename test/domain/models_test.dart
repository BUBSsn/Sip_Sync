import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_store/domain/domain.dart';

void main() {
  group('SipEvent', () {
    test('value equality and hashCode', () {
      final t = DateTime.utc(2026, 10, 9, 10, 30);
      final sip1 = SipEvent(id: 's1', volumeMl: 45, timestamp: t);
      final sip2 = SipEvent(id: 's1', volumeMl: 45, timestamp: t);
      final sip3 = SipEvent(id: 's2', volumeMl: 45, timestamp: t);

      expect(sip1, equals(sip2));
      expect(sip1.hashCode, equals(sip2.hashCode));
      expect(sip1, isNot(equals(sip3)));
    });

    test('copyWith creates updated clone', () {
      final t = DateTime.utc(2026, 10, 9, 10, 30);
      final sip = SipEvent(id: 's1', volumeMl: 45, timestamp: t);
      final updated = sip.copyWith(volumeMl: 60);

      expect(updated.id, 's1');
      expect(updated.volumeMl, 60);
      expect(updated.timestamp, t);
    });

    test('enforces strictly positive volume in assertion', () {
      expect(
        () => SipEvent(
          id: 's1',
          volumeMl: 0,
          timestamp: DateTime.utc(2026, 10, 9),
        ),
        throwsAssertionError,
      );
    });
  });

  group('CupWeightReading', () {
    test('value equality and hashCode', () {
      final t = DateTime.utc(2026, 10, 9, 10, 30);
      final r1 = CupWeightReading(grams: 350.0, timestamp: t);
      final r2 = CupWeightReading(grams: 350.0, timestamp: t);
      final r3 = CupWeightReading(grams: 360.0, timestamp: t);

      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
      expect(r1, isNot(equals(r3)));
    });

    test('enforces non-negative grams in assertion', () {
      expect(
        () =>
            CupWeightReading(grams: -1.0, timestamp: DateTime.utc(2026, 10, 9)),
        throwsAssertionError,
      );
    });
  });

  group('CalibrationResult', () {
    test('success and failure modeling', () {
      final t = DateTime.utc(2026, 10, 9, 10, 30);
      final success = CalibrationResult(
        status: CalibrationStatus.success,
        measuredGrams: 350.0,
        timestamp: t,
      );
      final failure = CalibrationResult(
        status: CalibrationStatus.failure,
        timestamp: t,
        errorMessage: 'Scale unstable',
      );

      expect(success.isSuccess, isTrue);
      expect(success.measuredGrams, 350.0);
      expect(failure.isSuccess, isFalse);
      expect(failure.errorMessage, 'Scale unstable');
    });

    test('asserts measuredGrams on success', () {
      expect(
        () => CalibrationResult(
          status: CalibrationStatus.success,
          measuredGrams: null,
          timestamp: DateTime.utc(2026, 10, 9),
        ),
        throwsAssertionError,
      );
    });
  });

  group('CoasterConnection', () {
    test('connection statuses and lastSeen', () {
      final t = DateTime.utc(2026, 10, 9, 10, 30);
      final conn1 = CoasterConnection(
        status: ConnectionStatus.connected,
        lastSeen: t,
      );
      final conn2 = CoasterConnection(
        status: ConnectionStatus.connected,
        lastSeen: t,
      );
      final disconnected = CoasterConnection(
        status: ConnectionStatus.disconnected,
      );

      expect(conn1, equals(conn2));
      expect(conn1.isConnected, isTrue);
      expect(disconnected.isConnected, isFalse);
    });
  });

  group('UserSettings', () {
    test('defaults and validation bounds', () {
      const settings = UserSettings();
      expect(settings.dailyGoalMl, 2000);
      expect(settings.inactivityThresholdMinutes, 45);
      expect(settings.adaptiveRemindersEnabled, isTrue);
      expect(settings.portionLimitMl, 250);

      expect(
        () => UserSettings(dailyGoalMl: 900), // Below 1000 min
        throwsAssertionError,
      );
      expect(
        () => UserSettings(dailyGoalMl: 4500), // Above 4000 max
        throwsAssertionError,
      );
      expect(
        () => UserSettings(portionLimitMl: 40), // Below 50 min
        throwsAssertionError,
      );
      expect(
        () => UserSettings(portionLimitMl: 550), // Above 500 max
        throwsAssertionError,
      );
    });

    test('copyWith and equality with portionLimitMl', () {
      const settings = UserSettings();
      final updated = settings.copyWith(portionLimitMl: 300);
      expect(updated.portionLimitMl, 300);
      expect(updated, isNot(equals(settings)));

      final same = settings.copyWith(portionLimitMl: 250);
      expect(same, equals(settings));
      expect(same.hashCode, equals(settings.hashCode));
    });
  });

  group('DailySummary', () {
    test('normalizes date and calculates progress', () {
      final dt = DateTime(2026, 10, 9, 15, 30, 45);
      final summary = DailySummary(date: dt, totalMl: 1450, goalMl: 2000);

      expect(summary.date, DateTime(2026, 10, 9));
      expect(summary.progress, 1450 / 2000);
      expect(summary.isGoalMet, isFalse);
    });

    test('equality checks year, month, day rather than time offset', () {
      final s1 = DailySummary(
        date: DateTime(2026, 10, 9, 8, 0),
        totalMl: 2100,
        goalMl: 2000,
      );
      final s2 = DailySummary(
        date: DateTime(2026, 10, 9, 22, 0),
        totalMl: 2100,
        goalMl: 2000,
      );

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1.isGoalMet, isTrue);
    });
  });

  group('StreakResult & StreakBadgeTier', () {
    test('tier mapping for streak badge progression', () {
      expect(StreakBadgeTier.fromDays(0), StreakBadgeTier.none);
      expect(StreakBadgeTier.fromDays(2), StreakBadgeTier.tier1);
      expect(StreakBadgeTier.fromDays(5), StreakBadgeTier.tier2);
      expect(StreakBadgeTier.fromDays(10), StreakBadgeTier.tier3);
      expect(StreakBadgeTier.fromDays(20), StreakBadgeTier.tier4);
      expect(StreakBadgeTier.fromDays(35), StreakBadgeTier.tier5);
    });

    test('asserts bestStreak >= currentStreak', () {
      expect(
        () => StreakResult(currentStreak: 5, bestStreak: 3),
        throwsAssertionError,
      );
    });
  });
}
