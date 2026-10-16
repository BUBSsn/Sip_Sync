import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/liquid_theme.dart';
import '../../theme/liquid_tokens.dart';
import '../../theme/reduced_motion.dart';

/// Tactile liquid switch for toggling adaptive reminders.
///
/// Features:
/// - Liquid track fill animation.
/// - Droplet morphing thumb that stretches dynamically during motion.
/// - White checkmark indicator when active (matching reference).
/// - Haptic feedback on toggle.
/// - Full accessibility semantics and 48dp minimum touch target.
class LiquidSwitch extends ConsumerStatefulWidget {
  const LiquidSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Adaptive Reminders',
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  ConsumerState<LiquidSwitch> createState() => _LiquidSwitchState();
}

class _LiquidSwitchState extends ConsumerState<LiquidSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _thumbPosition;
  late Animation<double> _stretch;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: LiquidTokens.durationShort,
      value: widget.value ? 1.0 : 0.0,
    );

    _thumbPosition = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    // Dynamic morphing curve: stretches in the middle of transition
    _stretch = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 0.35,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.35,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInBack)),
        weight: 50.0,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(LiquidSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onChanged == null) return;
    HapticFeedback.lightImpact();
    widget.onChanged!(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.liquidColors;
    final reduceMotion = shouldReduceMotion(context, ref);

    const trackWidth = 52.0;
    const trackHeight = 30.0;
    const thumbRadius = 11.5;
    const padding = 3.5;

    return Semantics(
      toggled: widget.value,
      enabled: widget.onChanged != null,
      label: widget.label,
      onTap: widget.onChanged != null ? _handleTap : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onChanged != null ? _handleTap : null,
        child: Container(
          // Ensure 48dp minimum touch target
          constraints: const BoxConstraints(minWidth: 48.0, minHeight: 48.0),
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = _thumbPosition.value;
              final stretchAmount = reduceMotion ? 0.0 : _stretch.value;

              final trackBg = Color.lerp(
                palette.waterShallow.withValues(alpha: 0.3),
                palette.primary,
                progress,
              )!;

              final trackBorder = Color.lerp(
                palette.glassBorder,
                palette.primary.withValues(alpha: 0.5),
                progress,
              )!;

              final availableTravel =
                  trackWidth - 2 * padding - 2 * thumbRadius;
              final thumbCenterX =
                  padding + thumbRadius + progress * availableTravel;

              return Container(
                width: trackWidth,
                height: trackHeight,
                decoration: BoxDecoration(
                  color: trackBg,
                  borderRadius: BorderRadius.circular(LiquidTokens.radiusPill),
                  border: Border.all(color: trackBorder, width: 1.2),
                  boxShadow: widget.value
                      ? [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: 0.25),
                            blurRadius: 8.0,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(trackWidth, trackHeight),
                    painter: _LiquidSwitchThumbPainter(
                      thumbCenterX: thumbCenterX,
                      centerY: trackHeight / 2,
                      thumbRadius: thumbRadius,
                      stretchAmount: stretchAmount,
                      progress: progress,
                      palette: palette,
                      reduceMotion: reduceMotion,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LiquidSwitchThumbPainter extends CustomPainter {
  const _LiquidSwitchThumbPainter({
    required this.thumbCenterX,
    required this.centerY,
    required this.thumbRadius,
    required this.stretchAmount,
    required this.progress,
    required this.palette,
    required this.reduceMotion,
  });

  final double thumbCenterX;
  final double centerY;
  final double thumbRadius;
  final double stretchAmount;
  final double progress;
  final LiquidColorPalette palette;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(thumbCenterX, centerY);

    if (!reduceMotion && stretchAmount > 0) {
      final scaleX = 1.0 + stretchAmount * 0.45;
      final scaleY = 1.0 - stretchAmount * 0.2;
      canvas.scale(scaleX, scaleY);
    }

    // Thumb shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawCircle(const Offset(0, 1.5), thumbRadius, shadowPaint);

    // Thumb droplet body (pure white with subtle glass sheen)
    final thumbPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, thumbRadius, thumbPaint);

    // Subtle specular highlight on droplet
    final glossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(-thumbRadius * 0.3, -thumbRadius * 0.3),
      thumbRadius * 0.25,
      glossPaint,
    );

    // Checkmark icon rendered on thumb when ON (as in reference image)
    if (progress > 0.3) {
      final checkAlpha = ((progress - 0.3) / 0.7).clamp(0.0, 1.0);
      final checkPaint = Paint()
        ..color = palette.primary.withValues(alpha: checkAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path()
        ..moveTo(-thumbRadius * 0.4, 0.0)
        ..lineTo(-thumbRadius * 0.1, thumbRadius * 0.32)
        ..lineTo(thumbRadius * 0.4, -thumbRadius * 0.25);
      canvas.drawPath(path, checkPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LiquidSwitchThumbPainter oldDelegate) {
    return oldDelegate.thumbCenterX != thumbCenterX ||
        oldDelegate.stretchAmount != stretchAmount ||
        oldDelegate.progress != progress ||
        oldDelegate.palette != palette ||
        oldDelegate.reduceMotion != reduceMotion;
  }
}
