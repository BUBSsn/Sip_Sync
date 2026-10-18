import 'package:flutter/material.dart';

import '../../theme/liquid_theme.dart';
import '../../view_models/history_view_model.dart';

const telemetryTeal = Color(0xFF00758F);
const telemetryCyan = Color(0xFF00B4D8);
const telemetryMint = Color(0xFF52DE97);

TextStyle telemetryType({
  double size = 11,
  Color? color,
  FontWeight fontWeight = FontWeight.w500,
  double? letterSpacing,
}) => TextStyle(
  fontFamily: LiquidTheme.homeFont,
  fontFamilyFallback: LiquidTheme.homeFontFallback,
  fontSize: size,
  fontWeight: fontWeight,
  letterSpacing: letterSpacing ?? 0,
  color: color ?? telemetryTeal,
);

String _formatNumber(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
}

/// Solid, rounded card surface with Apple-inspired borders and soft shadows.
class TelemetryPanel extends StatelessWidget {
  const TelemetryPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.liquidColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x22FFFFFF) : const Color(0xFFF0F1F5),
          width: 1.0,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Telemetry overview card displaying weekly total, daily average, and streak progression.
class WeeklyTelemetry extends StatelessWidget {
  const WeeklyTelemetry({
    super.key,
    required this.history,
    required this.level,
  });

  final HistoryViewState history;
  final int level;

