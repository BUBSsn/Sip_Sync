import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/liquid_theme.dart';
import '../theme/liquid_tokens.dart';
import '../theme/reduced_motion.dart';
import '../widgets/sip_tab_header.dart';
import '../view_models/history_view_model.dart';
import '../view_models/hydration_view_model.dart';
import 'widgets/arcade_history.dart';
import 'widgets/milestone_seal_tile.dart';

/// History screen displaying arcade telemetry, hydro tubes, badges, and past archive records.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    return Theme(
      data: LiquidTheme.homeTheme(brightness),
      child: const _HistoryContent(),
    );
  }
}

class _HistoryContent extends ConsumerWidget {
  const _HistoryContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyViewModelProvider);
    final level = ref.watch(
      hydrationViewModelProvider.select((state) => state.level),
    );
    final goal = ref.watch(
      hydrationViewModelProvider.select((state) => state.goalMl),
    );
    final now = DateTime.now();
    final columns = history.weeklyColumns.isNotEmpty
        ? history.weeklyColumns
        : List.generate(7, (index) {
            final date = DateTime(now.year, now.month, now.day - 6 + index);
            return WeeklyDayColumn(
              dayLabel: const [
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun',
              ][date.weekday - 1],
              date: date,
              totalMl: 0,
              goalMl: goal,
              progress: 0,
              isToday: index == 6,
            );
          });
    final reducedMotion = shouldReduceMotion(context, ref);
    final colors = context.liquidColors;

    return Scaffold(
      backgroundColor: colors.background,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Sip History',
                            style: sipHeaderTitleStyle(context),
                          ),
                          const SizedBox(height: 3),
                          const SipHeaderXpLabel(tabName: 'History'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const SipHeaderActions(),
                  ],
                ),
              ),

              // Scrollable Content
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LiquidTokens.spaceMd,
                  vertical: LiquidTokens.spaceMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    WeeklyTelemetry(history: history, level: level),
                    const SizedBox(height: LiquidTokens.spaceMd),
                    WeeklyHydroTubes(
                      columns: columns,
                      archiveEntries: history.archiveEntries,
                      reducedMotion: reducedMotion,
                      isEmpty: history.isEmpty,
                    ),
                    const SizedBox(height: LiquidTokens.spaceMd),
                    const UnlockedBadgesCard(),
                    const SizedBox(height: 24),
                    Text(
                      'Archive',
                      style: TextStyle(
                        fontFamily: LiquidTheme.homeFont,
                        fontFamilyFallback: LiquidTheme.homeFontFallback,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (history.archiveEntries.isEmpty)
                      const TelemetryPanel(
                        padding: EdgeInsets.all(20),
                        child: Text('No past archive records yet'),
                      )
                    else
                      for (final item in history.archiveEntries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: MilestoneSealTile(
                            item: item,
                            ambientPhase: 0,
                            isReducedMotion: reducedMotion,
                          ),
                        ),
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
