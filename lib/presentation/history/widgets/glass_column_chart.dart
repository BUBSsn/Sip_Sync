import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/liquid_theme.dart';
import '../../theme/liquid_tokens.dart';
import '../../view_models/history_view_model.dart';
import '../../widgets/glass_card.dart';

/// Fillable glass column chart representing weekly intake (Tue–Mon trailing 7 days).
///
/// Implements:
/// - Pure water optics (depth gradients, surface meniscus, empty glass silhouette)
/// - Dashed horizontal goal reference line
/// - Current day highlighted accent rim
/// - Capped columns above 100% with glowing aqua Goal-Met marker pip
/// - Staggered entrance cascade animation
/// - Tap-for-ml tooltip overlay displaying un-clamped percentage
/// - Loading (skeleton), Empty, and Data states
/// - RepaintBoundary isolation and reduced-motion fallback
class GlassColumnChart extends StatefulWidget {
  const GlassColumnChart({
    super.key,
    required this.columns,
    this.isLoading = false,
    this.isEmpty = false,
    required this.isReducedMotion,
    this.chartHeight = 180.0,
  });

  final List<WeeklyDayColumn> columns;
  final bool isLoading;
  final bool isEmpty;
  final bool isReducedMotion;
  final double chartHeight;

  @override
  State<GlassColumnChart> createState() => _GlassColumnChartState();
}

