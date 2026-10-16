import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/liquid_tokens.dart';

/// Active touch ripple model (capped at maximum 3 concurrent ripples).
@immutable
class TouchRipple {
  const TouchRipple({required this.center, required this.progress});

  /// Tap location on the vessel.
  final Offset center;

  /// Expansion and dissipation progress from 0.0 to 1.0.
  final double progress;
}

/// High-performance CustomPainter rendering living water physics:
/// - Pure water optics: dual-layer sine waves, depth gradient, meniscus at walls, caustics
/// - Glass container silhouette with soft rim, walls, and base
/// - Slosh tilt and touch ripples
/// - Over-goal rim illumination
/// - Reduced-motion fallback (static level, calm water)
class LiquidVesselPainter extends CustomPainter {
  LiquidVesselPainter({
    required this.fillProgress,
    required this.wavePhase,
    required this.tiltAngle,
    required this.palette,
    required this.isOverGoal,
    required this.isReducedMotion,
    this.ripples = const [],
    super.repaint,
  });

  /// Visual fill ratio (0.0 .. 1.0 clamped).
  final double fillProgress;

  /// Continuous oscillating wave phase in radians (0.0 .. 2*pi).
  final double wavePhase;

  /// Device tilt slant angle in radians.
  final double tiltAngle;

  /// Active theme color palette.
  final LiquidColorPalette palette;

  /// Whether current intake meets or exceeds 100% daily goal.
  final bool isOverGoal;

  /// Accessibility reduced-motion active flag.
  final bool isReducedMotion;

  /// Active expanding touch ripples (max 3).
  final List<TouchRipple> ripples;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final w = size.width;
    final h = size.height;

    // Inset to accommodate outer glass border stroke
    const double padding = 8.0;
    final vesselRect = Rect.fromLTWH(
      padding,
      padding,
      w - padding * 2,
      h - padding * 2,
    );

    // Vessel interior geometry: rounded tumbler with soft rim and base
    final rrect = RRect.fromRectAndCorners(
      vesselRect,
      topLeft: const Radius.circular(24.0),
      topRight: const Radius.circular(24.0),
      bottomLeft: const Radius.circular(28.0),
      bottomRight: const Radius.circular(28.0),
    );

    final vesselInteriorPath = Path()..addRRect(rrect);

