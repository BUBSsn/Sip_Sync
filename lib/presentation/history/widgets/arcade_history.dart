import 'package:flutter/material.dart';

import '../../theme/liquid_theme.dart';
import '../../widgets/glass_card.dart';
import '../../view_models/history_view_model.dart';

const telemetryTeal = Color(0xFF0277A5);
const telemetryCyan = Color(0xFF31B6D3);
const telemetryMint = Color(0xFF72D5DD);

TextStyle telemetryType({double size = 11, Color? color}) => TextStyle(
  fontSize: size,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
  color: color ?? telemetryTeal,
);

class TelemetryPanel extends StatelessWidget {
  const TelemetryPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      GlassCard(padding: const EdgeInsets.all(20), child: child);
}

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
    final palette = context.liquidColors;
    final lavender = palette.primary.withValues(alpha: 0.06);
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'This week',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              Text(
                'Level $level / 50',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly total',
                      style: telemetryType(color: palette.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: (total / 1000).toStringAsFixed(1),
                            style: telemetryType(
                              size: 34,
                              color: palette.primary,
                            ),
                          ),
                          TextSpan(
                            text: ' L',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily average',
                      style: telemetryType(color: palette.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${history.averageIntakeMl}',
                            style: telemetryType(
                              size: 26,
                              color: palette.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: ' ml/day',
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: lavender,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_outlined,
                      color: Color(0xFF2875DA),
                      size: 23,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${history.currentStreakDays}-day streak',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      history.daysToNextTier == 0
                          ? 'MAX TIER'
                          : '${(progress * 100).round()}% TO\nTIER ${history.currentTier.index + 1}',
                      style: telemetryType(size: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    minHeight: 8,
                    color: palette.primary,
                    backgroundColor: telemetryCyan.withValues(alpha: 0.1),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  history.daysToNextTier == 0
                      ? 'Max Tier 5 Active · Keep your streak flowing'
                      : 'Tier ${history.currentTier.index + 1} unlocks in ${history.daysToNextTier} ${history.daysToNextTier == 1 ? "day" : "days"}',
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Best streak: ${history.bestStreakDays} days',
                  style: telemetryType(size: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WeeklyHydroTubes extends StatefulWidget {
  const WeeklyHydroTubes({
    super.key,
    required this.columns,
    required this.reducedMotion,
    required this.isEmpty,
  });
  final List<WeeklyDayColumn> columns;
  final bool reducedMotion;
  final bool isEmpty;
  @override
  State<WeeklyHydroTubes> createState() => _WeeklyHydroTubesState();
}

class _WeeklyHydroTubesState extends State<WeeklyHydroTubes> {
  DateTime? _selectedDate;
  @override
  Widget build(BuildContext context) {
    final palette = context.liquidColors;
    final lavender = palette.primary.withValues(alpha: 0.06);
    if (widget.columns.isEmpty) {
      return const TelemetryPanel(child: Text('No intake logged this week'));
    }
    final selected =
        widget.columns.where((day) => day.date == _selectedDate).firstOrNull ??
        widget.columns.last;
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
    final mixedGoals = widget.columns.any((day) => day.goalMl != todayGoal);
    return TelemetryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly intake',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Your daily progress in milliliters',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: lavender,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text('Last 7 days', style: telemetryType(size: 10)),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: telemetryCyan,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  mixedGoals ? 'Daily targets' : 'Goal: $todayGoal ml',
                  style: telemetryType(size: 10, color: Colors.white),
                ),
              ),
              Text('Today', style: telemetryType(size: 10)),
            ],
          ),
          CustomPaint(
            painter: _GoalLine(),
            size: const Size(double.infinity, 3),
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < widget.columns.length; i++)
                  Expanded(
                    child: _tube(context, widget.columns[i], i, lavender),
                  ),
              ],
            ),
          ),
          if (widget.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'No intake logged this week',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: lavender,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.water_drop_outlined,
                  color: telemetryTeal,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_dayName(selected.date)} ($selectedStatus)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${selected.totalMl} ml consumed · $selectedPercent% of target',
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap a tube to view that day. Sips sync from your coaster.',
            style: TextStyle(fontSize: 11, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _tube(
    BuildContext context,
    WeeklyDayColumn day,
    int index,
    Color background,
  ) {
    final met = day.goalMl > 0 && day.totalMl >= day.goalMl;
    final selected = day.date == _selectedDate;
    final color = met ? const Color(0xFF008C75) : telemetryTeal;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${_dayName(day.date)}, ${day.totalMl} ml of ${day.goalMl} ml${day.isToday ? ", today" : ""}',
      child: InkWell(
        key: ValueKey('hydro-tube-$index'),
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _selectedDate = day.date),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    if (met)
                      const Positioned(
                        top: -27,
                        left: 0,
                        right: 0,
                        child: Icon(
                          Icons.check_circle,
                          color: Color(0xFF22C796),
                          size: 18,
                        ),
                      ),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(24),
                        border: selected
                            ? Border.all(color: telemetryTeal, width: 2)
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
                                heightFactor: progress.clamp(0, 1),
                                widthFactor: 1,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: day.isToday
                                          ? [
                                              telemetryCyan,
                                              const Color(0xFF0AA5C4),
                                            ]
                                          : [
                                              met
                                                  ? telemetryMint
                                                  : telemetryCyan,
                                              color,
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
              const SizedBox(height: 9),
              Text(
                day.dayLabel,
                style: telemetryType(
                  size: 10,
                  color: day.isToday || met
                      ? telemetryTeal
                      : context.liquidColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
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
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = telemetryCyan.withValues(alpha: 0.6)
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
  bool shouldRepaint(covariant _GoalLine oldDelegate) => false;
}
