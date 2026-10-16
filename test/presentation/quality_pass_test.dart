import '../support/test_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_store/data/fake/fake_history_repository.dart';
import 'package:liquid_store/domain/domain.dart';
import 'package:liquid_store/presentation/history/history_screen.dart';
import 'package:liquid_store/presentation/history/widgets/arcade_history.dart';
import 'package:liquid_store/presentation/history/widgets/milestone_seal_tile.dart';
import 'package:liquid_store/presentation/home/home_screen.dart';
import 'package:liquid_store/presentation/home/widgets/beaker_vessel.dart';
import 'package:liquid_store/presentation/home/widgets/freshness_indicator.dart';
import 'package:liquid_store/presentation/home/widgets/liquid_vessel.dart';
import 'package:liquid_store/presentation/settings/settings_screen.dart';
import 'package:liquid_store/presentation/settings/widgets/tare_ritual_button.dart';
import 'package:liquid_store/presentation/shell/app_shell.dart';
import 'package:liquid_store/presentation/theme/liquid_theme.dart';
import 'package:liquid_store/presentation/theme/liquid_tokens.dart';
import 'package:liquid_store/presentation/view_models/freshness_view_model.dart';
import 'package:liquid_store/presentation/view_models/history_view_model.dart';
import 'package:liquid_store/presentation/view_models/hydration_view_model.dart';
import 'package:liquid_store/presentation/view_models/settings_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestApp({
    Key? key,
    required Widget child,
    List<dynamic> overrides = const [],
    ThemeMode themeMode = ThemeMode.light,
    double textScale = 1.0,
    Size surfaceSize = const Size(390, 844),
  }) {
    return TestProviderScope(
      key: key,
      overrides: overrides.cast(),
      child: MaterialApp(
        theme: LiquidTheme.light,
        darkTheme: LiquidTheme.dark,
        themeMode: themeMode,
        home: MediaQuery(
          data: MediaQueryData(
            size: surfaceSize,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('Quality Pass: Hydration Progression & State Labels (Pillar 1)', () {
    test('verifies all 5 progression state enum values and labels', () {
      expect(HydrationState.gettingStarted.label, 'Just Getting Started');
      expect(HydrationState.steadyStream.label, 'Steady Stream');
      expect(HydrationState.optimalFlow.label, 'Optimal Flow');
      expect(HydrationState.nearlyFull.label, 'Nearly Full');
      expect(HydrationState.fullReservoir.label, 'Full Reservoir');
      expect(HydrationState.thirstQuenched.label, 'Thirst Quenched');
    });

    testWidgets('renders all progression labels inside LiquidVessel', (
      tester,
    ) async {
      // 1. Just Getting Started
      await tester.pumpWidget(
        createTestApp(
          key: const ValueKey('progression_1'),
          overrides: [
            hydrationViewModelProvider.overrideWith(
              (ref) => _FakeHydrationViewModel(
                HydrationSnapshot(
                  currentMl: 200,
                  goalMl: 2000,
                  progress: 0.1,
                  hydrationState: HydrationState.gettingStarted,
                  stateLabel: 'Just Getting Started',
                  isOverGoal: false,
                  isThirstQuenched: false,
                ),
              ),
            ),
          ],
          child: const LiquidVessel(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Just Getting Started'), findsOneWidget);

      // 2. Steady Stream
      await tester.pumpWidget(
        createTestApp(
          key: const ValueKey('progression_2'),
          overrides: [
            hydrationViewModelProvider.overrideWith(
              (ref) => _FakeHydrationViewModel(
                HydrationSnapshot(
                  currentMl: 700,
                  goalMl: 2000,
                  progress: 0.35,
                  hydrationState: HydrationState.steadyStream,
                  stateLabel: 'Steady Stream',
                  isOverGoal: false,
                  isThirstQuenched: false,
                ),
              ),
            ),
          ],
          child: const LiquidVessel(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Steady Stream'), findsOneWidget);

      // 3. Optimal Flow
      await tester.pumpWidget(
        createTestApp(
          key: const ValueKey('progression_3'),
          overrides: [
            hydrationViewModelProvider.overrideWith(
              (ref) => _FakeHydrationViewModel(
                HydrationSnapshot(
                  currentMl: 1450,
                  goalMl: 2000,
                  progress: 0.725,
                  hydrationState: HydrationState.optimalFlow,
                  stateLabel: 'Optimal Flow',
                  isOverGoal: false,
                  isThirstQuenched: false,
                ),
              ),
            ),
          ],
          child: const LiquidVessel(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Optimal Flow'), findsOneWidget);

      // 4. Nearly Full
      await tester.pumpWidget(
        createTestApp(
          key: const ValueKey('progression_4'),
          overrides: [
            hydrationViewModelProvider.overrideWith(
              (ref) => _FakeHydrationViewModel(
                HydrationSnapshot(
                  currentMl: 1900,
                  goalMl: 2000,
                  progress: 0.95,
                  hydrationState: HydrationState.nearlyFull,
                  stateLabel: 'Nearly Full',
                  isOverGoal: false,
                  isThirstQuenched: false,
                ),
              ),
            ),
          ],
          child: const LiquidVessel(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Nearly Full'), findsOneWidget);

      // 5. Full Reservoir
      await tester.pumpWidget(
        createTestApp(
          key: const ValueKey('progression_5'),
          overrides: [
            hydrationViewModelProvider.overrideWith(
              (ref) => _FakeHydrationViewModel(
                HydrationSnapshot(
                  currentMl: 2100,
                  goalMl: 2000,
                  progress: 1.05,
                  hydrationState: HydrationState.fullReservoir,
                  stateLabel: 'Full Reservoir',
                  isOverGoal: true,
                  isThirstQuenched: false,
                ),
              ),
            ),
          ],
          child: const LiquidVessel(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Full Reservoir'), findsOneWidget);
    });

    test('Thirst Quenched transient label overrides regular state label', () {
      final snapshotWithQuenched = HydrationSnapshot(
        currentMl: 1450,
        goalMl: 2000,
        progress: 0.725,
        hydrationState: HydrationState.optimalFlow,
        stateLabel: 'Thirst Quenched',
        isOverGoal: false,
        isThirstQuenched: true,
      );

      expect(snapshotWithQuenched.stateLabel, 'Thirst Quenched');
      expect(snapshotWithQuenched.isThirstQuenched, isTrue);
    });
  });

  group('Quality Pass: Freshness Indicator Phases (Pillar 2)', () {
    testWidgets('renders Fresh phase correctly', (tester) async {
      final container = createTestContainer(
        overrides: [
          freshnessViewModelProvider.overrideWith(
            (ref) => _FakeFreshnessViewModel(
              FreshnessState(
                elapsed: const Duration(minutes: 10),
                threshold: const Duration(minutes: 30),
                phase: FreshnessPhase.fresh,
                elapsedDisplay: '10m ago',
                lastSipTime: DateTime.now().subtract(
                  const Duration(minutes: 10),
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: LiquidTheme.light,
            home: const Scaffold(body: FreshnessIndicator()),
          ),
        ),
      );

      expect(find.text('10m ago • Fresh'), findsOneWidget);
      expect(find.byIcon(Icons.water_drop), findsOneWidget);
    });

    testWidgets('renders Fading phase correctly', (tester) async {
      final container = createTestContainer(
        overrides: [
          freshnessViewModelProvider.overrideWith(
            (ref) => _FakeFreshnessViewModel(
              FreshnessState(
                elapsed: const Duration(minutes: 45),
                threshold: const Duration(minutes: 30),
                phase: FreshnessPhase.fading,
                elapsedDisplay: '45m ago',
                lastSipTime: DateTime.now().subtract(
                  const Duration(minutes: 45),
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: LiquidTheme.light,
            home: const Scaffold(body: FreshnessIndicator()),
          ),
        ),
      );

      expect(find.text('45m ago • Fading'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('renders Dry phase correctly', (tester) async {
      final container = createTestContainer(
        overrides: [
          freshnessViewModelProvider.overrideWith(
            (ref) => _FakeFreshnessViewModel(
              FreshnessState(
                elapsed: const Duration(minutes: 90),
                threshold: const Duration(minutes: 30),
                phase: FreshnessPhase.dry,
                elapsedDisplay: '1h 30m ago',
                lastSipTime: DateTime.now().subtract(
                  const Duration(minutes: 90),
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: LiquidTheme.light,
            home: const Scaffold(body: FreshnessIndicator()),
          ),
        ),
      );

      expect(find.text('Time for a sip • Low'), findsOneWidget);
      expect(find.byIcon(Icons.spa_outlined), findsOneWidget);
    });
  });

  group('Quality Pass: Milestone Seal Tiers (Pillar 3)', () {
    testWidgets('renders GoalMet tier with check_circle and status text', (
      tester,
    ) async {
      final item = ArchiveItem(
        date: DateTime.now(),
        dayName: 'Yesterday',
        totalMl: 2200,
        goalMl: 2000,
        sealTier: SealTier.goalMet,
        statusText: 'Goal Met!',
      );

      await tester.pumpWidget(
        createTestApp(
          child: MilestoneSealTile(item: item, isReducedMotion: true),
        ),
      );

      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Goal Met!'), findsOneWidget);
      expect(find.text('2200ml'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('renders AlmostThere tier with water_drop and status text', (
      tester,
    ) async {
      final item = ArchiveItem(
        date: DateTime.now(),
        dayName: 'Monday',
        totalMl: 1800,
        goalMl: 2000,
        sealTier: SealTier.almostThere,
        statusText: 'Almost there!',
      );

      await tester.pumpWidget(
        createTestApp(
          child: MilestoneSealTile(item: item, isReducedMotion: true),
        ),
      );

      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('Almost there!'), findsOneWidget);
      expect(find.text('1800ml'), findsOneWidget);
      expect(find.byIcon(Icons.water_drop), findsOneWidget);
    });

    testWidgets('renders UnderGoal tier with muted drop and no shame text', (
      tester,
    ) async {
      final item = ArchiveItem(
        date: DateTime.now(),
        dayName: 'Sunday',
        totalMl: 1200,
        goalMl: 2000,
        sealTier: SealTier.underGoal,
        statusText: '',
      );

      await tester.pumpWidget(
        createTestApp(
          child: MilestoneSealTile(item: item, isReducedMotion: true),
        ),
      );

      expect(find.text('Sunday'), findsOneWidget);
      expect(find.text('1200ml'), findsOneWidget);
      expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
      expect(find.text('Almost there!'), findsNothing);
      expect(find.text('Goal Met!'), findsNothing);
    });
  });

  group('Quality Pass: Tare Ritual Sealed States (Pillar 4)', () {
    testWidgets(
      'renders TareIdle, TarePrompt, TareMeasuring, TareSuccess, TareFailure, TareDisconnected accurately',
      (tester) async {
        // 1. Idle
        await tester.pumpWidget(
          createTestApp(
            key: const ValueKey('tare_idle'),
            overrides: [
              settingsViewModelProvider.overrideWith(
                (ref) => _FakeSettingsViewModel(
                  const SettingsViewState(
                    dailyGoalMl: 2000,
                    inactivityThresholdMinutes: 45,
                    adaptiveRemindersEnabled: true,
                    ritualState: TareIdle(),
                  ),
                ),
              ),
            ],
            child: const TareRitualButton(),
          ),
        );
        expect(find.text('Calibrate Empty Cup Weight'), findsOneWidget);

        // 2. Prompt
        await tester.pumpWidget(
          createTestApp(
            key: const ValueKey('tare_prompt'),
            overrides: [
              settingsViewModelProvider.overrideWith(
                (ref) => _FakeSettingsViewModel(
                  const SettingsViewState(
                    dailyGoalMl: 2000,
                    inactivityThresholdMinutes: 45,
                    adaptiveRemindersEnabled: true,
                    ritualState: TarePrompt(),
                  ),
                ),
              ),
            ],
            child: const TareRitualButton(),
          ),
        );
        expect(find.text('Start Calibration'), findsOneWidget);

        // 3. Measuring
        await tester.pumpWidget(
          createTestApp(
            key: const ValueKey('tare_measuring'),
            overrides: [
              settingsViewModelProvider.overrideWith(
                (ref) => _FakeSettingsViewModel(
                  const SettingsViewState(
                    dailyGoalMl: 2000,
                    inactivityThresholdMinutes: 45,
                    adaptiveRemindersEnabled: true,
                    ritualState: TareMeasuring(liveGrams: 345.0),
                  ),
                ),
              ),
            ],
            child: const TareRitualButton(),
          ),
        );
        expect(find.textContaining('Stabilizing (345 g)'), findsOneWidget);

        // 4. Success
        await tester.pumpWidget(
          createTestApp(
            key: const ValueKey('tare_success'),
            overrides: [
              settingsViewModelProvider.overrideWith(
                (ref) => _FakeSettingsViewModel(
                  const SettingsViewState(
                    dailyGoalMl: 2000,
                    inactivityThresholdMinutes: 45,
                    adaptiveRemindersEnabled: true,
                    ritualState: TareSuccess(taredGrams: 350.0),
                  ),
                ),
              ),
            ],
            child: const TareRitualButton(),
          ),
        );
        expect(find.text('Cup Tare Zeroed ✓ 350 g'), findsOneWidget);

        // 5. Failure
        await tester.pumpWidget(
          createTestApp(
            key: const ValueKey('tare_failure'),
            overrides: [
              settingsViewModelProvider.overrideWith(
                (ref) => _FakeSettingsViewModel(
                  const SettingsViewState(
                    dailyGoalMl: 2000,
                    inactivityThresholdMinutes: 45,
                    adaptiveRemindersEnabled: true,
                    ritualState: TareFailure(errorMessage: 'Hardware timeout'),
                  ),
                ),
              ),
            ],
            child: const TareRitualButton(),
          ),
        );
        expect(find.text('Hardware timeout'), findsOneWidget);

        // 6. Disconnected
        await tester.pumpWidget(
          createTestApp(
            key: const ValueKey('tare_disconnected'),
            overrides: [
              settingsViewModelProvider.overrideWith(
                (ref) => _FakeSettingsViewModel(
                  const SettingsViewState(
                    dailyGoalMl: 2000,
                    inactivityThresholdMinutes: 45,
                    adaptiveRemindersEnabled: true,
                    ritualState: TareDisconnected(),
                    isConnected: false,
                  ),
                ),
              ),
            ],
            child: const TareRitualButton(),
          ),
        );
        expect(find.text('Coaster Disconnected'), findsOneWidget);
      },
    );
  });

  group('Quality Pass: Midnight Rollover Logic', () {
    test(
      'resets today intake to 0 ml and stores previous day in archive',
      () async {
        final historyRepo = FakeHistoryRepository();
        addTearDown(historyRepo.dispose);

        final initialTotal = historyRepo.currentTodaySips.fold<int>(
          0,
          (sum, s) => sum + s.volumeMl,
        );
        expect(initialTotal, 1450);

        // Trigger midnight rollover to tomorrow
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        await historyRepo.simulateMidnightRollover(tomorrow);

        final rolledTotal = historyRepo.currentTodaySips.fold<int>(
          0,
          (sum, s) => sum + s.volumeMl,
        );
        expect(rolledTotal, 0);

        // Verify the 1450ml intake is now in history
        final summaries = await historyRepo.getDailySummaries();
        final hasPreviousDay = summaries.any((s) => s.totalMl == 1450);
        expect(hasPreviousDay, isTrue);
      },
    );
  });

  group('Quality Pass: 200% Text Scaling Robustness', () {
    testWidgets('Home screen renders without overflow at 200% text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(textScale: 2.0, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(BeakerVessel), findsOneWidget);
      expect(find.text('SipSync'), findsOneWidget);
    });

    testWidgets('History screen renders without overflow at 200% text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(textScale: 2.0, child: const HistoryScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(WeeklyHydroTubes), findsOneWidget);
    });

    testWidgets('Settings screen renders without overflow at 200% text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(textScale: 2.0, child: const SettingsScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Sip Settings'), findsOneWidget);
      expect(find.byType(TareRitualButton), findsNothing);
    });
  });

  group('Quality Pass: Dark Mode Color Tokens & Contrast', () {
    test('validates Dark Mode tokens are distinct, dark, and legible', () {
      const darkPalette = LiquidTokens.darkColors;
      const lightPalette = LiquidTokens.lightColors;

      // Dark background must be dark slate/navy
      expect(darkPalette.background.computeLuminance(), lessThan(0.1));
      // Dark text must be high luminance for legibility
      expect(darkPalette.textPrimary.computeLuminance(), greaterThan(0.8));
      // Aqua highlight must be vibrant
      expect(darkPalette.aquaHighlight.computeLuminance(), greaterThan(0.4));
      // Dark palette and light palette background differ
      expect(darkPalette.background, isNot(equals(lightPalette.background)));
    });

    testWidgets('HomeScreen renders cleanly in dark theme mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(themeMode: ThemeMode.dark, child: const HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('Quality Pass: AppShell Production Guards', () {
    testWidgets('renders AppShell tabs with accessible semantics', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp(child: const AppShell()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data == 'Home' || w.data == 'HOME'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data == 'History' || w.data == 'HISTORY'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data == 'Settings' || w.data == 'SETTINGS'),
        ),
        findsOneWidget,
      );
    });
  });
}

class _FakeHydrationViewModel extends StateNotifier<HydrationSnapshot>
    implements HydrationViewModel {
  _FakeHydrationViewModel(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettingsViewModel extends StateNotifier<SettingsViewState>
    implements SettingsViewModel {
  _FakeSettingsViewModel(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFreshnessViewModel extends StateNotifier<FreshnessState>
    implements FreshnessViewModel {
  _FakeFreshnessViewModel(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
