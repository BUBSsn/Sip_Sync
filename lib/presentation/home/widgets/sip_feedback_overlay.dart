import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/liquid_theme.dart';
import '../../theme/liquid_tokens.dart';
import '../../theme/reduced_motion.dart';
import '../../view_models/sip_feedback_view_model.dart';

/// Interactive celebration overlay rendering floating "+X ml" badge
/// and capped particle droplet bursts on sip events (Pillar 2).
class SipFeedbackOverlay extends ConsumerStatefulWidget {
  const SipFeedbackOverlay({
    super.key,
    this.width = 280.0,
    this.height = 360.0,
  });

  final double width;
  final double height;

  @override
  ConsumerState<SipFeedbackOverlay> createState() => _SipFeedbackOverlayState();
}

class _SipFeedbackOverlayState extends ConsumerState<SipFeedbackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final List<_DropletParticle> _particles;
  final _random = Random();

  int? _displayedVolume;
  DateTime? _lastTimestamp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: LiquidTokens.durationSipFeedback,
    );
    _particles = List.generate(
      8,
      (i) => _DropletParticle(index: i, random: _random),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _triggerFeedback(int volumeMl, DateTime? timestamp) {
    _displayedVolume = volumeMl;
    _lastTimestamp = timestamp;

    if (context.mounted) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Logged $volumeMl milliliters water sip',
        TextDirection.ltr,
      );
    }

    for (final p in _particles) {
      p.reset(_random, widget.width / 2, widget.height * 0.45);
    }

    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.liquidColors;
    final feedback = ref.watch(sipFeedbackViewModelProvider);
    final isReducedMotion = shouldReduceMotion(context, ref);

    // Detect new feedback trigger or merged sip update
    if (feedback.hasActiveFeedback &&
        feedback.mergedVolumeMl > 0 &&
        feedback.timestamp != _lastTimestamp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _triggerFeedback(feedback.mergedVolumeMl, feedback.timestamp);
        }
      });
    }

    return IgnorePointer(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            if (!_animController.isAnimating || _displayedVolume == null) {
              return const SizedBox.shrink();
            }

            final t = _animController.value;

            // 1. Reduced motion: simple fade-in and upward drift
            if (isReducedMotion) {
              final opacity = (1.0 - t).clamp(0.0, 1.0);
              return Center(
                child: Transform.translate(
                  offset: Offset(0, -30 * t),
                  child: Opacity(
                    opacity: opacity,
                    child: _FloatingMlBadge(
                      volumeMl: _displayedVolume!,
                      palette: palette,
                    ),
                  ),
                ),
              );
            }

            // 2. Full animation: particle droplet burst + floating badge with pulse
            final badgeOpacity = t < 0.2
                ? (t / 0.2)
                : ((1.0 - t) / 0.8).clamp(0.0, 1.0);
            final badgeY = -50 * sin(t * pi * 0.5);
            final badgeScale = 0.8 + 0.35 * sin(t * pi);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Droplet particles
                RepaintBoundary(
                  child: CustomPaint(
                    size: Size(widget.width, widget.height),
                    painter: _DropletBurstPainter(
                      particles: _particles,
                      progress: t,
                      color: palette.aquaHighlight,
                    ),
                  ),
                ),

                // Floating "+X ml" Badge
                Align(
                  alignment: const Alignment(0, -0.2),
                  child: Transform.translate(
                    offset: Offset(0, badgeY),
                    child: Transform.scale(
                      scale: badgeScale,
                      child: Opacity(
                        opacity: badgeOpacity.clamp(0.0, 1.0),
                        child: _FloatingMlBadge(
                          volumeMl: _displayedVolume!,
                          palette: palette,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FloatingMlBadge extends StatelessWidget {
  const _FloatingMlBadge({required this.volumeMl, required this.palette});

  final int volumeMl;
  final LiquidColorPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LiquidTokens.spaceMd,
        vertical: LiquidTokens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: palette.aquaHighlight,
        borderRadius: BorderRadius.circular(LiquidTokens.radiusPill),
        boxShadow: [
          BoxShadow(
            color: palette.aquaHighlight.withValues(alpha: 0.5),
            blurRadius: 16.0,
            spreadRadius: 1.0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.water_drop, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '+$volumeMl ml',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DropletParticle {
  _DropletParticle({required this.index, required Random random}) {
    reset(random, 0, 0);
  }

  final int index;
  double startX = 0;
  double startY = 0;
  double vx = 0;
  double vy = 0;
  double size = 4;

  void reset(Random random, double x, double y) {
    startX = x;
    startY = y;
    final angle = -pi / 2 + (random.nextDouble() - 0.5) * 1.4;
    final speed = 70.0 + random.nextDouble() * 100.0;
    vx = cos(angle) * speed;
    vy = sin(angle) * speed;
    size = 3.0 + random.nextDouble() * 3.5;
  }
}

class _DropletBurstPainter extends CustomPainter {
  _DropletBurstPainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  final List<_DropletParticle> particles;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: (1.0 - progress).clamp(0.0, 1.0) * 0.85)
      ..style = PaintingStyle.fill;

    const gravity = 220.0;

    for (final p in particles) {
      final x = p.startX + p.vx * progress;
      final y =
          p.startY + p.vy * progress + 0.5 * gravity * progress * progress;
      final radius = p.size * (1.0 - progress * 0.4);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DropletBurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
