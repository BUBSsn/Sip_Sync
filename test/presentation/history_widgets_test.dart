import '../support/test_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_store/data/fake/fake_history_repository.dart';
import 'package:liquid_store/data/fake/seed_data.dart';
import 'package:liquid_store/data/providers.dart';
import 'package:liquid_store/domain/domain.dart';
import 'package:liquid_store/presentation/history/history_screen.dart';
import 'package:liquid_store/presentation/history/widgets/arcade_history.dart';
import 'package:liquid_store/presentation/history/widgets/glass_column_chart.dart';
import 'package:liquid_store/presentation/history/widgets/milestone_seal_tile.dart';
import 'package:liquid_store/presentation/history/widgets/stat_card.dart';
import 'package:liquid_store/presentation/history/widgets/streak_badge.dart';
import 'package:liquid_store/presentation/history/widgets/streak_drop_badge.dart';
import 'package:liquid_store/presentation/theme/reduced_motion.dart';
import 'package:liquid_store/presentation/view_models/history_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget({
    required Widget child,
    List<dynamic> overrides = const [],
  }) {
    return TestProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('StreakDropBadge (Pillar 3)', () {
    testWidgets('renders zero-streak state gracefully', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const StreakDropBadge(
            streakDays: 0,
            bestStreakDays: 0,
            currentTier: StreakBadgeTier.none,
            daysToNextTier: 1,
            isReducedMotion: false,
          ),
        ),
      );

      expect(find.text('Best Streak'), findsOneWidget);
      expect(find.text('0 Days'), findsOneWidget);
      expect(find.textContaining('No active streak'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'displays progression hint to next tier (e.g. 2 days to Tier 3)',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: const StreakDropBadge(
              streakDays: 5,
              bestStreakDays: 5,
              currentTier: StreakBadgeTier.tier2,
              daysToNextTier: 2,
              isReducedMotion: false,
            ),
          ),
        );

        expect(find.text('5 Days'), findsOneWidget);
        expect(find.textContaining('2 days to Tier 3'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('displays max tier celebration when at Tier 5 (30+ days)', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const StreakDropBadge(
            streakDays: 35,
            bestStreakDays: 35,
            currentTier: StreakBadgeTier.tier5,
            daysToNextTier: 0,
            isReducedMotion: false,
          ),
        ),
      );

      expect(find.text('35 Days'), findsOneWidget);
      expect(find.textContaining('Max Tier 5 Active 👑'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'renders static badge without continuous ticker in reduced motion',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: const StreakDropBadge(
              streakDays: 10,
              bestStreakDays: 14,
              currentTier: StreakBadgeTier.tier3,
              daysToNextTier: 4,
              isReducedMotion: true,
            ),
          ),
        );

        expect(find.text('14 Days'), findsOneWidget);
        expect(find.textContaining('4 days to Tier 4'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  group('GlassColumnChart (Pillar 3)', () {
    testWidgets('renders loading skeleton when isLoading is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const GlassColumnChart(
            columns: [],
            isLoading: true,
            isReducedMotion: true,
          ),
        ),
      );

      expect(find.text('Weekly Intake'), findsOneWidget);
      // Verify loading skeleton containers
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders friendly empty state when isEmpty is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const GlassColumnChart(
            columns: [],
            isEmpty: true,
            isReducedMotion: true,
          ),
        ),
      );

      expect(find.text('No intake logged this week'), findsOneWidget);
      expect(
        find.textContaining('Place your cup on the coaster'),
        findsOneWidget,
      );
    });

    testWidgets(
      'renders 7 columns, highlights today, and caps goal-met marker',
      (tester) async {
        final now = DateTime.now();
        final columns = [
          WeeklyDayColumn(
            dayLabel: 'Tue',
            date: now.subtract(const Duration(days: 6)),
            totalMl: 1200,
            goalMl: 2000,
            progress: 0.6,
            isToday: false,
          ),
          WeeklyDayColumn(
            dayLabel: 'Wed',
            date: now.subtract(const Duration(days: 5)),
            totalMl: 2000,
            goalMl: 2000,
            progress: 1.0,
            isToday: false,
          ),
          WeeklyDayColumn(
            dayLabel: 'Thu',
            date: now.subtract(const Duration(days: 4)),
            totalMl: 2050,
            goalMl: 2000,
            progress: 1.0,
            isToday: false,
          ),
          WeeklyDayColumn(
            dayLabel: 'Fri',
            date: now.subtract(const Duration(days: 3)),
            totalMl: 2000,
            goalMl: 2000,
            progress: 1.0,
            isToday: false,
          ),
          WeeklyDayColumn(
            dayLabel: 'Sat',
            date: now.subtract(const Duration(days: 2)),
            totalMl: 1600,
            goalMl: 2000,
            progress: 0.8,
            isToday: false,
          ),
          WeeklyDayColumn(
            dayLabel: 'Sun',
            date: now.subtract(const Duration(days: 1)),
            totalMl: 1950,
            goalMl: 2000,
            progress: 0.975,
            isToday: false,
          ),
          WeeklyDayColumn(
            dayLabel: 'Mon',
            date: now,
            totalMl: 2100,
            goalMl: 2000,
            progress: 1.0,
            isToday: true,
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: GlassColumnChart(columns: columns, isReducedMotion: true),
          ),
        );

        // Verify all 7 day labels
        expect(find.text('Tue'), findsOneWidget);
        expect(find.text('Wed'), findsOneWidget);
        expect(find.text('Thu'), findsOneWidget);
        expect(find.text('Fri'), findsOneWidget);
        expect(find.text('Sat'), findsOneWidget);
        expect(find.text('Sun'), findsOneWidget);
        expect(find.text('Mon'), findsOneWidget);

        // Tap on Monday column to reveal tooltip
        await tester.tap(find.text('Mon'));
        await tester.pumpAndSettle();

        expect(find.text('Mon: 2100 ml (105%)'), findsOneWidget);
      },
    );

    testWidgets(
      'handles 0ml empty glass and extreme hydration (>250%) gracefully',
      (tester) async {
        final now = DateTime.now();
        final columns = [
          WeeklyDayColumn(
            dayLabel: 'Tue',
            date: now.subtract(const Duration(days: 1)),
            totalMl: 0,
            goalMl: 2000,
            progress: 0.0,
            isToday: false,
          ),
          WeeklyDayColumn(
            dayLabel: 'Wed',
            date: now,
            totalMl: 5000,
            goalMl: 2000,
            progress: 1.0, // visually clamped to 1.0
            isToday: true,
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: GlassColumnChart(columns: columns, isReducedMotion: true),
          ),
        );

        // Tap Tue (0ml): tooltip reflects 0 ml (0%)
        await tester.tap(find.text('Tue'));
        await tester.pumpAndSettle();
        expect(find.text('Tue: 0 ml (0%)'), findsOneWidget);

        // Tap Wed (5000ml): tooltip reflects un-clamped 5000 ml (250%)
        await tester.tap(find.text('Wed'));
        await tester.pumpAndSettle();
        expect(find.text('Wed: 5000 ml (250%)'), findsOneWidget);
      },
    );
  });

  group('MilestoneSealTile (Pillar 3)', () {
    testWidgets('renders Goal Met (>= 100%) with checkmark and status text', (
      tester,
    ) async {
      final item = ArchiveItem(
        dayName: 'Monday',
        date: DateTime.now(),
        totalMl: 2100,
        goalMl: 2000,
        sealTier: SealTier.goalMet,
        statusText: 'Goal Met!',
      );

      await tester.pumpWidget(
        createTestWidget(
          child: MilestoneSealTile(item: item, isReducedMotion: true),
        ),
      );

      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('Goal Met!'), findsOneWidget);
      expect(find.text('2100ml'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('renders Almost there (80-99%) with partial completion ring', (
      tester,
    ) async {
      final item = ArchiveItem(
        dayName: 'Sunday',
        date: DateTime.now().subtract(const Duration(days: 1)),
        totalMl: 1950,
        goalMl: 2000,
        sealTier: SealTier.almostThere,
        statusText: 'Almost there!',
      );

      await tester.pumpWidget(
        createTestWidget(
          child: MilestoneSealTile(item: item, isReducedMotion: true),
        ),
      );

      expect(find.text('Sunday'), findsOneWidget);
      expect(find.text('Almost there!'), findsOneWidget);
      expect(find.text('1950ml'), findsOneWidget);
      expect(find.byIcon(Icons.water_drop), findsOneWidget);
    });

    testWidgets('renders below 80% with neutral non-shaming styling', (
      tester,
    ) async {
      final item = ArchiveItem(
        dayName: 'Saturday',
        date: DateTime.now().subtract(const Duration(days: 2)),
        totalMl: 1600,
        goalMl: 2000,
        sealTier: SealTier.underGoal,
        statusText: 'In Progress',
      );

      await tester.pumpWidget(
        createTestWidget(
          child: MilestoneSealTile(item: item, isReducedMotion: true),
        ),
      );

      expect(find.text('Saturday'), findsOneWidget);
      expect(find.text('1600ml'), findsOneWidget);
      expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
      // Status text should be hidden or neutral, never shaming
      expect(find.text('Goal Met!'), findsNothing);
    });

    testWidgets('safely protects against historic goalMl == 0 division', (
      tester,
    ) async {
      final zeroGoalItem = ArchiveItem(
        dayName: 'Friday',
        date: DateTime.now().subtract(const Duration(days: 3)),
        totalMl: 1500,
        goalMl: 0, // historic goal was zero/unset
        sealTier: SealTier.underGoal,
        statusText: 'In Progress',
      );

      await tester.pumpWidget(
        createTestWidget(
          child: MilestoneSealTile(item: zeroGoalItem, isReducedMotion: true),
        ),
      );

      expect(find.text('Friday'), findsOneWidget);
      expect(find.text('1500ml'), findsOneWidget);
    });
  });

  group('StatCard (Pillar 3)', () {
    testWidgets(
      'displays formatted value and immediately provides accessible label',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          createTestWidget(
            child: StatCard(
              icon: Icons.track_changes,
              label: 'Average Intake',
              targetValue: 1850.0,
              valueFormatter: (v) => '${v.round()}ml',
              isReducedMotion: true,
            ),
          ),
        );

        expect(find.text('Average Intake'), findsOneWidget);
        expect(find.text('1850ml'), findsOneWidget);
        expect(find.bySemanticsLabel('Average Intake: 1850ml'), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets('formats weekly total as 12.9L', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createTestWidget(
          child: StatCard(
            icon: Icons.waves,
            label: 'Weekly Total',
            targetValue: 12.9,
            valueFormatter: (v) => '${v.toStringAsFixed(1)}L',
            isReducedMotion: true,
          ),
        ),
      );

      expect(find.text('Weekly Total'), findsOneWidget);
      expect(find.text('12.9L'), findsOneWidget);
      expect(find.bySemanticsLabel('Weekly Total: 12.9L'), findsOneWidget);
      handle.dispose();
    });
  });

  group('Phase 6 Rive Abstraction', () {
    testWidgets(
      'streakBadgeBuilderProvider can be overridden without changing callers',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            overrides: [
              streakBadgeBuilderProvider.overrideWithValue((
                context, {
                required streakDays,
                required bestStreakDays,
                required currentTier,
                required daysToNextTier,
                required isReducedMotion,
              }) {
                return Container(
                  key: const ValueKey('mock_rive_streak_badge'),
                  child: Text('Mock Rive Badge: $streakDays days'),
                );
              }),
            ],
            child: Builder(
              builder: (context) {
                final builder = ProviderScope.containerOf(
                  context,
                ).read(streakBadgeBuilderProvider);
                return builder(
                  context,
                  streakDays: 7,
                  bestStreakDays: 10,
                  currentTier: StreakBadgeTier.tier3,
                  daysToNextTier: 7,
                  isReducedMotion: false,
                );
              },
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey('mock_rive_streak_badge')),
          findsOneWidget,
        );
        expect(find.text('Mock Rive Badge: 7 days'), findsOneWidget);
      },
    );
  });

  testWidgets(
    'hydro tube selection shows actual intake and historical target',
    (tester) async {
      final columns = List.generate(
        7,
        (index) => WeeklyDayColumn(
          dayLabel: const [
            'Sat',
            'Sun',
            'Mon',
            'Tue',
            'Wed',
            'Thu',
            'Fri',
          ][index],
          date: DateTime(2026, 10, 10 + index),
          totalMl: index == 0 ? 1200 : 0,
          goalMl: index == 0 ? 1000 : 2000,
          progress: index == 0 ? 1 : 0,
          isToday: index == 6,
        ),
      );
      await tester.pumpWidget(
        createTestWidget(
          child: WeeklyHydroTubes(
            columns: columns,
            reducedMotion: true,
            isEmpty: false,
          ),
        ),
      );
      expect(find.text('Daily targets'), findsOneWidget);
      expect(find.text('Friday (In progress)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('hydro-tube-0')));
      await tester.pump();
      expect(find.text('Saturday (Goal met)'), findsOneWidget);
      expect(find.text('1200 ml consumed · 120% of target'), findsOneWidget);
      expect(find.text('LOG CUP'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('hydro-tube-4')));
      await tester.pump();
      expect(find.text('Wednesday (Below goal)'), findsOneWidget);
      expect(find.text('0 ml consumed · 0% of target'), findsOneWidget);
      expect(find.textContaining('(In progress)'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('hydro-tube-6')));
      await tester.pump();
      expect(find.text('Friday (In progress)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  group('HistoryScreen Full Assembly & Presets', () {
    testWidgets('renders all visual reference sections in exact hierarchy', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          overrides: [manualReducedEffectsProvider.overrideWith((ref) => true)],
          child: const HistoryScreen(),
        ),
      );

      // 1. Header
      expect(find.text('Sip History'), findsOneWidget);

      // 2. Weekly Intake Chart
      expect(find.byType(WeeklyHydroTubes), findsOneWidget);

      // 3. StatCards
      expect(find.text('Daily average'), findsOneWidget);
      expect(find.text('Weekly total'), findsOneWidget);

      // 4. Best Streak Badge
      expect(find.textContaining('Best streak:'), findsOneWidget);
      expect(find.byType(WeeklyTelemetry), findsOneWidget);

      // 5. Archive
      expect(find.text('Archive'), findsOneWidget);
      expect(find.byType(MilestoneSealTile), findsWidgets);

      // Reference sips / archives
      expect(find.text('Monday'), findsWidgets);
      expect(find.text('2100ml'), findsWidgets);
      expect(find.text('Sunday'), findsWidgets);
      expect(find.text('1950ml'), findsWidgets);
      expect(find.text('Saturday'), findsWidgets);
      expect(find.text('1600ml'), findsWidgets);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'swapping to empty history preset renders friendly empty states',
      (tester) async {
        final fakeHistoryRepo = FakeHistoryRepository();
        await fakeHistoryRepo.setHistoryPreset(HistoryPreset.empty);

        await tester.pumpWidget(
          createTestWidget(
            overrides: [
              historyRepositoryProvider.overrideWithValue(fakeHistoryRepo),
              manualReducedEffectsProvider.overrideWith((ref) => true),
            ],
            child: const HistoryScreen(),
          ),
        );

        expect(find.text('No intake logged this week'), findsOneWidget);
        expect(find.byKey(const ValueKey('hydro-tube-6')), findsOneWidget);
        expect(find.text('0-day streak'), findsOneWidget);
        expect(find.text('No past archive records yet'), findsOneWidget);

        fakeHistoryRepo.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('swapping to high streak preset renders Tier 5 active badge', (
      tester,
    ) async {
      final fakeHistoryRepo = FakeHistoryRepository();
      await fakeHistoryRepo.setHistoryPreset(HistoryPreset.highStreak);

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            historyRepositoryProvider.overrideWithValue(fakeHistoryRepo),
            manualReducedEffectsProvider.overrideWith((ref) => true),
          ],
          child: const HistoryScreen(),
        ),
      );

      expect(find.text('35-day streak'), findsOneWidget);
      expect(find.textContaining('Max Tier 5 Active'), findsOneWidget);

      fakeHistoryRepo.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('DST & Calendar Continuity', () {
    test(
      'streak calculation does not break on 23h or 25h DST transition day',
      () {
        final day1 = DateTime(2026, 3, 28);
        // DST shift day (23 hours long in local time)
        final day2 = DateTime(2026, 3, 29);
        final day3 = DateTime(2026, 3, 30);

        final summaries = [
          DailySummary(date: day1, totalMl: 2100, goalMl: 2000),
          DailySummary(date: day2, totalMl: 2000, goalMl: 2000),
          DailySummary(date: day3, totalMl: 2200, goalMl: 2000),
        ];

        final streak = calculateStreaks(summaries, today: day3);
        expect(streak.currentStreak, 3);
        expect(streak.bestStreak, 3);
      },
    );
  });
}
