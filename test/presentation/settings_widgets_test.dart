import '../support/test_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_store/data/fake/fake_coaster_repository.dart';
import 'package:liquid_store/data/fake/fake_settings_repository.dart';
import 'package:liquid_store/data/providers.dart';
import 'package:liquid_store/domain/domain.dart';
import 'package:liquid_store/presentation/settings/settings_screen.dart';
import 'package:liquid_store/presentation/settings/widgets/widgets.dart';
import 'package:liquid_store/presentation/view_models/hydration_view_model.dart';
import 'package:liquid_store/presentation/view_models/settings_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget({
    required Widget child,
    List<dynamic> overrides = const [],
    bool reduceMotion = false,
  }) {
    return TestProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('DropletSlider (Pillar 4)', () {
    testWidgets('renders min and max labels beneath track', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: DropletSlider(
            value: 2000,
            min: 1000,
            max: 4000,
            step: 100,
            minLabel: '1L',
            maxLabel: '4L',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('1L'), findsOneWidget);
      expect(find.text('4L'), findsOneWidget);
    });

    testWidgets(
      'drag updates value continuously and clamps strictly within bounds',
      (tester) async {
        double latestVal = 2000;
        double? committedVal;

        await tester.pumpWidget(
          createTestWidget(
            child: SizedBox(
              width: 300,
              child: DropletSlider(
                value: latestVal,
                min: 1000,
                max: 4000,
                step: 100,
                onChanged: (v) => latestVal = v,
                onChangeEnd: (v) => committedVal = v,
              ),
            ),
          ),
        );

        final sliderFinder = find.byType(DropletSlider);

        // Drag far to the right (past 4000)
        await tester.drag(sliderFinder, const Offset(600, 0));
        await tester.pumpAndSettle();

        expect(latestVal, 4000.0);
        expect(committedVal, 4000.0);

        // Drag far to the left (past 1000)
        await tester.drag(sliderFinder, const Offset(-900, 0));
        await tester.pumpAndSettle();

        expect(latestVal, 1000.0);
        expect(committedVal, 1000.0);
      },
    );

    testWidgets('tap-to-position jumps/settles to tapped position', (
      tester,
    ) async {
      double? changedVal;
      double? committedVal;

      await tester.pumpWidget(
        createTestWidget(
          child: Center(
            child: SizedBox(
              width: 300,
              child: DropletSlider(
                value: 1000,
                min: 1000,
                max: 4000,
                step: 100,
                onChanged: (v) => changedVal = v,
                onChangeEnd: (v) => committedVal = v,
              ),
            ),
          ),
        ),
      );

      // Tap near the center (should be ~2500)
      await tester.tap(find.byType(DropletSlider));
      await tester.pumpAndSettle();

      expect(changedVal, isNotNull);
      expect(committedVal, isNotNull);
      expect(changedVal, greaterThan(1500));
      expect(changedVal, lessThan(3500));
    });

    testWidgets(
      'reduced motion mode snaps thumb instantly without spring bounce',
      (tester) async {
        double latestVal = 2000;

        await tester.pumpWidget(
          createTestWidget(
            reduceMotion: true,
            child: SizedBox(
              width: 300,
              child: DropletSlider(
                value: latestVal,
                min: 1000,
                max: 4000,
                step: 100,
                onChanged: (v) => latestVal = v,
              ),
            ),
          ),
        );

        await tester.drag(find.byType(DropletSlider), const Offset(100, 0));
        // With reduced motion, single pump reflects final snap position immediately
        await tester.pump();
        expect(latestVal, greaterThan(2000));
      },
    );

    testWidgets(
      'disabled state renders with reduced opacity and ignores gestures',
      (tester) async {
        double latestVal = 2000;

        await tester.pumpWidget(
          createTestWidget(
            child: SizedBox(
              width: 300,
              child: DropletSlider(
                value: latestVal,
                min: 1000,
                max: 4000,
                step: 100,
                enabled: false,
                onChanged: (v) => latestVal = v,
              ),
            ),
          ),
        );

        await tester.drag(find.byType(DropletSlider), const Offset(200, 0));
        await tester.pumpAndSettle();

        // Value should remain unchanged because slider is disabled
        expect(latestVal, 2000.0);

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(DropletSlider),
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(animatedOpacity.opacity, 0.38);
      },
    );

    testWidgets('semantics accessibility exposes slider role and value', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          child: DropletSlider(
            value: 2500,
            min: 1000,
            max: 4000,
            step: 100,
            unit: 'ml',
            label: 'Daily Water Goal',
            onChanged: (_) {},
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(DropletSlider));
      expect(semantics.label, 'Daily Water Goal');
      expect(semantics.value, '2500 ml');
    });
  });

  group('LiquidSwitch (Pillar 4)', () {
    testWidgets('renders and calls onChanged with toggled value on tap', (
      tester,
    ) async {
      bool switchValue = true;

      await tester.pumpWidget(
        createTestWidget(
          child: StatefulBuilder(
            builder: (context, setState) {
              return LiquidSwitch(
                value: switchValue,
                onChanged: (val) => setState(() => switchValue = val),
              );
            },
          ),
        ),
      );

      expect(switchValue, isTrue);

      await tester.tap(find.byType(LiquidSwitch));
      await tester.pumpAndSettle();

      expect(switchValue, isFalse);

      await tester.tap(find.byType(LiquidSwitch));
      await tester.pumpAndSettle();

      expect(switchValue, isTrue);
    });
  });

  group('TareRitualButton (Pillar 4)', () {
    testWidgets(
      'renders idle state with helper text and enters prompt on tap',
      (tester) async {
        final coasterRepo = FakeCoasterRepository();
        final container = createTestContainer(
          overrides: [coasterRepositoryProvider.overrideWithValue(coasterRepo)],
        );
        addTearDown(container.dispose);
        addTearDown(coasterRepo.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: TareRitualButton())),
          ),
        );

        expect(find.text('Calibrate Empty Cup Weight'), findsOneWidget);
        expect(
          find.textContaining('Calibrate your coaster once with an empty cup'),
          findsOneWidget,
        );

        // Tap to prompt
        await tester.tap(find.text('Calibrate Empty Cup Weight'));
        await tester.pumpAndSettle();

        expect(find.text('Place Empty Cup on Coaster'), findsOneWidget);
        expect(find.text('Start Calibration'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        // Cancel returns to idle
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Calibrate Empty Cup Weight'), findsOneWidget);
      },
    );

    testWidgets(
      'calibration flow shows measuring with live weight and succeeds',
      (tester) async {
        final coasterRepo = FakeCoasterRepository();
        coasterRepo.setNextCalibrationOutcome(
          status: CalibrationStatus.success,
          measuredGrams: 350.0,
        );
        final container = createTestContainer(
          overrides: [coasterRepositoryProvider.overrideWithValue(coasterRepo)],
        );
        addTearDown(container.dispose);
        addTearDown(coasterRepo.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: TareRitualButton())),
          ),
        );

        // Tap to prompt
        await tester.tap(find.text('Calibrate Empty Cup Weight'));
        await tester.pumpAndSettle();

        // Tap Start Calibration
        await tester.tap(find.text('Start Calibration'));
        await tester.pump(); // Start measuring

        expect(find.textContaining('Zeroing Empty Cup'), findsOneWidget);

        // Simulate live weight reading during measurement
        coasterRepo.simulateWeightChange(348.0);
        await tester.pump();
        expect(find.textContaining('Stabilizing (348 g)'), findsOneWidget);

        // Let calibration complete (FakeCoasterRepository takes 600ms)
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        expect(find.text('Cup Tare Zeroed ✓ 350 g'), findsOneWidget);
        expect(
          find.text('Scale ready for water intake tracking.'),
          findsOneWidget,
        );

        // Auto-reverts to idle after 3 seconds
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        expect(find.text('Calibrate Empty Cup Weight'), findsOneWidget);
      },
    );

    testWidgets(
      'bluetooth disconnect mid-measuring aborts routine and renders TareDisconnected',
      (tester) async {
        final coasterRepo = FakeCoasterRepository();
        final container = createTestContainer(
          overrides: [coasterRepositoryProvider.overrideWithValue(coasterRepo)],
        );
        addTearDown(container.dispose);
        addTearDown(coasterRepo.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: TareRitualButton())),
          ),
        );

        // Enter prompt and start calibration
        await tester.tap(find.text('Calibrate Empty Cup Weight'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start Calibration'));
        await tester.pump();
        expect(find.textContaining('Zeroing Empty Cup'), findsOneWidget);

        // Coaster drops connection while measuring
        coasterRepo.simulateConnection(ConnectionStatus.disconnected);
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        expect(find.text('Coaster Disconnected'), findsOneWidget);
        expect(
          find.text('Connect your coaster to calibrate empty cup weight.'),
          findsOneWidget,
        );
      },
    );

    test('multiple rapid taps on start calibration are debounced', () async {
      final coasterRepo = FakeCoasterRepository();
      final container = createTestContainer(
        overrides: [coasterRepositoryProvider.overrideWithValue(coasterRepo)],
      );
      addTearDown(container.dispose);
      addTearDown(coasterRepo.dispose);

      final vm = container.read(settingsViewModelProvider.notifier);
      vm.promptTare();

      // Dispatch 3 calibration attempts concurrently
      final f1 = vm.confirmTare();
      final f2 = vm.startCalibration();
      final f3 = vm.startCalibration();

      await Future.wait([f1, f2, f3]);

      final state = container.read(settingsViewModelProvider);
      expect(state.ritualState, isA<TareSuccess>());
    });

    testWidgets('calibration failure displays error banner with retry option', (
      tester,
    ) async {
      final coasterRepo = FakeCoasterRepository();
      coasterRepo.setNextCalibrationOutcome(
        status: CalibrationStatus.failure,
        errorMessage: 'Scale surface is vibrating',
      );
      final container = createTestContainer(
        overrides: [coasterRepositoryProvider.overrideWithValue(coasterRepo)],
      );
      addTearDown(container.dispose);
      addTearDown(coasterRepo.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: TareRitualButton())),
        ),
      );

      await tester.tap(find.text('Calibrate Empty Cup Weight'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Calibration'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.text('Scale surface is vibrating'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Dismiss button resets to idle
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();

      expect(find.text('Calibrate Empty Cup Weight'), findsOneWidget);
    });

    testWidgets('initially disconnected coaster displays disabled button', (
      tester,
    ) async {
      final coasterRepo = FakeCoasterRepository();
      coasterRepo.simulateConnection(ConnectionStatus.disconnected);

      final container = createTestContainer(
        overrides: [coasterRepositoryProvider.overrideWithValue(coasterRepo)],
      );
      addTearDown(container.dispose);
      addTearDown(coasterRepo.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: TareRitualButton())),
        ),
      );

      expect(find.text('Coaster Disconnected'), findsOneWidget);
      expect(
        find.text('Connect your coaster to calibrate empty cup weight.'),
        findsOneWidget,
      );
    });
  });

  group('SettingsScreen Assembly & Cross-Screen Reactivity (Pillar 4)', () {
    testWidgets('renders all cards and sections matching reference', (
      tester,
    ) async {
      final settingsRepo = FakeSettingsRepository();
      final coasterRepo = FakeCoasterRepository();

      await tester.pumpWidget(
        TestProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
            coasterRepositoryProvider.overrideWithValue(coasterRepo),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      expect(find.text('Sip Settings'), findsOneWidget);
      expect(find.text('Daily Goal'), findsOneWidget);
      expect(find.text('2000'), findsOneWidget);
      expect(find.text('ml'), findsWidgets);
      expect(find.text('Adaptive Reminders'), findsNothing);
      expect(find.text('Inactivity Threshold'), findsNothing);
      expect(find.text('Your fixed cup'), findsOneWidget);
      expect(find.text('Calibrate Empty Cup Weight'), findsNothing);
    });

    testWidgets(
      'production settings expose one goal slider and the fixed cup',
      (tester) async {
        await tester.pumpWidget(
          TestProviderScope(child: const MaterialApp(home: SettingsScreen())),
        );
        await tester.pump();
        expect(find.byType(DropletSlider), findsOneWidget);
        expect(find.byType(LiquidSwitch), findsNothing);
        expect(find.byType(TareRitualButton), findsNothing);
        expect(find.textContaining('258 g'), findsOneWidget);
      },
    );

    test(
      'changing daily goal updates SettingsRepository and triggers HydrationViewModel re-tween',
      () async {
        final settingsRepo = FakeSettingsRepository();
        final coasterRepo = FakeCoasterRepository();

        final container = createTestContainer(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
            coasterRepositoryProvider.overrideWithValue(coasterRepo),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(coasterRepo.dispose);

        // Initial hydration state has goalMl 2000
        expect(container.read(hydrationViewModelProvider).goalMl, 2000);

        final settingsVm = container.read(settingsViewModelProvider.notifier);
        await settingsVm.updateDailyGoal(3000);

        // Verify settings persisted in repo
        expect(settingsRepo.currentSettings.dailyGoalMl, 3000);

        // Small delay for stream broadcast to downstream hydration VM
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // Hydration VM automatically received updated goal
        expect(container.read(hydrationViewModelProvider).goalMl, 3000);
      },
    );

    test(
      'dragging slider while coaster is disconnected updates settings cleanly',
      () async {
        final settingsRepo = FakeSettingsRepository();
        final coasterRepo = FakeCoasterRepository();
        coasterRepo.simulateConnection(ConnectionStatus.disconnected);

        final container = createTestContainer(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
            coasterRepositoryProvider.overrideWithValue(coasterRepo),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(coasterRepo.dispose);

        final settingsVm = container.read(settingsViewModelProvider.notifier);
        await settingsVm.updateDailyGoal(2800);

        expect(settingsRepo.currentSettings.dailyGoalMl, 2800);
        expect(container.read(settingsViewModelProvider).dailyGoalMl, 2800);
      },
    );
  });
}