class _GlassColumnChartState extends State<GlassColumnChart>
    with TickerProviderStateMixin {
  late final AnimationController _cascadeController;
  late final AnimationController _waveController;

  int? _selectedColumnIndex;

  @override
  void initState() {
    super.initState();
    _cascadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    if (widget.isReducedMotion) {
      _cascadeController.value = 1.0;
    } else {
      _cascadeController.forward();
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant GlassColumnChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReducedMotion != oldWidget.isReducedMotion) {
      if (widget.isReducedMotion) {
        _cascadeController.value = 1.0;
        _waveController.stop();
      } else {
        _waveController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _cascadeController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _onColumnTapped(int index) {
    setState(() {
      _selectedColumnIndex = _selectedColumnIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.liquidColors;

    return GlassCard(
      padding: const EdgeInsets.all(LiquidTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Chart Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Intake',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              if (_selectedColumnIndex != null &&
                  _selectedColumnIndex! < widget.columns.length) ...[
                _buildTooltipBadge(
                  widget.columns[_selectedColumnIndex!],
                  palette,
                ),
              ],
            ],
          ),
          const SizedBox(height: LiquidTokens.spaceMd),

          // 2. Chart Area / States
          if (widget.isLoading)
            _buildLoadingSkeleton(palette)
          else if (widget.isEmpty || widget.columns.isEmpty)
            _buildEmptyState(palette)
          else
            _buildChartArea(palette),
        ],
      ),
    );
  }

  Widget _buildTooltipBadge(WeeklyDayColumn col, LiquidColorPalette palette) {
    final percent = col.goalMl > 0
        ? ((col.totalMl / col.goalMl) * 100).round()
        : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.aquaHighlight.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(LiquidTokens.radiusSm),
        border: Border.all(
          color: palette.aquaHighlight.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Text(
        '${col.dayLabel}: ${col.totalMl} ml ($percent%)',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: palette.primary,
        ),
      ),
    );
  }

  Widget _buildEmptyState(LiquidColorPalette palette) {
    return Column(
      children: [
        SizedBox(
          height: widget.chartHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              return _EmptyColumnSilhouette(
                height: widget.chartHeight * 0.75,
                palette: palette,
              );
            }),
          ),
        ),
        const SizedBox(height: LiquidTokens.spaceSm),
        Text(
          'No intake logged this week',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Place your cup on the coaster to start tracking.',
          style: TextStyle(
            fontSize: 12,
            color: palette.textSecondary.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton(LiquidColorPalette palette) {
    return SizedBox(
      height: widget.chartHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (i) {
          return Container(
            width: 28,
            height: widget.chartHeight * 0.7,
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(LiquidTokens.radiusSm),
              border: Border.all(
                color: palette.glassBorder.withValues(alpha: 0.3),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildChartArea(LiquidColorPalette palette) {
    final columnAreaHeight = widget.chartHeight * 0.75;

    return RepaintBoundary(
      child: Column(
        children: [
          // Glass Columns with dashed goal line
          SizedBox(
            height: columnAreaHeight,
            child: Stack(
              children: [
                // Dashed Goal Line at top (100% capacity level)
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: CustomPaint(
                    size: const Size(double.infinity, 1),
                    painter: _DashedLinePainter(
                      color: palette.textSecondary.withValues(alpha: 0.25),
                    ),
                  ),
                ),

                // 7 Fillable Columns
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(widget.columns.length, (index) {
                    final col = widget.columns[index];
                    final isSelected = _selectedColumnIndex == index;

                    // Staggered cascade progress (delayed per column index)
                    final startFraction = (index * 0.08).clamp(0.0, 0.6);
                    final endFraction = (startFraction + 0.4).clamp(0.0, 1.0);
                    final cascadeProgress = widget.isReducedMotion
                        ? 1.0
                        : ((_cascadeController.value - startFraction) /
                                  (endFraction - startFraction))
                              .clamp(0.0, 1.0);

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onColumnTapped(index),
                      child: _ColumnItem(
                        column: col,
                        cascadeProgress: cascadeProgress,
                        wavePhase: widget.isReducedMotion
                            ? 0.0
                            : _waveController.value,
                        maxHeight: columnAreaHeight,
                        isSelected: isSelected,
                        isReducedMotion: widget.isReducedMotion,
                        palette: palette,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: LiquidTokens.spaceSm),

          // Day of Week Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(widget.columns.length, (index) {
              final col = widget.columns[index];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onColumnTapped(index),
                child: SizedBox(
                  width: 32,
                  child: Text(
                    col.dayLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: col.isToday
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: col.isToday
                          ? palette.primary
                          : palette.textSecondary,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ColumnItem extends StatelessWidget {
  const _ColumnItem({
    required this.column,
    required this.cascadeProgress,
    required this.wavePhase,
    required this.maxHeight,
    required this.isSelected,
    required this.isReducedMotion,
    required this.palette,
  });

  final WeeklyDayColumn column;
  final double cascadeProgress;
  final double wavePhase;
  final double maxHeight;
  final bool isSelected;
  final bool isReducedMotion;
  final LiquidColorPalette palette;

  @override
  Widget build(BuildContext context) {
    const columnWidth = 28.0;
    final isGoalMet = column.goalMl > 0 && column.totalMl >= column.goalMl;

    final semanticsPercent = column.goalMl > 0
        ? ((column.totalMl / column.goalMl) * 100).round()
        : 0;
    final semantics =
        '${column.dayLabel}, ${column.totalMl} milliliters, $semanticsPercent percent of goal${isGoalMet ? ', goal met' : ''}';

    return Semantics(
      label: semantics,
      button: true,
      child: Container(
        width: columnWidth,
        height: maxHeight,
        alignment: Alignment.bottomCenter,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Glass Cylinder Column Canvas
            CustomPaint(
              size: Size(columnWidth, maxHeight),
              painter: _GlassColumnPainter(
                progress: column.progress * cascadeProgress,
                wavePhase: wavePhase,
                isToday: column.isToday,
                isSelected: isSelected,
                isGoalMet: isGoalMet,
                isReducedMotion: isReducedMotion,
                palette: palette,
              ),
            ),

            // Goal-Met Glowing Aqua Pip at Top Rim (if >= 100%)
            if (isGoalMet && cascadeProgress >= 0.8)
              Positioned(
                top: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: palette.aquaHighlight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: palette.aquaHighlight.withValues(alpha: 0.8),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlassColumnPainter extends CustomPainter {
  const _GlassColumnPainter({
    required this.progress,
    required this.wavePhase,
    required this.isToday,
    required this.isSelected,
    required this.isGoalMet,
    required this.isReducedMotion,
    required this.palette,
  });

  final double progress;
  final double wavePhase;
  final bool isToday;
  final bool isSelected;
  final bool isGoalMet;
  final bool isReducedMotion;
  final LiquidColorPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(LiquidTokens.radiusSm),
    );

    // 1. Column Hollow Interior
    final bgPaint = Paint()
      ..color = palette.surface.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(r, bgPaint);

    // 2. Liquid Fill (Clipped to Column Cylinder)
    if (progress > 0.001) {
      canvas.save();
      canvas.clipRRect(r);

      final fillHeight = (size.height * progress.clamp(0.0, 1.0));
      final waterLevelY = size.height - fillHeight;

      final wavePath = Path();
      wavePath.moveTo(0, size.height);
      wavePath.lineTo(0, waterLevelY);

      if (isReducedMotion || progress >= 0.99) {
        wavePath.lineTo(size.width, waterLevelY);
      } else {
        const amplitude = 1.4;
        wavePath.quadraticBezierTo(
          size.width * 0.5,
          waterLevelY + sin(wavePhase * 2 * pi) * amplitude,
          size.width,
          waterLevelY,
        );
      }

      wavePath.lineTo(size.width, size.height);
      wavePath.close();

      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.waterShallow, palette.waterMid, palette.waterDeep],
        stops: const [0.0, 0.45, 1.0],
      );

      final fillPaint = Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(0, waterLevelY, size.width, fillHeight),
        )
        ..style = PaintingStyle.fill;

      canvas.drawPath(wavePath, fillPaint);

      // Meniscus Highlight Line
      final meniscusPaint = Paint()
        ..color = palette.aquaHighlight.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(0, waterLevelY),
        Offset(size.width, waterLevelY),
        meniscusPaint,
      );

      canvas.restore();
    } else {
      // Empty Column Base Meniscus
      final baseMeniscusPaint = Paint()
        ..color = palette.waterShallow.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(3, size.height - 3),
        Offset(size.width - 3, size.height - 3),
        baseMeniscusPaint,
      );
    }

    // 3. Outer Glass Column Border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isToday || isSelected ? 1.8 : 0.8;

    if (isSelected) {
      borderPaint.color = palette.aquaHighlight;
    } else if (isToday) {
      borderPaint.color = palette.primary;
    } else {
      borderPaint.color = palette.glassBorder.withValues(alpha: 0.4);
    }
    canvas.drawRRect(r, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _GlassColumnPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.isToday != isToday ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.isGoalMet != isGoalMet ||
        oldDelegate.isReducedMotion != isReducedMotion;
  }
}

class _EmptyColumnSilhouette extends StatelessWidget {
  const _EmptyColumnSilhouette({required this.height, required this.palette});

  final double height;
  final LiquidColorPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: height,
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(LiquidTokens.radiusSm),
        border: Border.all(color: palette.glassBorder.withValues(alpha: 0.3)),
      ),
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: palette.waterShallow.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
