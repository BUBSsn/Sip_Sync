import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_store/domain/domain.dart';
import 'package:liquid_store/data/providers.dart';
import 'package:liquid_store/data/fake/fake_history_repository.dart';
import 'package:liquid_store/main.dart';
import 'package:liquid_store/presentation/history/widgets/arcade_history.dart';
import 'package:liquid_store/presentation/theme/theme_mode_provider.dart';
import 'package:liquid_store/presentation/view_models/history_view_model.dart';
import 'package:liquid_store/presentation/widgets/sip_tab_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_providers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('chart ranges include saved older days and keep daily targets', (
    tester,
  ) async {
    final anchor = DateTime(2026, 10, 19);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WeeklyHydroTubes(
              reducedMotion: true,
              isEmpty: false,
              columns: List.generate(
                7,
                (i) => WeeklyDayColumn(
                  dayLabel: 'Day',
                  date: anchor.subtract(Duration(days: 6 - i)),
                  totalMl: 100,
                  goalMl: 2000,
                  progress: 0.05,
                  isToday: i == 6,
                ),
              ),
              archiveEntries: [
                ArchiveItem(
                  dayName: 'Tuesday',
                  date: DateTime(2026, 10, 6),
                  totalMl: 2400,
                  goalMl: 3000,
                  sealTier: SealTier.almostThere,
                  statusText: 'Almost there!',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('hydro-tube-6')), findsOneWidget);
    await tester.tap(find.byKey(const Key('hydro_range_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 14 days'));
    await tester.pumpAndSettle();
    expect(find.text('LAST 14 DAYS'), findsOneWidget);
    expect(find.byKey(const ValueKey('hydro-tube-13')), findsOneWidget);
    expect(find.text('Daily targets'), findsOneWidget);
    final oldest = find.byKey(const ValueKey('hydro-tube-0'));
    await tester.ensureVisible(oldest);
    await tester.tap(oldest);
    await tester.pumpAndSettle();
    expect(find.text('2400 ml consumed · 80% of target'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('hydro_range_filter')));
    await tester.tap(find.byKey(const Key('hydro_range_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 30 days'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hydro-tube-29')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tab headers share height and Settings toggles the shared theme',
    (tester) async {
      await tester.pumpWidget(const TestProviderScope(child: LiquidStoreApp()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final homeHeight = tester
          .getSize(find.byType(SipTabHeader).hitTestable())
          .height;
      await tester.tap(find.text('HISTORY'));
      await tester.pump();
      expect(find.text('ONLINE'), findsNothing);
      expect(find.text('94%'), findsNothing);
      expect(
        tester.getSize(find.byType(SipTabHeader).hitTestable()).height,
        homeHeight,
      );
      await tester.tap(find.text('SETTINGS'));
      await tester.pump();
      expect(
        tester.getSize(find.byType(SipTabHeader).hitTestable()).height,
        homeHeight,
      );
      expect(find.byIcon(Icons.person).hitTestable(), findsOneWidget);
      final toggle = find.byTooltip('Switch to dark mode').hitTestable();
      final context = tester.element(toggle);
      final container = ProviderScope.containerOf(context);
      await tester.tap(toggle);
      await tester.pump();
      expect(container.read(themeModeProvider), ThemeMode.dark);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byTooltip('Switch to light mode').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Switch to light mode').hitTestable());
      await tester.pump();
      expect(container.read(themeModeProvider), ThemeMode.light);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'all tab titles match and XP updates from saved sips and corrections',
    (tester) async {
      final history = FakeHistoryRepository(
        initialSips: [],
        initialSummaries: [],
      );
      addTearDown(history.dispose);
      await tester.pumpWidget(
        TestProviderScope(
          overrides: [historyRepositoryProvider.overrideWithValue(history)],
          child: const LiquidStoreApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final titleStyle = tester.widget<Text>(find.text('SipSync')).style;
      for (final tab in ['HOME', 'HISTORY', 'SETTINGS']) {
        await tester.tap(find.text(tab));
        await tester.pump();
        final name = {
          'HOME': 'Home',
          'HISTORY': 'History',
          'SETTINGS': 'Settings',
        }[tab]!;
        final title = {
          'HOME': 'SipSync',
          'HISTORY': 'Sip History',
          'SETTINGS': 'Sip Settings',
        }[tab]!;
        expect(tester.widget<Text>(find.text(title)).style, titleStyle);
        final actions = find.byType(SipHeaderActions);
        final themeButton = find.descendant(
          of: actions,
          matching: find.byType(IconButton),
        );
        final avatar = find.descendant(
          of: actions,
          matching: find.byType(CircleAvatar),
        );
        expect(tester.getSize(themeButton), const Size.square(48));
        expect(tester.getSize(avatar), const Size.square(48));
        expect(find.text('$name · LVL 1 [0/100 XP]'), findsOneWidget);
      }

      await history.recordSip(
        SipEvent(
          id: 'header-xp-sip',
          volumeMl: 80,
          timestamp: DateTime.now().toUtc(),
        ),
      );
      await tester.pump();
      expect(find.text('Settings · LVL 1 [10/100 XP]'), findsOneWidget);
      await tester.tap(find.text('HISTORY'));
      await tester.pump();
      expect(find.text('History · LVL 1 [10/100 XP]'), findsOneWidget);
      await tester.tap(find.text('HOME'));
      await tester.pump();
      expect(find.text('Home · LVL 1 [10/100 XP]'), findsOneWidget);

      // A level-up uses the next level's real target rather than a fixed 100 XP.
      await history.recordSip(
        SipEvent(
          id: 'header-level-up',
          volumeMl: 720,
          timestamp: DateTime.now().toUtc(),
        ),
      );
      await tester.pump();
      expect(find.text('Home · LVL 2 [0/200 XP]'), findsOneWidget);
      await history.deleteSip('header-level-up');
      await tester.pump();
      expect(find.text('Home · LVL 1 [10/100 XP]'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
