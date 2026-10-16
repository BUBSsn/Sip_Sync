import '../support/test_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_store/presentation/theme/reduced_motion.dart';
import 'package:liquid_store/presentation/widgets/glass_card.dart';

void main() {
  testWidgets('GlassCard renders BackdropFilter when reduced effects is off', (
    tester,
  ) async {
    await tester.pumpWidget(
      const TestProviderScope(
        child: MaterialApp(
          home: Scaffold(body: GlassCard(child: Text('Frosted Content'))),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Frosted Content'), findsOneWidget);
  });

  testWidgets(
    'GlassCard renders solid fallback without BackdropFilter when reduced effects is on',
    (tester) async {
      await tester.pumpWidget(
        TestProviderScope(
          overrides: [manualReducedEffectsProvider.overrideWith((ref) => true)],
          child: const MaterialApp(
            home: Scaffold(
              body: GlassCard(child: Text('Solid Fallback Content')),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('Solid Fallback Content'), findsOneWidget);
    },
  );
}
