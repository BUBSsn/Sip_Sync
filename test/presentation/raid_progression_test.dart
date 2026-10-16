import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_store/data/fake/fake_history_repository.dart';
import 'package:liquid_store/data/providers.dart';
import 'package:liquid_store/domain/domain.dart';
import 'package:liquid_store/presentation/home/home_screen.dart';
import 'package:liquid_store/presentation/home/widgets/beaker_vessel.dart';
import 'package:liquid_store/presentation/settings/settings_screen.dart';
import 'package:liquid_store/presentation/view_models/hydration_view_model.dart';
import 'package:liquid_store/presentation/widgets/coaster_connection_card.dart';
import 'package:liquid_store/presentation/widgets/raid_badges.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_providers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'all ten bosses unlock in order with increasing HP and finish permanently',
    () {
      var total = 0;
      expect(BossRaidStatus.bossNames.toSet(), hasLength(10));
      expect(BossRaidStatus.badgeNames.toSet(), hasLength(10));
      expect(raidBadgeIcons.toSet(), hasLength(10));
      for (var act = 1; act <= 10; act++) {
        final boss = BossRaidStatus.calculate(total);
        expect(boss.act, act);
        expect(boss.bossName, BossRaidStatus.bossNames[act - 1]);
        expect(boss.currentHp, 0);
        total += boss.maxHp;
        expect(BossRaidStatus.defeatedCount(total - 1), act - 1);
        expect(BossRaidStatus.defeatedCount(total), act);
      }
      expect(total, 42500);
      expect(BossRaidStatus.calculate(total).isComplete, true);
      expect(BossRaidStatus.calculate(total + 100000).act, 10);
      expect(BossRaidStatus.calculate(total + 100000).progress, 1);
      expect(
        BossRaidStatus.earnedRewardXp(total + 100000),
        BossRaidStatus.earnedRewardXp(total),
      );
      expect(BossRaidStatus.defeatedCount(-1), 0);
    },
  );

  test('level 50 starts at 122500 XP and has no further level', () {
    expect(HydrationSnapshot.calculateLevelProgress(122499).level, 49);
    final capped = HydrationSnapshot.calculateLevelProgress(122500);
    expect(capped, (level: 50, currentLevelXp: 0, nextLevelXp: 0));
    expect(HydrationSnapshot.calculateLevelProgress(99999999), capped);
    expect(HydrationSnapshot.calculateLevelProgress(-1).level, 1);
  });

  test('lifetime boss and reward combine intake from multiple days', () {
    final now = DateTime.now();
    final history = FakeHistoryRepository(
      initialSips: [SipEvent(id: 'today', volumeMl: 1000, timestamp: now)],
      initialSummaries: [
        DailySummary(
          date: DateTime(now.year, now.month, now.day - 1),
          totalMl: 1000,
          goalMl: 2000,
        ),
      ],
    );
    addTearDown(history.dispose);
    final container = createTestContainer(
      overrides: [historyRepositoryProvider.overrideWithValue(history)],
    );
    addTearDown(container.dispose);
    final snapshot = container.read(hydrationViewModelProvider);
    expect(snapshot.currentMl, 1000);
    expect(snapshot.bossRaid.act, 2);
    expect(snapshot.totalXp, 500);
    expect(snapshot.xpToday, 375);
    expect(snapshot.copyWith(isThirstQuenched: true).bossRaid.act, 2);
  });

  testWidgets(
    'connection card is absent from Home and badges appear in Settings',
    (tester) async {
      await tester.pumpWidget(
        const TestProviderScope(child: MaterialApp(home: HomeScreen())),
      );
      await tester.pump();
      expect(find.byType(CoasterConnectionCard), findsNothing);
      await tester.pumpWidget(
        const TestProviderScope(child: MaterialApp(home: SettingsScreen())),
      );
      await tester.pump();
      expect(find.byType(CoasterConnectionCard), findsOneWidget);
      expect(find.byType(RaidBadgeCollection), findsOneWidget);
      expect(find.byType(RaidBadge), findsNWidgets(10));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'first sip rises gradually from empty and settles at saved intake',
    (tester) async {
      final history = FakeHistoryRepository(
        initialSips: [],
        initialSummaries: [],
      );
      addTearDown(history.dispose);
      await tester.pumpWidget(
        TestProviderScope(
          overrides: [historyRepositoryProvider.overrideWithValue(history)],
          child: const MaterialApp(home: Scaffold(body: BeakerVessel())),
        ),
      );
      await tester.pump();
      final canvas = find.descendant(
        of: find.byType(BeakerVessel),
        matching: find.byType(CustomPaint),
      );
      double fill() =>
          (tester.widget<CustomPaint>(canvas).painter as dynamic).fillProgress
              as double;
      expect(fill(), 0);
      await history.recordSip(
        SipEvent(id: 'sip', volumeMl: 200, timestamp: DateTime.now()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(fill(), greaterThan(0));
      expect(fill(), lessThan(0.1));
      await tester.pump(const Duration(seconds: 2));
      expect(fill(), closeTo(0.1, 0.00001));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
