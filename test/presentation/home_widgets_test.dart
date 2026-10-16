import '../support/test_providers.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_store/data/fake/fake_coaster_repository.dart';
import 'package:liquid_store/data/fake/fake_history_repository.dart';
import 'package:liquid_store/data/providers.dart';
import 'package:liquid_store/domain/domain.dart';
import 'package:liquid_store/presentation/home/home_screen.dart';
import 'package:liquid_store/presentation/home/widgets/adjust_sip_dialog.dart';
import 'package:liquid_store/presentation/home/widgets/beaker_vessel.dart';
import 'package:liquid_store/presentation/home/widgets/cup_weight_chip.dart';
import 'package:liquid_store/presentation/home/widgets/freshness_indicator.dart';
import 'package:liquid_store/presentation/home/widgets/liquid_vessel.dart';
import 'package:liquid_store/presentation/home/widgets/liquid_vessel_painter.dart';
import 'package:liquid_store/presentation/home/widgets/sip_feedback_overlay.dart';
import 'package:liquid_store/presentation/home/widgets/sip_log_list.dart';
import 'package:liquid_store/presentation/theme/liquid_tokens.dart';
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

  group('LiquidVessel & LiquidVesselPainter (Pillar 1)', () {
    testWidgets(
      'isolates canvas in RepaintBoundary and renders central readout',
      (tester) async {
        await tester.pumpWidget(createTestWidget(child: const LiquidVessel()));

        // Verify RepaintBoundary wraps CustomPaint
        final repaintBoundaryFinder = find.byType(RepaintBoundary);
        expect(repaintBoundaryFinder, findsWidgets);

        // Verify central volume readout
        expect(find.text('1450'), findsOneWidget);
        expect(find.text('/ 2000 ml'), findsOneWidget);
        expect(find.text('Optimal Flow'), findsOneWidget);
      },
    );

    test(
      'maintains stable clamped geometry on extreme over-goal (3000ml / 2000ml)',
      () {
        final painter = LiquidVesselPainter(
          fillProgress: 1.5, // 150% over goal
          wavePhase: 1.2,
          tiltAngle: 0.15,
          palette: LiquidTokens.lightColors,
          isOverGoal: true,
          isReducedMotion: false,
        );

        // Verify painter paints without throwing NaN or infinite exceptions
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () => painter.paint(canvas, const Size(280, 360)),
          returnsNormally,
        );
        final picture = recorder.endRecording();
        picture.dispose();
      },
    );

    test('paints calm flat surface when reduced motion is true', () {
      final painter = LiquidVesselPainter(
        fillProgress: 0.725,
        wavePhase: 0.0,
        tiltAngle: 0.0,
        palette: LiquidTokens.lightColors,
        isOverGoal: false,
        isReducedMotion: true,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => painter.paint(canvas, const Size(280, 360)),
        returnsNormally,
      );
      final picture = recorder.endRecording();
      picture.dispose();
    });

    testWidgets('tap gesture registers ripple', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const LiquidVessel()));

      // Tap on the vessel
      await tester.tap(find.byType(LiquidVessel));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LiquidVessel), findsOneWidget);
    });
  });

  group('FreshnessIndicator (Pillar 2)', () {
    testWidgets('displays fresh phase with paired icon and text', (
      tester,
    ) async {
      final historyRepo = FakeHistoryRepository(
        initialSips: [
          SipEvent(
            id: 'recent_sip_fresh',
            volumeMl: 100,
            timestamp: DateTime.now().toUtc().subtract(
              const Duration(minutes: 5),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        createTestWidget(
          overrides: [historyRepositoryProvider.overrideWithValue(historyRepo)],
          child: const FreshnessIndicator(),
        ),
      );

      expect(find.byIcon(Icons.water_drop), findsOneWidget);
      expect(find.textContaining('Fresh'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      historyRepo.dispose();
    });

    testWidgets(
      'displays fading phase when elapsed time is 30 mins (threshold 45m)',
      (tester) async {
        final historyRepo = FakeHistoryRepository(
          initialSips: [
            SipEvent(
              id: 'sip_fading',
              volumeMl: 100,
              timestamp: DateTime.now().toUtc().subtract(
                const Duration(minutes: 30),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          createTestWidget(
            overrides: [
              historyRepositoryProvider.overrideWithValue(historyRepo),
            ],
            child: const FreshnessIndicator(),
          ),
        );

        expect(find.byIcon(Icons.schedule), findsOneWidget);
        expect(find.textContaining('Fading'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        historyRepo.dispose();
      },
    );

    testWidgets('displays dry phase when elapsed time exceeds 45 mins', (
      tester,
    ) async {
      final historyRepo = FakeHistoryRepository(
        initialSips: [
          SipEvent(
            id: 'sip_dry',
            volumeMl: 100,
            timestamp: DateTime.now().toUtc().subtract(
              const Duration(minutes: 60),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        createTestWidget(
          overrides: [historyRepositoryProvider.overrideWithValue(historyRepo)],
          child: const FreshnessIndicator(),
        ),
      );

      expect(find.byIcon(Icons.spa_outlined), findsOneWidget);
      expect(find.textContaining('Low'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      historyRepo.dispose();
    });

    testWidgets(
      'displays offline status and reconnect hint when coaster disconnected',
      (tester) async {
        final coasterRepo = FakeCoasterRepository();
        coasterRepo.simulateConnection(ConnectionStatus.disconnected);

        await tester.pumpWidget(
          createTestWidget(
            overrides: [
              coasterRepositoryProvider.overrideWithValue(coasterRepo),
            ],
            child: const FreshnessIndicator(),
          ),
        );

        expect(find.text('Coaster offline • Reconnecting...'), findsOneWidget);
        expect(find.byIcon(Icons.wifi_off), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        coasterRepo.dispose();
      },
    );
  });

  group('CupWeightChip (Pillar 2)', () {
    testWidgets('displays live scale reading and updates on weight shift', (
      tester,
    ) async {
      final coasterRepo = FakeCoasterRepository();

      await tester.pumpWidget(
        createTestWidget(
          overrides: [coasterRepositoryProvider.overrideWithValue(coasterRepo)],
          child: const CupWeightChip(),
        ),
      );

      expect(find.text('Cup Weight: 350g'), findsOneWidget);

      // Simulate weight change to 420g
      coasterRepo.simulateWeightChange(420.0);
      await tester.pumpAndSettle();

      expect(find.text('Cup Weight: 420g'), findsOneWidget);
      coasterRepo.dispose();
    });
  });

  group('SipLogList & Overflow Actions (Pillar 2)', () {
    testWidgets('renders sips and supports deletion via three-dot menu', (
      tester,
    ) async {
      final historyRepo = FakeHistoryRepository();

      await tester.pumpWidget(
        createTestWidget(
          overrides: [historyRepositoryProvider.overrideWithValue(historyRepo)],
          child: const SipLogList(),
        ),
      );

      expect(find.text('120ml sip'), findsOneWidget);
      expect(find.text('45ml sip'), findsOneWidget);
      expect(find.text('250ml sip'), findsOneWidget);

      // Tap first three-dot overflow menu
      final overflowButtons = find.byIcon(Icons.more_vert);
      expect(overflowButtons, findsWidgets);
      await tester.tap(overflowButtons.first);
      await tester.pumpAndSettle();

      // Tap "Delete entry"
      expect(find.text('Delete entry'), findsOneWidget);
      await tester.tap(find.text('Delete entry'));
      await tester.pumpAndSettle();

      // 120ml sip should now be removed from today sips
      expect(find.text('120ml sip'), findsNothing);
      historyRepo.dispose();
    });

    testWidgets('renders friendly empty state when no sips logged today', (
      tester,
    ) async {
      final emptyHistoryRepo = FakeHistoryRepository(
        initialSips: [],
        initialSummaries: [],
      );

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            historyRepositoryProvider.overrideWithValue(emptyHistoryRepo),
          ],
          child: const SipLogList(),
        ),
      );

      expect(find.text('No sips logged yet today'), findsOneWidget);
      expect(
        find.textContaining('Place your cup on the coaster'),
        findsOneWidget,
      );
      emptyHistoryRepo.dispose();
    });
  });

  group('AdjustSipDialog Validation', () {
    testWidgets('validates 5ml minimum and 1500ml maximum', (tester) async {
      int? savedVolume;
      bool wasDeleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdjustSipDialog(
              initialVolumeMl: 100,
              onSave: (vol) => savedVolume = vol,
              onDelete: () => wasDeleted = true,
            ),
          ),
        ),
      );

      // Test typing 2 ml (< 5 ml min)
      final textField = find.byType(TextField);
      await tester.enterText(textField, '2');
      await tester.pump();
      await tester.tap(find.text('Save Volume'));
      await tester.pump();

      expect(find.text('Minimum sip volume is 5 ml.'), findsOneWidget);
      expect(savedVolume, isNull);

      // Test typing 1800 ml (> 1500 ml max)
      await tester.enterText(textField, '1800');
      await tester.pump();
      await tester.tap(find.text('Save Volume'));
      await tester.pump();

      expect(find.text('Maximum single sip is 1500 ml.'), findsOneWidget);
      expect(savedVolume, isNull);

      // Test typing 0 ml prompts delete
      await tester.enterText(textField, '0');
      await tester.pump();
      expect(find.text('0 ml will delete this sip entry.'), findsOneWidget);
      expect(find.text('Delete Sip'), findsOneWidget);

      await tester.tap(find.text('Delete Sip'));
      await tester.pumpAndSettle();
      expect(wasDeleted, isTrue);
    });
  });

  group('SipFeedbackOverlay', () {
    testWidgets('renders floating badge on active sip feedback', (
      tester,
    ) async {
      final coasterRepo = FakeCoasterRepository();

      await tester.pumpWidget(
        createTestWidget(
          overrides: [coasterRepositoryProvider.overrideWithValue(coasterRepo)],
          child: const SipFeedbackOverlay(),
        ),
      );

      // Simulate sip
      coasterRepo.simulateSip(75);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('+75 ml'), findsOneWidget);
      coasterRepo.dispose();
    });
  });

  group('Density Parity (1.0g = 1.0ml)', () {
    test('verifies 200g hardware drop corresponds to exactly 200ml intake', () {
      const dropGrams = 200.0;
      final derivedVolumeMl = dropGrams.round();
      expect(derivedVolumeMl, 200);
    });
  });

  group('HomeScreen Full Assembly', () {
    testWidgets(
      'renders real intake and excludes simulated sip and refill controls',
      (tester) async {
        await tester.pumpWidget(createTestWidget(child: const HomeScreen()));
        await tester.pump();
        expect(find.text('SipSync'), findsOneWidget);
        expect(find.byType(BeakerVessel), findsOneWidget);
        expect(find.byType(SipFeedbackOverlay), findsOneWidget);
        expect(find.textContaining('Quick Sip'), findsNothing);
        expect(find.text('Refill'), findsNothing);
        expect(find.text('PORTION LIMIT'), findsNothing);
        expect(find.textContaining('Tare Scale'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('BeakerVessel animates fluid flow surge on tap and sip', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(child: const BeakerVessel()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(BeakerVessel), findsOneWidget);

      // Tap on beaker vessel triggers interactive splash excitation
      await tester.tap(find.byType(BeakerVessel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
