import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/domain.dart';
import '../../theme/liquid_theme.dart';
import '../../theme/liquid_tokens.dart';
import '../../widgets/glass_card.dart';
import 'streak_drop_badge_painter.dart';

/// Interactive water-drop badge reflecting active streak momentum and all-time best streak.
///
/// Features:
/// - Isolated canvas in [RepaintBoundary]
/// - 5 milestone tiers with distinct fills, glows, and ambient waves
/// - Smooth animated tier/fill transitions
/// - Prominent Best Streak ribbon and progress to next tier
/// - Full reduced-motion fallback
class StreakDropBadge extends StatefulWidget {
  const StreakDropBadge({
    super.key,
    required this.streakDays,
    required this.bestStreakDays,
    required this.currentTier,
    required this.daysToNextTier,
    required this.isReducedMotion,
    this.badgeSize = 84.0,
  });

  final int streakDays;
  final int bestStreakDays;
  final StreakBadgeTier currentTier;
  final int daysToNextTier;
  final bool isReducedMotion;
  final double badgeSize;

  @override
  State<StreakDropBadge> createState() => _StreakDropBadgeState();
}

class _StreakDropBadgeState extends State<StreakDropBadge>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController;
  late final AnimationController _fillController;
  late Animation<double> _fillAnimation;

  double _lastTargetFill = 0.0;

  double _tierToFillRatio(StreakBadgeTier tier) {
    return switch (tier) {
      StreakBadgeTier.none => 0.0,
      StreakBadgeTier.tier1 => 0.28,
      StreakBadgeTier.tier2 => 0.52,
      StreakBadgeTier.tier3 => 0.74,
      StreakBadgeTier.tier4 => 0.90,
      StreakBadgeTier.tier5 => 1.00,
    };
  }

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    if (!widget.isReducedMotion && widget.currentTier != StreakBadgeTier.none) {
      _ambientController.repeat(reverse: true);
    }

    _lastTargetFill = _tierToFillRatio(widget.currentTier);
    _fillController = AnimationController(
      vsync: this,
      duration: LiquidTokens.durationNormal,
    );
    _fillAnimation = Tween<double>(begin: _lastTargetFill, end: _lastTargetFill)
        .animate(
          CurvedAnimation(parent: _fillController, curve: Curves.easeOutCubic),
        );
  }

  @override
  void didUpdateWidget(covariant StreakDropBadge oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isReducedMotion != oldWidget.isReducedMotion ||
        widget.currentTier != oldWidget.currentTier) {
      if (widget.isReducedMotion ||
          widget.currentTier == StreakBadgeTier.none) {
        _ambientController.stop();
      } else if (!_ambientController.isAnimating) {
        _ambientController.repeat(reverse: true);
      }
    }

    final newTarget = _tierToFillRatio(widget.currentTier);
    if ((newTarget - _lastTargetFill).abs() > 0.001) {
      _fillAnimation =
          Tween<double>(begin: _fillAnimation.value, end: newTarget).animate(
            CurvedAnimation(
              parent: _fillController,
              curve: Curves.easeOutCubic,
            ),
          );
      _lastTargetFill = newTarget;
      _fillController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _fillController.dispose();
    super.dispose();
  }

  String _formatTierProgress() {
    if (widget.streakDays == 0) {
      return 'No active streak • Drink today to begin!';
    }
    if (widget.currentTier == StreakBadgeTier.tier5) {
      return 'Current: ${widget.streakDays}d • Max Tier 5 Active 👑';
    }
    final nextTierNumber = widget.currentTier.index + 1;
    final dayLabel = widget.daysToNextTier == 1 ? 'day' : 'days';
    return 'Current: ${widget.streakDays}d • ${widget.daysToNextTier} $dayLabel to Tier $nextTierNumber';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.liquidColors;

    final semanticsLabel = widget.streakDays == 0
        ? 'Best streak: ${widget.bestStreakDays} days. No active streak today.'
        : 'Best streak: ${widget.bestStreakDays} days. Current streak: ${widget.streakDays} days, tier ${widget.currentTier.name}. ${_formatTierProgress()}.';

    return Semantics(
      label: semanticsLabel,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(
          horizontal: LiquidTokens.spaceLg,
          vertical: LiquidTokens.spaceLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Water Drop Badge Silhouette
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _ambientController,
                  _fillController,
                ]),
                builder: (context, _) {
                  final glow = widget.isReducedMotion
                      ? 0.5
                      : (0.4 + 0.6 * sin(_ambientController.value * pi));
                  final wavePhase = widget.isReducedMotion
                      ? 0.0
                      : _ambientController.value;

                  return CustomPaint(
                    size: Size(widget.badgeSize, widget.badgeSize * 1.15),
                    painter: StreakDropBadgePainter(
                      fillRatio: _fillAnimation.value,
                      glowIntensity: glow,
                      wavePhase: wavePhase,
                      tier: widget.currentTier,
                      palette: palette,
                      isReducedMotion: widget.isReducedMotion,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: LiquidTokens.spaceMd),

            // 2. Subhead: "Best Streak"
            Text(
              'Best Streak',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),

            // 3. Primary Value: "5 Days"
            Text(
              '${widget.bestStreakDays} Days',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: LiquidTokens.spaceSm),

            // 4. Current Streak & Tier Progression Ribbon
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: LiquidTokens.spaceMd,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(LiquidTokens.radiusPill),
                border: Border.all(
                  color: palette.primary.withValues(alpha: 0.18),
                  width: 0.8,
                ),
              ),
              child: Text(
                _formatTierProgress(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.streakDays > 0
                      ? palette.primary
                      : palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
