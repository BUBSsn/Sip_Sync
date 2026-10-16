import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/liquid_theme.dart';
import '../theme/liquid_tokens.dart';
import '../view_models/settings_view_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/raid_badges.dart';
import 'widgets/droplet_slider.dart';
import '../widgets/coaster_connection_card.dart';

/// Full production Sip Settings screen for SipSync (Pillar 4).
///
/// Implements visual reference hierarchy from `docs/reference/settings.png`:
/// 1. "Sip Settings" title
/// 2. Daily Goal card with prominent "2000 ml" readout and elastic [DropletSlider]
/// 3. Adaptive Reminders card with [LiquidSwitch] and nested Inactivity Threshold
/// 4. Tactile [TareRitualButton] hardware calibration state machine
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.liquidColors;
    final settings = ref.watch(settingsViewModelProvider);
    final vm = ref.read(settingsViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Sip Settings',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: palette.primary,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: LiquidTokens.spaceMd,
            vertical: LiquidTokens.spaceSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Daily Goal Card
              GlassCard(
                padding: const EdgeInsets.all(LiquidTokens.spaceLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Daily Goal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: LiquidTokens.spaceSm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${settings.dailyGoalMl}',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: palette.primary,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ml',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: palette.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: LiquidTokens.spaceMd),
                    DropletSlider(
                      value: settings.dailyGoalMl.toDouble(),
                      min: 1000.0,
                      max: 4000.0,
                      step: 100.0,
                      unit: 'ml',
                      minLabel: '1L',
                      maxLabel: '4L',
                      label: 'Daily Water Goal',
                      onChanged: (val) => vm.previewDailyGoal(val.round()),
                      onChangeEnd: (val) async {
                        try {
                          await vm.updateDailyGoal(val.round());
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not save the daily goal. Please retry.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: LiquidTokens.spaceMd),

              const CoasterConnectionCard(),
              const SizedBox(height: LiquidTokens.spaceMd),
              const GlassCard(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your fixed cup',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Empty cup: 258 g\nSafe filled weight: 655 g\nAutomatic refill at or below: 350 g',
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Start the coaster with the cup removed. Use only the supported cup. The coaster handles refilling and drinking reminders automatically.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: LiquidTokens.spaceMd),
              const RaidBadgeCollection(),
              const SizedBox(height: LiquidTokens.spaceXl),
            ],
          ),
        ),
      ),
    );
  }
}