    // 1. Draw subtle vessel glass background fill
    final glassFillPaint = Paint()
      ..color = palette.glassFill
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, glassFillPaint);

    // 2. Draw liquid inside the clipped vessel interior
    canvas.save();
    canvas.clipPath(vesselInteriorPath);

    _paintLiquid(canvas, vesselRect);

    // 3. Draw active touch ripples on top of liquid
    _paintRipples(canvas);

    canvas.restore();

    // 4. Draw outer glass container walls, rim, and sheen
    _paintGlassContainer(canvas, rrect, vesselRect);
  }

  void _paintLiquid(Canvas canvas, Rect bounds) {
    // Clamped visual fill level: caps at 96% to always preserve an air gap below rim
    final safeProgress = fillProgress.clamp(0.0, 1.0);
    if (safeProgress <= 0.001) return;

    final effectiveFill = safeProgress * 0.96;
    final liquidHeight = bounds.height * effectiveFill;
    final baseSurfaceY = bounds.bottom - liquidHeight;

    final w = bounds.width;
    final left = bounds.left;
    final right = bounds.right;
    final bottom = bounds.bottom + 10.0; // Extend slightly to cover corners

    final tiltSlope = isReducedMotion ? 0.0 : tan(tiltAngle.clamp(-0.25, 0.25));

    // --- Back Wave (Deep layer) ---
    if (!isReducedMotion) {
      final backWavePath = Path();
      backWavePath.moveTo(left, bottom);

      final backAmp = 5.0 * (1.0 - (safeProgress - 0.5).abs() * 0.4);
      const backFreq = 1.8;
      final backPhase = wavePhase * 0.9 + 1.2;

      for (double x = left; x <= right; x += 3.0) {
        final relX = (x - left) / w;
        final tiltOffset = (relX - 0.5) * w * tiltSlope;
        final waveOffset = sin(relX * 2 * pi * backFreq + backPhase) * backAmp;
        final y = baseSurfaceY + tiltOffset + waveOffset;
        if (x == left) {
          backWavePath.lineTo(x, y);
        } else {
          backWavePath.lineTo(x, y);
        }
      }
      backWavePath.lineTo(right, bottom);
      backWavePath.close();

      final backPaint = Paint()
        ..color = palette.waterDeep.withValues(alpha: 0.65)
        ..style = PaintingStyle.fill;
      canvas.drawPath(backWavePath, backPaint);
    }

    // --- Front Wave (Primary liquid volume with depth gradient) ---
    final frontWavePath = Path();
    frontWavePath.moveTo(left, bottom);

    final frontAmp = isReducedMotion ? 0.0 : 4.0;
    const frontFreq = 1.3;
    final frontPhase = isReducedMotion ? 0.0 : wavePhase * 1.3;

    // Track points for caustic surface stroke
    final surfacePoints = <Offset>[];

    for (double x = left; x <= right; x += 3.0) {
      final relX = (x - left) / w;
      final tiltOffset = (relX - 0.5) * w * tiltSlope;

      // Surface tension meniscus: slight upward lift at container sidewalls
      double meniscus = 0.0;
      if (relX < 0.08) {
        meniscus = -3.0 * (1.0 - relX / 0.08);
      } else if (relX > 0.92) {
        meniscus = -3.0 * ((relX - 0.92) / 0.08);
      }

      final waveOffset = isReducedMotion
          ? 0.0
          : sin(relX * 2 * pi * frontFreq + frontPhase) * frontAmp;

      final y = baseSurfaceY + tiltOffset + waveOffset + meniscus;
      frontWavePath.lineTo(x, y);
      surfacePoints.add(Offset(x, y));
    }

    frontWavePath.lineTo(right, bottom);
    frontWavePath.close();

    // Pure-water depth gradient: crystal cyan surface down to dense deep water
    final depthGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        palette.waterShallow.withValues(alpha: 0.88),
        palette.waterMid.withValues(alpha: 0.92),
        palette.waterDeep.withValues(alpha: 0.98),
      ],
      stops: const [0.0, 0.45, 1.0],
    );

    final liquidPaint = Paint()
      ..shader = depthGradient.createShader(
        Rect.fromLTRB(left, baseSurfaceY - 10, right, bottom),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(frontWavePath, liquidPaint);

    // --- Painted Caustic Surface Line ---
    if (surfacePoints.isNotEmpty && !isReducedMotion) {
      final causticPath = Path()
        ..moveTo(surfacePoints.first.dx, surfacePoints.first.dy);
      for (int i = 1; i < surfacePoints.length; i++) {
        causticPath.lineTo(surfacePoints[i].dx, surfacePoints[i].dy);
      }

      final causticAlpha = isOverGoal ? 0.95 : 0.70;
      final causticPaint = Paint()
        ..color = palette.aquaHighlight.withValues(alpha: causticAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isOverGoal ? 2.5 : 1.8
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(causticPath, causticPaint);

      // Secondary diffuse reflection band just below the surface
      final diffusePaint = Paint()
        ..color = palette.aquaHighlight.withValues(
          alpha: isOverGoal ? 0.45 : 0.25,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawPath(causticPath, diffusePaint);
    }
  }

  void _paintRipples(Canvas canvas) {
    if (ripples.isEmpty || isReducedMotion) return;

    for (final ripple in ripples.take(3)) {
      final alpha = (1.0 - ripple.progress).clamp(0.0, 1.0);
      final radius = ripple.progress * 65.0;

      final ripplePaint = Paint()
        ..color = palette.aquaHighlight.withValues(alpha: alpha * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(ripple.center, radius, ripplePaint);

      if (radius > 15.0) {
        final innerPaint = Paint()
          ..color = palette.aquaHighlight.withValues(alpha: alpha * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(ripple.center, radius * 0.6, innerPaint);
      }
    }
  }

  void _paintGlassContainer(Canvas canvas, RRect rrect, Rect bounds) {
    // 1. Container outer border
    final borderPaint = Paint()
      ..color = palette.glassBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, borderPaint);

    // 2. Over-goal celebratory rim illumination
    if (isOverGoal) {
      final glowPaint = Paint()
        ..color = palette.aquaHighlight.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);

      // Highlight the top rim arc
      final rimPath = Path()
        ..moveTo(rrect.left, rrect.top + 20)
        ..arcToPoint(
          Offset(rrect.left + 20, rrect.top),
          radius: const Radius.circular(24.0),
        )
        ..lineTo(rrect.right - 20, rrect.top)
        ..arcToPoint(
          Offset(rrect.right, rrect.top + 20),
          radius: const Radius.circular(24.0),
        );
      canvas.drawPath(rimPath, glowPaint);
    }

    // 3. Specular glass wall reflection highlight (left edge sheen)
    final sheenPath = Path()
      ..moveTo(rrect.left + 8, rrect.top + 30)
      ..lineTo(rrect.left + 8, rrect.bottom - 40);

    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(bounds)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(sheenPath, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant LiquidVesselPainter oldDelegate) {
    return oldDelegate.fillProgress != fillProgress ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.tiltAngle != tiltAngle ||
        oldDelegate.palette != palette ||
        oldDelegate.isOverGoal != isOverGoal ||
        oldDelegate.isReducedMotion != isReducedMotion ||
        oldDelegate.ripples != ripples;
  }
}
