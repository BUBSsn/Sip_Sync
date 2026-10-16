import 'package:flutter/material.dart';

import '../../theme/liquid_theme.dart';
import '../../theme/liquid_tokens.dart';
import '../../widgets/glass_card.dart';

/// Reusable GlassCard displaying formatted metrics with count-up animation (Pillar 3).
///
/// Features:
/// - Screen-reader friendly: [Semantics] announces final metric immediately without ticker chatter
/// - Count-up tween on entrance using [AnimationController]
/// - Instant display when reduced motion is requested
/// - Pure water theme typography and frosted surface styling
class StatCard extends StatefulWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.targetValue,
    required this.valueFormatter,
    required this.isReducedMotion,
  });

  final IconData icon;
  final String label;
  final double targetValue;
  final String Function(double val) valueFormatter;
  final bool isReducedMotion;

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countUpController;
  late Animation<double> _animation;
  double _lastTargetValue = 0.0;

  @override
  void initState() {
    super.initState();
    _lastTargetValue = widget.targetValue;

    _countUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _animation =
        Tween<double>(
          begin: widget.isReducedMotion ? widget.targetValue : 0.0,
          end: widget.targetValue,
        ).animate(
          CurvedAnimation(
            parent: _countUpController,
            curve: Curves.easeOutCubic,
          ),
        );

    if (!widget.isReducedMotion) {
      _countUpController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant StatCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isReducedMotion != oldWidget.isReducedMotion) {
      if (widget.isReducedMotion) {
        _countUpController.value = 1.0;
      }
    }

    if ((widget.targetValue - _lastTargetValue).abs() > 0.001) {
      _animation =
          Tween<double>(
            begin: widget.isReducedMotion
                ? widget.targetValue
                : _animation.value,
            end: widget.targetValue,
          ).animate(
            CurvedAnimation(
              parent: _countUpController,
              curve: Curves.easeOutCubic,
            ),
          );
      _lastTargetValue = widget.targetValue;
      if (!widget.isReducedMotion) {
        _countUpController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _countUpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.liquidColors;
    final finalDisplay = widget.valueFormatter(widget.targetValue);
    final accessibleLabel = '${widget.label}: $finalDisplay';

    return Semantics(
      label: accessibleLabel,
      excludeSemantics: true,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(
          horizontal: LiquidTokens.spaceLg,
          vertical: LiquidTokens.spaceLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Metric Category Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: palette.waterShallow.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, size: 20, color: palette.primary),
            ),
            const SizedBox(height: LiquidTokens.spaceSm),

            // 2. Subhead Label
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 4),

            // 3. Large Numeric Value
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                final display = widget.isReducedMotion
                    ? finalDisplay
                    : widget.valueFormatter(_animation.value);

                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    display,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