  @override
  Widget build(BuildContext context) {
    final colors = context.liquidColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = history.weeklyColumns.fold<int>(
      0,
      (sum, day) => sum + day.totalMl,
    );
    final target = history.currentStreakDays + history.daysToNextTier;
    final progress = target > 0 ? history.currentStreakDays / target : 1.0;

    return TelemetryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Badges Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE8EBFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D6E77),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ARCADE TELEMETRY HUB',
                      style: TextStyle(
                        fontFamily: LiquidTheme.homeFont,
                        fontFamilyFallback: LiquidTheme.homeFontFallback,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.15,
                        color: isDark
                            ? const Color(0xFF818CF8)
                            : const Color(0xFF4338CA),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF065F46), const Color(0xFF047857)]
                        : [const Color(0xFF67F5AB), const Color(0xFF53ECC4)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '[ 2.5X XP MULTIPLIER ]',
                  style: TextStyle(
                    fontFamily: LiquidTheme.homeFont,
                    fontFamilyFallback: LiquidTheme.homeFontFallback,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    color: isDark ? Colors.white : const Color(0xFF064E3B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Stat Metrics Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        const Opacity(
                          opacity: 0,
                          child: SizedBox(
                            width: 0,
                            height: 0,
                            child: Text('Weekly total'),
                          ),
                        ),
                        Text(
                          'WEEKLY TOTAL',
                          style: TextStyle(
                            fontFamily: LiquidTheme.homeFont,
                            fontFamilyFallback: LiquidTheme.homeFontFallback,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            (total / 1000).toStringAsFixed(1),
                            style: TextStyle(
                              fontFamily: LiquidTheme.homeFont,
                              fontFamilyFallback: LiquidTheme.homeFontFallback,
                              fontSize: 36,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1.2,
                              color: isDark
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFF00758F),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Liters',
                            style: TextStyle(
                              fontFamily: LiquidTheme.homeFont,
                              fontFamilyFallback: LiquidTheme.homeFontFallback,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        const Opacity(
                          opacity: 0,
                          child: SizedBox(
                            width: 0,
                            height: 0,
                            child: Text('Daily average'),
                          ),
                        ),
                        Text(
                          'DAILY AVERAGE',
                          style: TextStyle(
                            fontFamily: LiquidTheme.homeFont,
                            fontFamilyFallback: LiquidTheme.homeFontFallback,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _formatNumber(history.averageIntakeMl),
                            style: TextStyle(
                              fontFamily: LiquidTheme.homeFont,
                              fontFamilyFallback: LiquidTheme.homeFontFallback,
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.8,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ml/day',
                            style: TextStyle(
                              fontFamily: LiquidTheme.homeFont,
                              fontFamilyFallback: LiquidTheme.homeFontFallback,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Streak Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.7)
                  : const Color(0xFFF3F5FD),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_fire_department_outlined,
                      color: isDark
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF1868DB),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Stack(
                        children: [
                          Opacity(
                            opacity: 0,
                            child: SizedBox(
                              width: 0,
                              height: 0,
                              child: Text(
                                '${history.currentStreakDays}-day streak',
                              ),
                            ),
                          ),
                          Text(
                            '${history.currentStreakDays}-Day Hydration Streak',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: TextStyle(
                              fontFamily: LiquidTheme.homeFont,
                              fontFamilyFallback: LiquidTheme.homeFontFallback,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      history.daysToNextTier == 0
                          ? 'MAX TIER'
                          : '${(progress * 100).round()}%\nTIER ${history.currentTier.index + 1}',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontFamily: LiquidTheme.homeFont,
                        fontFamilyFallback: LiquidTheme.homeFontFallback,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                        color: isDark
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 7,
                    color: isDark
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF00B4D8),
                    backgroundColor: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFDEE5FA),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Opacity(
                            opacity: 0,
                            child: SizedBox(
                              width: 0,
                              height: 0,
                              child: Text(
                                'Best streak: ${history.bestStreakDays} days',
                              ),
                            ),
                          ),
                          Text(
                            history.daysToNextTier == 0
                                ? 'Max Tier 5 Active · Keep your streak flowing'
                                : 'Tier ${history.currentTier.index + 1} unlocks in ${history.daysToNextTier} ${history.daysToNextTier == 1 ? "day" : "days"}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: TextStyle(
                              fontFamily: LiquidTheme.homeFont,
                              fontFamilyFallback: LiquidTheme.homeFontFallback,
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+250 BONUS XP',
                      style: TextStyle(
                        fontFamily: LiquidTheme.homeFont,
                        fontFamilyFallback: LiquidTheme.homeFontFallback,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                        color: isDark
                            ? const Color(0xFF34D399)
                            : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 7-day interactive hydro tubes visualizer matching the Arcade Telemetry design.
class WeeklyHydroTubes extends StatefulWidget {
  const WeeklyHydroTubes({
    super.key,
    required this.columns,
    required this.reducedMotion,
    required this.isEmpty,
    this.archiveEntries = const [],
  });

  final List<WeeklyDayColumn> columns;
  final List<ArchiveItem> archiveEntries;
  final bool reducedMotion;
  final bool isEmpty;

  @override
  State<WeeklyHydroTubes> createState() => _WeeklyHydroTubesState();
}

class _WeeklyHydroTubesState extends State<WeeklyHydroTubes> {
  DateTime? _selectedDate;
  int _rangeDays = 7;

  List<WeeklyDayColumn> get _visibleColumns {
    if (_rangeDays == 7 || widget.columns.isEmpty) return widget.columns;
    final anchor = widget.columns.last.date;
    final byDate = {
      for (final day in widget.columns) DateUtils.dateOnly(day.date): day,
    };
    final archive = {
      for (final day in widget.archiveEntries)
        DateUtils.dateOnly(day.date): day,
    };
    return List.generate(_rangeDays, (index) {
      final date = DateTime(
        anchor.year,
        anchor.month,
        anchor.day - _rangeDays + 1 + index,
      );
      if (byDate.containsKey(date)) return byDate[date]!;
      final saved = archive[date];
      final amount = saved?.totalMl ?? 0;
      final goal = saved?.goalMl ?? widget.columns.last.goalMl;
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
        totalMl: amount,
        goalMl: goal,
        progress: goal > 0 ? (amount / goal).clamp(0.0, 1.0) : 0,
        isToday: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.liquidColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.columns.isEmpty) {
      return const TelemetryPanel(child: Text('No intake logged this week'));
    }

    final columns = _visibleColumns;
    final selected =
        columns.where((day) => day.date == _selectedDate).firstOrNull ??
        columns.last;
    final selectedStatus =
        selected.goalMl > 0 && selected.totalMl >= selected.goalMl
        ? 'Goal met'
        : selected.isToday
        ? 'In progress'
        : 'Below goal';
    final selectedPercent = selected.goalMl > 0
        ? (selected.totalMl / selected.goalMl * 100).round()
        : 0;
    final todayGoal = widget.columns.last.goalMl;
    final mixedGoals = columns.any((day) => day.goalMl != todayGoal);

    return TelemetryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Hydro Tubes',
                    style: TextStyle(
                      fontFamily: LiquidTheme.homeFont,
                      fontFamilyFallback: LiquidTheme.homeFontFallback,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Continuous volume telemetry (ml)',
                    style: TextStyle(
                      fontFamily: LiquidTheme.homeFont,
                      fontFamilyFallback: LiquidTheme.homeFontFallback,
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<int>(
                key: const Key('hydro_range_filter'),
                tooltip: 'Choose chart date range',
                initialValue: _rangeDays,
                onSelected: (days) => setState(() {
                  _rangeDays = days;
                  _selectedDate = null;
                }),
                itemBuilder: (context) => [
                  for (final days in [7, 14, 30])
                    CheckedPopupMenuItem<int>(
                      value: days,
                      checked: days == _rangeDays,
                      child: Text('Last $days days'),
                    ),
                ],
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Center(
                    widthFactor: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFEDF1FD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune,
                            size: 13,
                            color: isDark
                                ? const Color(0xFF818CF8)
                                : const Color(0xFF2856A3),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'LAST $_rangeDays DAYS',
                            style: TextStyle(
                              fontFamily: LiquidTheme.homeFont,
                              fontFamilyFallback: LiquidTheme.homeFontFallback,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.15,
                              color: isDark
                                  ? const Color(0xFF818CF8)
                                  : const Color(0xFF2856A3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Dashed Goal Line & Goal Badge
          Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                painter: _GoalLine(
                  color: const Color(0xFF00B4D8).withValues(alpha: 0.6),
                ),
                size: const Size(double.infinity, 2),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B4D8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      mixedGoals
                          ? 'Daily targets'
                          : 'GOAL: ${_formatNumber(todayGoal)} ml',
                      style: const TextStyle(
                        fontFamily: LiquidTheme.homeFont,
                        fontFamilyFallback: LiquidTheme.homeFontFallback,
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  Text(
                    'TODAY',
                    style: TextStyle(
                      fontFamily: LiquidTheme.homeFont,
                      fontFamilyFallback: LiquidTheme.homeFontFallback,
                      color: isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF00758F),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Longer ranges scroll while keeping every day individually tappable.
          SizedBox(
            height: 200,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = columns.length > 7
                    ? columns.length * 48.0
                    : constraints.maxWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: SizedBox(
                    width: width,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < columns.length; i++)
                          Expanded(child: _tube(context, columns[i], i)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (columns.every((day) => day.totalMl == 0)) ...[
            const SizedBox(height: 12),
            Text(
              _rangeDays == 7
                  ? 'No intake logged this week'
                  : 'No intake logged in this range',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: LiquidTheme.homeFont,
                fontFamilyFallback: LiquidTheme.homeFontFallback,
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 18),

          // Selected Day Detail Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.7)
                  : const Color(0xFFF3F5FD),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_drink_outlined,
                    color: isDark
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF00758F),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _rangeDays == 7
                            ? '${_dayName(selected.date)} ($selectedStatus)'
                            : '${_dayName(selected.date)}, ${selected.date.month}/${selected.date.day} ($selectedStatus)',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: TextStyle(
                          fontFamily: LiquidTheme.homeFont,
                          fontFamilyFallback: LiquidTheme.homeFontFallback,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${selected.totalMl} ml consumed · $selectedPercent% of target',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: TextStyle(
                          fontFamily: LiquidTheme.homeFont,
                          fontFamilyFallback: LiquidTheme.homeFontFallback,
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected.isToday) ...[
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF075E6C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                    ),
                    child: const Text(
                      'LOG CUP',
                      style: TextStyle(
                        fontFamily: LiquidTheme.homeFont,
                        fontFamilyFallback: LiquidTheme.homeFontFallback,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.15,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap a tube to view that day. Sips sync from your coaster.',
            style: TextStyle(
              fontFamily: LiquidTheme.homeFont,
              fontFamilyFallback: LiquidTheme.homeFontFallback,
              fontSize: 11,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tube(BuildContext context, WeeklyDayColumn day, int index) {
    final colors = context.liquidColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final met = day.goalMl > 0 && day.totalMl >= day.goalMl;
    final selected = day.date == _selectedDate;

    // Tube background
    final tubeTrackColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFEBF0FC);

    return Semantics(
      button: true,
      selected: selected,
      label:
          '${_dayName(day.date)}, ${_rangeDays == 7 ? "" : "${day.date.month}/${day.date.day}, "}${day.totalMl} ml of ${day.goalMl} ml${day.isToday ? ", today" : ""}',
      child: InkWell(
        key: ValueKey('hydro-tube-$index'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _selectedDate = day.date),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    // Floating mint checkmark or star badge on goal met days
                    if (met)
                      Positioned(
                        top: -16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFF52DE97),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF52DE97,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Icon(
                              index % 2 == 1 ? Icons.star : Icons.check,
                              size: 11,
                              color: const Color(0xFF064E3B),
                            ),
                          ),
                        ),
                      ),

                    // Tube container
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: tubeTrackColor,
                        borderRadius: BorderRadius.circular(20),
                        border: selected
                            ? Border.all(
                                color: isDark
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFF00758F),
                                width: 2,
                              )
                            : null,
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: day.progress),
                          duration: widget.reducedMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 900),
                          curve: Curves.easeInOutCubic,
                          builder: (context, progress, _) =>
                              FractionallySizedBox(
                                heightFactor: progress.clamp(0.0, 1.0),
                                widthFactor: 1,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: day.isToday
                                          ? [
                                              const Color(0xFF22D3EE),
                                              const Color(0xFF0891B2),
                                            ]
                                          : met
                                          ? [
                                              const Color(0xFF34D399),
                                              const Color(0xFF059669),
                                            ]
                                          : [
                                              const Color(0xFF38BDF8),
                                              const Color(0xFF0284C7),
                                            ],
                                    ),
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                day.dayLabel.toUpperCase(),
                style: TextStyle(
                  fontFamily: LiquidTheme.homeFont,
                  fontFamilyFallback: LiquidTheme.homeFontFallback,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                  color: met
                      ? const Color(0xFF059669)
                      : day.isToday
                      ? (isDark
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF0284C7))
                      : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Unlocked Badges & Trophies showcase card from the reference design.
class UnlockedBadgesCard extends StatelessWidget {
  const UnlockedBadgesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.liquidColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TelemetryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Unlocked Badges &\nTrophies',
                  style: TextStyle(
                    fontFamily: LiquidTheme.homeFont,
                    fontFamilyFallback: LiquidTheme.homeFontFallback,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Text(
                '3 OF 12\nCLAIMED',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFamily: LiquidTheme.homeFont,
                  fontFamilyFallback: LiquidTheme.homeFontFallback,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.15,
                  color: colors.textSecondary,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _badgeTile(
                  context,
                  title: 'Hydro Master',
                  subtitle: 'GOLD TIER',
                  icon: Icons.emoji_events,
                  iconBg: const Color(0xFF66F2AF),
                  iconColor: const Color(0xFF065F46),
                  subtitleColor: const Color(0xFF059669),
                  cardBg: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF3FBF7),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _badgeTile(
                  context,
                  title: 'Pacing Prodigy',
                  subtitle: '18 ml/s AVG',
                  icon: Icons.bolt,
                  iconBg: const Color(0xFF7CE4F9),
                  iconColor: const Color(0xFF0369A1),
                  subtitleColor: const Color(0xFF0284C7),
                  cardBg: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFEFF8FC),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _badgeTile(
                  context,
                  title: 'Dawn Drinker',
                  subtitle: '5X STREAK',
                  icon: Icons.wb_twilight,
                  iconBg: const Color(0xFFCCD9FE),
                  iconColor: const Color(0xFF3730A3),
                  subtitleColor: const Color(0xFF4338CA),
                  cardBg: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F3FE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badgeTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required Color subtitleColor,
    required Color cardBg,
  }) {
    final colors = context.liquidColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                fontFamily: LiquidTheme.homeFont,
                fontFamilyFallback: LiquidTheme.homeFontFallback,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              subtitle,
              style: TextStyle(
                fontFamily: LiquidTheme.homeFont,
                fontFamilyFallback: LiquidTheme.homeFontFallback,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
                color: subtitleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _dayName(DateTime date) => const [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
][date.weekday - 1];

class _GoalLine extends CustomPainter {
  const _GoalLine({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (double x = 0; x < size.width; x += 10) {
      canvas.drawLine(
        Offset(x, 1),
        Offset((x + 6).clamp(0, size.width), 1),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoalLine oldDelegate) =>
      oldDelegate.color != color;
}
