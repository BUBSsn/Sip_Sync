import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/liquid_theme.dart';
import '../theme/liquid_tokens.dart';
import '../theme/reduced_motion.dart';
import '../theme/theme_mode_provider.dart';
import '../view_models/history_view_model.dart';
import '../view_models/hydration_view_model.dart';
import 'widgets/arcade_history.dart';
import 'widgets/milestone_seal_tile.dart';

String _formatNumber(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
}

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar Header matching reference
              Container(
                color: colors.surface,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Sip History',
                              style: TextStyle(
                                fontFamily: LiquidTheme.homeFont,
                                fontFamilyFallback:
                                    LiquidTheme.homeFontFallback,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                                color: isDark
                                    ? colors.textPrimary
                                    : const Color(0xFF0F3B4C),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6CF5B0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF064E3B),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'ONLINE',
                                    style: TextStyle(
                                      fontFamily: LiquidTheme.homeFont,
                                      fontFamilyFallback:
                                          LiquidTheme.homeFontFallback,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.1,
                                      color: Color(0xFF064E3B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'History · LVL $level [${_formatNumber(level * 250)} XP]',
                            style: TextStyle(
                              fontFamily: LiquidTheme.homeFont,
                              fontFamilyFallback: LiquidTheme.homeFontFallback,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.0,
                              color: isDark
                                  ? const Color(0xFF7DD3FC)
                                  : const Color(0xFF388E9C),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Right header controls: Battery pill, Theme Toggle, Avatar
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFE6EEF8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.battery_5_bar,
                                size: 15,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF334155),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '94%',
                                style: TextStyle(
                                  fontFamily: LiquidTheme.homeFont,
                                  fontFamilyFallback:
                                      LiquidTheme.homeFontFallback,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          button: true,
                          label: isDark
                              ? 'Switch to light mode'
                              : 'Switch to dark mode',
                          child: Tooltip(
                            message: isDark
                                ? 'Switch to light mode'
                                : 'Switch to dark mode',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  LiquidTokens.radiusPill,
                                ),
                                onTap: () {
                                  ref.read(themeModeProvider.notifier).toggle();
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? colors.primary.withValues(alpha: 0.18)
                                        : const Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? colors.aquaHighlight.withValues(
                                              alpha: 0.35,
                                            )
                                          : const Color(0xFFE2E8F0),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isDark
                                          ? Icons.light_mode_rounded
                                          : Icons.dark_mode_outlined,
                                      color: isDark
                                          ? colors.aquaHighlight
                                          : const Color(0xFF006677),
                                      size: 19,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF075E6C),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ],
                    ),
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
