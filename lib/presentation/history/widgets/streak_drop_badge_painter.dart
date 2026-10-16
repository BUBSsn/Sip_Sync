import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/domain.dart';
import '../../theme/liquid_tokens.dart';

/// CustomPainter rendering an evolving, glowing water-drop milestone badge.
///
/// Implements 5 progression tiers:
/// - [StreakBadgeTier.none]: Muted empty drop outline, no active glow.
/// - [StreakBadgeTier.tier1]: ~25% fill, calm surface, subtle aura.
/// - [StreakBadgeTier.tier2]: ~50% fill, gentle ambient glow.
/// - [StreakBadgeTier.tier3]: ~75% fill, luminous deep-water aura.
/// - [StreakBadgeTier.tier4]: ~90% fill, energetic high-charge glow.
/// - [StreakBadgeTier.tier5]: 100% full, celestial over-charge aqua corona ring.
class StreakDropBadgePainter extends CustomPainter {
  const StreakDropBadgePainter({
    required this.fillRatio,
    required this.glowIntensity,
    required this.wavePhase,
    required this.tier,
    required this.palette,
    required this.isReducedMotion,
  });

  final double fillRatio;
  final double glowIntensity;
  final double wavePhase;
  final StreakBadgeTier tier;
  final LiquidColorPalette palette;
  final bool isReducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final dropPath = _createDropletPath(w, h);

    // 1. Ambient Glow Aura (if active streak and not reduced motion)
    if (tier != StreakBadgeTier.none) {
      _paintAura(canvas, dropPath, w, h);
    }

    // 2. Base Glass Droplet Body
    final bgPaint = Paint()
      ..color = palette.surface.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawPath(dropPath, bgPaint);

    // 3. Liquid Interior Fill (clipped to droplet silhouette)
    if (fillRatio > 0.001) {
      canvas.save();
      canvas.clipPath(dropPath);

      _paintLiquidFill(canvas, w, h);

      canvas.restore();
    }

    // 4. Glass Droplet Outer Border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = tier == StreakBadgeTier.tier5 ? 2.5 : 1.8;

    if (tier == StreakBadgeTier.none) {
      borderPaint.color = palette.textSecondary.withValues(alpha: 0.25);
    } else if (tier == StreakBadgeTier.tier5) {
      borderPaint.color = palette.aquaHighlight;
    } else {
      borderPaint.color = palette.primary.withValues(alpha: 0.6);
    }
    canvas.drawPath(dropPath, borderPaint);

