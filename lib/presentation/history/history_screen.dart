import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/liquid_theme.dart';
import '../theme/liquid_tokens.dart';
import '../theme/reduced_motion.dart';
import '../view_models/history_view_model.dart';
import '../view_models/hydration_view_model.dart';
import '../widgets/glass_card.dart';
import 'widgets/arcade_history.dart';
import 'widgets/milestone_seal_tile.dart';

/// Saved hydration history using the shared application surfaces.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

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
    final palette = context.liquidColors;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Sip History',
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
              WeeklyTelemetry(history: history, level: level),
              const SizedBox(height: LiquidTokens.spaceMd),
              WeeklyHydroTubes(
                columns: columns,
                reducedMotion: reducedMotion,
                isEmpty: history.isEmpty,
              ),
              const SizedBox(height: 24),
              Text(
                'Archive',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (history.archiveEntries.isEmpty)
                const GlassCard(
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
      ),
    );
  }
}
