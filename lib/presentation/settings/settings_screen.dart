import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/liquid_theme.dart';
import '../theme/liquid_tokens.dart';
import '../view_models/settings_view_model.dart';
import '../widgets/glass_card.dart';
import '../widgets/sip_tab_header.dart';
import '../widgets/raid_badges.dart';
import 'widgets/droplet_slider.dart';
import '../widgets/coaster_connection_card.dart';

/// Settings presentation shares the minimalist Home and History typography.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Theme(
    data: LiquidTheme.homeTheme(Theme.of(context).brightness),
    child: const _SettingsContent(),
  );
}

class _SettingsContent extends ConsumerWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.liquidColors;
    final settings = ref.watch(settingsViewModelProvider);
    final vm = ref.read(settingsViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SipTabHeader(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sip Settings',
                            style: sipHeaderTitleStyle(context),
                          ),
                          const SizedBox(height: 3),
                          const SipHeaderXpLabel(tabName: 'Settings'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const SipHeaderActions(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(LiquidTokens.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Daily Goal Card
                    GlassCard(
                      padding: const EdgeInsets.all(LiquidTokens.spaceLg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.water_drop_outlined,
                                size: 18,
                                color: palette.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Daily Goal',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: LiquidTokens.spaceSm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${settings.dailyGoalMl}',
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w600,
                                  color: palette.textPrimary,
                                  letterSpacing: -1.0,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ml',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: LiquidTokens.spaceMd),
                          _SettingsInset(
                            child: DropletSlider(
                              value: settings.dailyGoalMl.toDouble(),
                              min: 1000.0,
                              max: 4000.0,
                              step: 100.0,
                              unit: 'ml',
                              minLabel: '1L',
                              maxLabel: '4L',
                              label: 'Daily Water Goal',
                              onChanged: (val) =>
                                  vm.previewDailyGoal(val.round()),
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
                          Row(
                            children: [
                              Icon(Icons.local_drink_outlined, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your fixed cup',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          _SettingsInset(
                            child: Text(
                              'Empty cup: 258 g\nSafe filled weight: 655 g\nAutomatic refill at or below: 350 g',
                              style: TextStyle(fontSize: 14, height: 1.8),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Start the coaster with the cup removed. Use only the supported cup. The coaster handles refilling and drinking reminders automatically.',
                            style: TextStyle(fontSize: 13, height: 1.6),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft inset groups existing values without introducing additional controls.
class _SettingsInset extends StatelessWidget {
  const _SettingsInset({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? context.liquidColors.primary.withValues(alpha: 0.08)
          : const Color(0xFFF4F2FF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}
