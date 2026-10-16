import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/domain.dart';
import '../../theme/liquid_theme.dart';
import '../../theme/liquid_tokens.dart';
import '../../view_models/history_view_model.dart';
import '../../widgets/glass_card.dart';

/// Archive row tile displaying daily intake with a gamified milestone seal (Pillar 3).
///
/// Features:
/// - Three milestone tiers:
///   - [SealTier.goalMet] (>= 100%): Glowing water seal with ripple ring and "Goal Met!" status.
///   - [SealTier.almostThere] (80-99%): Partial completion ring proportional to progress and "Almost there!" status.
///   - [SealTier.underGoal] (< 80%): Muted grey/slate droplet icon, neutral phrasing, non-shaming.
/// - Never color alone: paired with icons, progress rings, and typography.
/// - Division-by-zero protection (falls back safely to 2000ml default).
/// - Consolidated ambient phase input to prevent ticker multiplication in scrolling lists.
/// - Full accessibility semantics.
class MilestoneSealTile extends StatelessWidget {
  const MilestoneSealTile({
    super.key,
    required this.item,
    this.ambientPhase = 0.0,
    required this.isReducedMotion,
  });

  final ArchiveItem item;
  final double ambientPhase;
  final bool isReducedMotion;

  @override
  Widget build(BuildContext context) {
    final palette = context.liquidColors;
    final safeGoal = item.goalMl > 0
        ? item.goalMl
        : UserSettings.defaultDailyGoalMl;
    final progress = (item.totalMl / safeGoal).clamp(0.0, 2.0);

    final semanticsStatus = switch (item.sealTier) {
      SealTier.goalMet => 'Goal Met',
      SealTier.almostThere => 'Almost there',
      SealTier.underGoal => 'Below Goal',
    };
    final semanticsLabel =
        '${item.dayName}, ${item.totalMl} milliliters, $semanticsStatus';

    return Semantics(
      label: semanticsLabel,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(
          horizontal: LiquidTokens.spaceMd,
          vertical: LiquidTokens.spaceSm + 2,
        ),
        borderRadius: BorderRadius.circular(LiquidTokens.radiusCard),
        child: Row(
          children: [
            // 1. Milestone Seal Badge
            _MilestoneSealBadge(
              tier: item.sealTier,
              progress: progress,
              ambientPhase: ambientPhase,
              isReducedMotion: isReducedMotion,
              palette: palette,
            ),
            const SizedBox(width: LiquidTokens.spaceMd),

            // 2. Day Name & Status Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.dayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (item.sealTier != SealTier.underGoal) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item.sealTier == SealTier.goalMet
                            ? palette.primary
                            : palette.aquaHighlight,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 3. Daily Intake Total (e.g. "2100ml")
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${item.totalMl}ml',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: item.sealTier == SealTier.goalMet
                      ? palette.primary
                      : palette.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneSealBadge extends StatelessWidget {
  const _MilestoneSealBadge({
    required this.tier,
    required this.progress,
    required this.ambientPhase,
    required this.isReducedMotion,
    required this.palette,
  });

  final SealTier tier;
  final double progress;
  final double ambientPhase;
  final bool isReducedMotion;
  final LiquidColorPalette palette;

  @override
  Widget build(BuildContext context) {
    const size = 44.0;

    switch (tier) {
      case SealTier.goalMet:
        final rippleScale = isReducedMotion
            ? 1.0
            : 1.0 + 0.12 * sin(ambientPhase * 2 * pi);
        final rippleOpacity = isReducedMotion
            ? 0.3
            : 0.2 + 0.15 * cos(ambientPhase * 2 * pi);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Ambient Breathing Ripple Ring
            Transform.scale(
              scale: rippleScale,
              child: Container(
                width: size + 4,
                height: size + 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: palette.primary.withValues(alpha: rippleOpacity),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            // Glowing Water Seal
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.primary.withValues(alpha: 0.45),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.check_circle, color: palette.primary, size: 22),
            ),
          ],
        );

      case SealTier.almostThere:
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Partial Completion Circular Ring
              CustomPaint(
                size: const Size(size, size),
                painter: _PartialRingPainter(
                  progress: progress.clamp(0.0, 1.0),
                  ringColor: palette.aquaHighlight,
                  trackColor: palette.surface.withValues(alpha: 0.4),
                ),
              ),
              Icon(Icons.water_drop, color: palette.aquaHighlight, size: 18),
            ],
          ),
        );

      case SealTier.underGoal:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(
              color: palette.textSecondary.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.water_drop_outlined,
            color: palette.textSecondary.withValues(alpha: 0.5),
            size: 18,
          ),
        );
    }
  }
}

class _PartialRingPainter extends CustomPainter {
  const _PartialRingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
  });

  final double progress;
  final Color ringColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 4.0) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc
    final arcPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.8;

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PartialRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.trackColor != trackColor;
  }
}