    // 5. Specular Sheen Highlight (top-left glass refraction)
    _paintSpecularHighlight(canvas, w, h);
  }

  Path _createDropletPath(double w, double h) {
    final path = Path();
    final top = Offset(w * 0.5, h * 0.08);
    final bottom = Offset(w * 0.5, h * 0.92);
    final bulbRadius = w * 0.38;

    path.moveTo(top.dx, top.dy);
    // Right side curve down to bottom bulb
    path.cubicTo(
      top.dx + bulbRadius * 0.95,
      top.dy + h * 0.44,
      bottom.dx + bulbRadius,
      bottom.dy - h * 0.14,
      bottom.dx,
      bottom.dy,
    );
    // Left side curve back to top tip
    path.cubicTo(
      bottom.dx - bulbRadius,
      bottom.dy - h * 0.14,
      top.dx - bulbRadius * 0.95,
      top.dy + h * 0.44,
      top.dx,
      top.dy,
    );
    path.close();
    return path;
  }

  void _paintAura(Canvas canvas, Path dropPath, double w, double h) {
    final blurSigma = switch (tier) {
      StreakBadgeTier.tier1 => 4.0,
      StreakBadgeTier.tier2 => 7.0,
      StreakBadgeTier.tier3 => 11.0,
      StreakBadgeTier.tier4 => 15.0,
      StreakBadgeTier.tier5 => 20.0,
      StreakBadgeTier.none => 0.0,
    };

    final effectiveBlur = isReducedMotion
        ? blurSigma * 0.6
        : blurSigma * (0.85 + 0.25 * glowIntensity);
    final alpha = switch (tier) {
      StreakBadgeTier.tier1 => 0.25,
      StreakBadgeTier.tier2 => 0.35,
      StreakBadgeTier.tier3 => 0.50,
      StreakBadgeTier.tier4 => 0.65,
      StreakBadgeTier.tier5 => 0.85,
      StreakBadgeTier.none => 0.0,
    };

    final glowColor = tier == StreakBadgeTier.tier5
        ? palette.aquaHighlight
        : (tier == StreakBadgeTier.tier4
              ? palette.aquaHighlight
              : palette.primary);

    final auraPaint = Paint()
      ..color = glowColor.withValues(
        alpha: alpha * (isReducedMotion ? 0.7 : glowIntensity),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = tier == StreakBadgeTier.tier5 ? 6.0 : 4.0
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, effectiveBlur);

    canvas.drawPath(dropPath, auraPaint);

    // Tier 5 celestial corona outer ring
    if (tier == StreakBadgeTier.tier5 && !isReducedMotion) {
      final coronaPaint = Paint()
        ..color = palette.aquaHighlight.withValues(alpha: 0.3 * glowIntensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16.0);
      canvas.drawPath(dropPath, coronaPaint);
    }
  }

  void _paintLiquidFill(Canvas canvas, double w, double h) {
    final topY = h * 0.08;
    final bottomY = h * 0.92;
    final totalHeight = bottomY - topY;
    final waterLevelY = bottomY - (totalHeight * fillRatio.clamp(0.0, 1.0));

    final wavePath = Path();
    wavePath.moveTo(0, h);
    wavePath.lineTo(0, waterLevelY);

    if (isReducedMotion || fillRatio >= 0.98) {
      // Flat calm water line
      wavePath.lineTo(w, waterLevelY);
    } else {
      // Subtle undulating surface wave
      const waveAmplitude = 2.2;
      final step = w / 30.0;
      for (double x = 0; x <= w; x += step) {
        final y =
            waterLevelY +
            sin((x / w * 2 * pi) + (wavePhase * 2 * pi)) * waveAmplitude;
        wavePath.lineTo(x, y);
      }
    }

    wavePath.lineTo(w, h);
    wavePath.close();

    // Depth Gradient (shallow aqua near surface to deep blue at bottom)
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [palette.waterShallow, palette.waterMid, palette.waterDeep],
      stops: const [0.0, 0.45, 1.0],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, waterLevelY, w, h - waterLevelY),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(wavePath, fillPaint);

    // Surface meniscus highlight line
    final meniscusPaint = Paint()
      ..color = palette.aquaHighlight.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final meniscusPath = Path();
    meniscusPath.moveTo(0, waterLevelY);
    if (isReducedMotion || fillRatio >= 0.98) {
      meniscusPath.lineTo(w, waterLevelY);
    } else {
      const waveAmplitude = 2.2;
      final step = w / 30.0;
      for (double x = 0; x <= w; x += step) {
        final y =
            waterLevelY +
            sin((x / w * 2 * pi) + (wavePhase * 2 * pi)) * waveAmplitude;
        meniscusPath.lineTo(x, y);
      }
    }
    canvas.drawPath(meniscusPath, meniscusPaint);
  }

  void _paintSpecularHighlight(Canvas canvas, double w, double h) {
    final sheenPath = Path();
    sheenPath.moveTo(w * 0.38, h * 0.28);
    sheenPath.quadraticBezierTo(w * 0.28, h * 0.42, w * 0.32, h * 0.58);

    final sheenPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(sheenPath, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant StreakDropBadgePainter oldDelegate) {
    return oldDelegate.fillRatio != fillRatio ||
        oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.tier != tier ||
        oldDelegate.palette != palette ||
        oldDelegate.isReducedMotion != isReducedMotion;
  }
}
