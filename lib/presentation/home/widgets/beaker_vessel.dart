import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../theme/liquid_theme.dart';
import '../../theme/liquid_tokens.dart';
import '../../theme/reduced_motion.dart';
import '../../view_models/hydration_view_model.dart';
import 'liquid_vessel_painter.dart';

const double beakerFillScale = 0.94;

List<({String label, double ratio})> beakerScaleMarks(int goalMl) => [
  (label: '$goalMl', ratio: beakerFillScale),
  (label: '${(goalMl * 0.75).round()}', ratio: beakerFillScale * 0.75),
  (label: '${(goalMl * 0.5).round()}', ratio: beakerFillScale * 0.5),
  (label: '0 ml', ratio: 0),
];

/// Volumetric Glass Beaker Vessel featuring authentic living water optics and
/// dynamic pouring/flowing liquid animation during sips:
/// - Pure water physics with dual sine-wave depth layers
/// - Cascading crystal-blue water stream pouring into the vessel on sip intake
/// - Surface impact displacement and concentric outward ripples at stream entry
/// - Rapidly flowing liquid wave currents that smoothly accelerate during intake and settle
/// - Surface tension meniscus pulling upwards along container sidewalls
/// - Painted aqua caustic surface reflection line and diffuse reflection band
/// - Hardware accelerometer device tilt slosh with spring low-pass filtering
/// - Interactive touch ripples on the water surface
/// - Volumetric tick markings scaled to the selected daily goal
/// - Full reduced-motion accessibility support
class BeakerVessel extends ConsumerStatefulWidget {
  const BeakerVessel({
    super.key,
    this.width = 300.0,
    this.height = 238.0,
    this.compact = false,
  });

  final bool compact;
  final double width;
  final double height;

  @override
  ConsumerState<BeakerVessel> createState() => _BeakerVesselState();
}

class _BeakerVesselState extends ConsumerState<BeakerVessel>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _waveController;
  late final AnimationController _fillController;
  late final AnimationController _flowController;
  late final AnimationController _rippleController;

  late Animation<double> _fillAnimation;
  double _lastTargetProgress = 0.0;
  bool _hasInitialProgress = false;

  // Sensor tilt state
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  double _currentTilt = 0.0;
  double _targetTilt = 0.0;

  // Active touch ripples (capped at 3)
  final List<TouchRipple> _ripples = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 1. Lively living water wave motion (flowing 2200ms period)
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // 2. Liquid level transition controller
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fillAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _fillController, curve: Curves.easeInOutCubic),
    );

    // 3. Sip pour stream and fluid flow surge controller
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // 4. Touch ripples controller
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(_updateRipples);

    _initSensors();
  }

  void _initSensors() {
    try {
      _accelerometerSub = accelerometerEventStream().listen(
        (event) {
          if (!mounted) return;
          final normalized = (-event.x / 9.8).clamp(-0.25, 0.25);
          _targetTilt = normalized;
          _currentTilt += (_targetTilt - _currentTilt) * 0.12;
        },
        onError: (_) {
          _targetTilt = 0.0;
          _currentTilt = 0.0;
        },
      );
    } catch (_) {
      _targetTilt = 0.0;
      _currentTilt = 0.0;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _waveController.stop();
      _accelerometerSub?.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (!shouldReduceMotion(context, ref)) {
        _waveController.repeat();
      }
      _accelerometerSub?.resume();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (shouldReduceMotion(context, ref)) return;

    if (_ripples.length >= 3) {
      _ripples.removeAt(0);
    }

    _ripples.add(TouchRipple(center: details.localPosition, progress: 0.0));

    _rippleController.forward(from: 0.0);
  }

  void _updateRipples() {
    if (_ripples.isEmpty) return;

    final t = _rippleController.value;
    for (int i = 0; i < _ripples.length; i++) {
      _ripples[i] = TouchRipple(center: _ripples[i].center, progress: t);
    }

    if (t >= 1.0) {
      _ripples.clear();
    }
  }

  void _syncFillAnimation(double targetProgress, bool reducedMotion) {
    final target = targetProgress.clamp(0.0, 1.0);
    if (!_hasInitialProgress) {
      _hasInitialProgress = true;
      _lastTargetProgress = target;
      _fillAnimation = AlwaysStoppedAnimation(target);
      return;
    }
    if (reducedMotion) {
      _fillController.stop();
      _flowController.stop();
      _lastTargetProgress = target;
      _fillAnimation = AlwaysStoppedAnimation(target);
      return;
    }
    if ((target - _lastTargetProgress).abs() < 0.00001) return;
    final increasing = target > _lastTargetProgress;
    _fillAnimation = Tween<double>(begin: _fillAnimation.value, end: target)
        .animate(
          CurvedAnimation(parent: _fillController, curve: Curves.easeInOutSine),
        );
    _lastTargetProgress = target;
    _fillController.forward(from: 0);
    if (increasing) {
      _flowController.forward(from: 0);
    } else {
      _flowController.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelerometerSub?.cancel();
    _waveController.dispose();
    _fillController.dispose();
    _flowController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.liquidColors;
    final hydration = ref.watch(hydrationViewModelProvider);
    final isReducedMotion = shouldReduceMotion(context, ref);

    if (isReducedMotion && _waveController.isAnimating) {
      _waveController.stop();
    } else if (!isReducedMotion && !_waveController.isAnimating) {
      _waveController.repeat();
    }

    _syncFillAnimation(hydration.visualProgress, isReducedMotion);

    return Semantics(
      label:
          'Hydration Beaker Vessel: ${hydration.currentMl} of ${hydration.goalMl} ml consumed (${(hydration.visualProgress * 100).toStringAsFixed(0)}%)',
      child: GestureDetector(
        onTapDown: _handleTapDown,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _waveController,
                _fillController,
                _flowController,
                _rippleController,
              ]),
              builder: (context, _) {
                // Compute flow strength: smooth ramp-up, peak pour, and smooth taper
                double flowStrength = 0.0;
                if (!isReducedMotion && _flowController.isAnimating) {
                  final t = _flowController.value;
                  if (t < 0.15) {
                    flowStrength = Curves.easeInOutSine.transform(t / 0.15);
                  } else if (t < 0.70) {
                    flowStrength = 1.0;
                  } else {
                    flowStrength = Curves.easeInOutSine.transform(
                      ((1.0 - t) / 0.30).clamp(0.0, 1.0),
                    );
                  }
                }

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      size: Size(widget.width, widget.height),
                      painter: _RealWaterBeakerPainter(
                        compact: widget.compact,
                        fillProgress: _fillAnimation.value,
                        goalMl: hydration.goalMl,
                        wavePhase: _waveController.value * 2 * pi,
                        tiltAngle: _currentTilt,
                        flowStrength: flowStrength,
                        palette: palette,
                        isOverGoal: hydration.isOverGoal,
                        isReducedMotion: isReducedMotion,
                        ripples: List.unmodifiable(_ripples),
                      ),
                    ),
                    if (!widget.compact)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 16,
                        bottom: 24,
                        child: IgnorePointer(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.water_drop_outlined,
                                    size: 26,
                                    color: palette.primary,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${(hydration.visualProgress * 100).round()}%',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'of daily goal',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                ],
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
        ),
      ),
    );
  }
}

/// High-performance CustomPainter rendering authentic water optics and flowing
/// liquid animation during a sip:
/// - Real water depth gradient (waterShallow -> waterMid -> waterDeep)
/// - Cascading pour stream with animated vertical caustic streaks
/// - Fluid impact depression and outgoing wave ripples
/// - Rolling liquid current waves that flow smoothly during intake
/// - Surface tension meniscus pulling upwards along sidewalls
/// - Painted aqua caustic surface reflection line and diffuse reflection band
/// - Device tilt slosh physics
/// - Volumetric tick marks scaled to the daily goal
class _RealWaterBeakerPainter extends CustomPainter {
  _RealWaterBeakerPainter({
    required this.compact,
    required this.fillProgress,
    required this.goalMl,
    required this.wavePhase,
    required this.tiltAngle,
    required this.flowStrength,
    required this.palette,
    required this.isOverGoal,
    required this.isReducedMotion,
    required this.ripples,
  });

  final bool compact;
  final double fillProgress;
  final int goalMl;
  final double wavePhase;
  final double tiltAngle;
  final double flowStrength;
  final LiquidColorPalette palette;
  final bool isOverGoal;
  final bool isReducedMotion;
  final List<TouchRipple> ripples;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final w = size.width;
    final h = size.height;

    // Equal gutters center the vessel; scale labels occupy the left gutter.
    final vesselRect = compact
        ? Rect.fromLTRB(6, 4, w - 6, h - 4)
        : Rect.fromLTRB(w * 0.25, 16, w * 0.75, h - 24);
    final rrect = RRect.fromRectAndRadius(
      vesselRect,
      Radius.circular(compact ? 16 : 30),
    );

    // 1. Subtle glass background fill
    final glassFillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          palette.primary.withValues(alpha: 0.035),
          palette.primary.withValues(alpha: 0.09),
        ],
      ).createShader(vesselRect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, glassFillPaint);

    // 2. Liquid and pouring stream clipped inside the vessel
    canvas.save();
    canvas.clipRRect(rrect);

    final currentSurfaceY = _paintLiquid(canvas, vesselRect);
    _paintPourStream(canvas, vesselRect, currentSurfaceY);
    _paintRipples(canvas);

    canvas.restore();

    // 3. Volumetric tick marks on glass
    _paintTickMarks(canvas, vesselRect);

    // 4. Outer glass container walls, sheen highlight and border
    _paintGlassContainer(canvas, rrect, vesselRect);
  }

  double _paintLiquid(Canvas canvas, Rect bounds) {
    final safeProgress = fillProgress.clamp(0.0, 1.0);
    if (safeProgress <= 0.001) return bounds.bottom;

    final effectiveFill = safeProgress * beakerFillScale;
    final liquidHeight = bounds.height * effectiveFill;
    final baseSurfaceY = bounds.bottom - liquidHeight;

    final w = bounds.width;
    final left = bounds.left;
    final right = bounds.right;
    final bottom = bounds.bottom + 8.0;

    final tiltSlope = isReducedMotion ? 0.0 : tan(tiltAngle.clamp(-0.25, 0.25));

    // Liquid flow dynamics: flow speed accelerates and currents roll during a sip
    final effectiveWavePhase = wavePhase;

    // --- Back Wave (Deep layer) ---
    if (!isReducedMotion) {
      final backWavePath = Path()..moveTo(left, bottom);

      final backAmp =
          (4.0 + flowStrength * 3.0) * (1.0 - (safeProgress - 0.5).abs() * 0.4);
      const backFreq = 1.8;
      final backPhase = effectiveWavePhase + 1.2;

      for (double x = left; x <= right; x += 2.0) {
        final relX = (x - left) / w;
        final tiltOffset = (relX - 0.5) * w * tiltSlope;
        final waveOffset = sin(relX * 2 * pi * backFreq + backPhase) * backAmp;
        final y = baseSurfaceY + tiltOffset + waveOffset;
        backWavePath.lineTo(x, y);
      }
      backWavePath.lineTo(right, bottom);
      backWavePath.close();

      final backPaint = Paint()
        ..color = palette.waterDeep.withValues(alpha: 0.65)
        ..style = PaintingStyle.fill;
      canvas.drawPath(backWavePath, backPaint);
    }

    // --- Front Wave (Primary liquid volume with depth gradient & meniscus) ---
    final frontWavePath = Path()..moveTo(left, bottom);

    final frontAmp = isReducedMotion ? 0.0 : (3.5 + flowStrength * 3.5);
    const frontFreq = 1.35;
    final frontPhase = isReducedMotion ? 0.0 : effectiveWavePhase;

    // Pour stream impact point coordinates (relX = 0.58)
    const streamRelX = 0.58;

    final surfacePoints = <Offset>[];

    for (double x = left; x <= right; x += 2.0) {
      final relX = (x - left) / w;
      final tiltOffset = (relX - 0.5) * w * tiltSlope;

      // Surface tension meniscus: slight upward lift at container sidewalls
      double meniscus = 0.0;
      if (relX < 0.08) {
        meniscus = -2.8 * (1.0 - relX / 0.08);
      } else if (relX > 0.92) {
        meniscus = -2.8 * ((relX - 0.92) / 0.08);
      }

      // Rolling fluid wave + horizontal flowing current
      final rollingWave =
          sin(relX * 2 * pi * frontFreq + frontPhase) * frontAmp;
      final flowingCurrent = flowStrength > 0.01
          ? sin(relX * 2 * pi * 2.2 - effectiveWavePhase * 2) *
                (flowStrength * 2.0)
          : 0.0;

      // Physical impact dip and outgoing circular ripples at pour entry
      final distFromStream = (relX - streamRelX).abs();
      final impactDip = flowStrength > 0.01
          ? -flowStrength * exp(-distFromStream * distFromStream / 0.015) * 3.5
          : 0.0;
      final impactRipples = flowStrength > 0.01
          ? flowStrength *
                sin(distFromStream * 22.0 - effectiveWavePhase * 3) *
                1.8
          : 0.0;

      final y =
          baseSurfaceY +
          tiltOffset +
          meniscus +
          rollingWave +
          flowingCurrent +
          impactDip +
          impactRipples;

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
        Rect.fromLTRB(left, baseSurfaceY - 8, right, bottom),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(frontWavePath, liquidPaint);

    // --- Painted Caustic Surface Line & Diffuse Reflection ---
    if (surfacePoints.isNotEmpty && !isReducedMotion) {
      final causticPath = Path()
        ..moveTo(surfacePoints.first.dx, surfacePoints.first.dy);
      for (int i = 1; i < surfacePoints.length; i++) {
        causticPath.lineTo(surfacePoints[i].dx, surfacePoints[i].dy);
      }

      final causticAlpha = isOverGoal ? 0.95 : (0.75 + flowStrength * 0.2);
      final causticPaint = Paint()
        ..color = palette.aquaHighlight.withValues(alpha: causticAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isOverGoal ? 2.4 : (1.6 + flowStrength * 0.8)
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(causticPath, causticPaint);

      // Diffuse reflection band just beneath the surface line
      final diffusePaint = Paint()
        ..color = palette.aquaHighlight.withValues(
          alpha: isOverGoal ? 0.40 : (0.22 + flowStrength * 0.18),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 + flowStrength * 1.5;
      canvas.drawPath(causticPath, diffusePaint);
    }

    return baseSurfaceY;
  }

  void _paintPourStream(Canvas canvas, Rect bounds, double surfaceY) {
    if (flowStrength <= 0.02 || isReducedMotion) return;

    final streamX = bounds.left + bounds.width * 0.58;
    final streamTop = bounds.top + 2.0;
    final impactY = surfaceY.clamp(bounds.top + 10.0, bounds.bottom);

    if (impactY <= streamTop + 6.0) return;

    final halfWidth = 2.4 + flowStrength * 1.8;

    // Stream geometry: cascading fluid entering from above
    final streamPath = Path()
      ..moveTo(streamX - halfWidth, streamTop)
      ..lineTo(streamX + halfWidth, streamTop)
      ..lineTo(streamX + halfWidth * 0.85, impactY)
      ..lineTo(streamX - halfWidth * 0.85, impactY)
      ..close();

    final streamGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        palette.waterShallow.withValues(alpha: 0.80 * flowStrength),
        palette.waterMid.withValues(alpha: 0.88 * flowStrength),
        palette.aquaHighlight.withValues(alpha: 0.95 * flowStrength),
      ],
    );

    final streamPaint = Paint()
      ..shader = streamGradient.createShader(
        Rect.fromLTRB(
          streamX - halfWidth,
          streamTop,
          streamX + halfWidth,
          impactY,
        ),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(streamPath, streamPaint);

    // Animated fast downward-flowing water streaks
    final streakPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75 * flowStrength)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final streakOffset = (wavePhase / (2 * pi) * 108.0) % 18.0;
    for (double y = streamTop + streakOffset; y < impactY - 4.0; y += 18.0) {
      canvas.drawLine(
        Offset(streamX - 0.4, y),
        Offset(streamX - 0.4, (y + 9.0).clamp(streamTop, impactY - 2.0)),
        streakPaint,
      );
    }

    // Impact spray droplets at the water entry point
    final splashPaint = Paint()
      ..color = palette.aquaHighlight.withValues(alpha: 0.85 * flowStrength)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final splashCycle = sin(wavePhase * 4);
    final splashSpread = 4.5 + splashCycle * 2.0;

    canvas.drawLine(
      Offset(streamX - 2.0, impactY),
      Offset(streamX - 2.0 - splashSpread, impactY - 4.0 - flowStrength * 2.0),
      splashPaint,
    );
    canvas.drawLine(
      Offset(streamX + 2.0, impactY),
      Offset(streamX + 2.0 + splashSpread, impactY - 4.0 - flowStrength * 2.0),
      splashPaint,
    );
  }

  void _paintRipples(Canvas canvas) {
    if (ripples.isEmpty || isReducedMotion) return;

    for (final ripple in ripples.take(3)) {
      final alpha = (1.0 - ripple.progress).clamp(0.0, 1.0);
      final radius = ripple.progress * 55.0;

      final ripplePaint = Paint()
        ..color = palette.aquaHighlight.withValues(alpha: alpha * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;

      canvas.drawCircle(ripple.center, radius, ripplePaint);

      if (radius > 12.0) {
        final innerPaint = Paint()
          ..color = palette.aquaHighlight.withValues(alpha: alpha * 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(ripple.center, radius * 0.6, innerPaint);
      }
    }
  }

  void _paintTickMarks(Canvas canvas, Rect bounds) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final tickPaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final marks = beakerScaleMarks(goalMl);

    for (final mark in marks) {
      final y = bounds.bottom - (bounds.height * mark.ratio);
      canvas.drawLine(
        Offset(compact ? bounds.left + 7 : bounds.left - 9, y),
        Offset(compact ? bounds.left + 11 : bounds.left - 3, y),
        tickPaint,
      );

      textPainter.text = TextSpan(
        text: mark.label,
        style: const TextStyle(
          color: Color(0xFF717985),
          fontFamily: LiquidTheme.homeFont,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          compact ? bounds.left + 15 : bounds.left - 15 - textPainter.width,
          (y - textPainter.height / 2).clamp(
            bounds.top + 4,
            bounds.bottom - textPainter.height - 4,
          ),
        ),
      );
    }
  }

  void _paintGlassContainer(Canvas canvas, RRect rrect, Rect bounds) {
    // 1. Container outer border
    final borderPaint = Paint()
      ..color = palette.glassBorder.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rrect, borderPaint);

    // 2. Over-goal rim illumination
    if (isOverGoal) {
      final glowPaint = Paint()
        ..color = palette.aquaHighlight.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);

      final rimPath = Path()
        ..moveTo(rrect.left, rrect.top + 16)
        ..arcToPoint(
          Offset(rrect.left + 16, rrect.top),
          radius: const Radius.circular(20.0),
        )
        ..lineTo(rrect.right - 16, rrect.top)
        ..arcToPoint(
          Offset(rrect.right, rrect.top + 16),
          radius: const Radius.circular(20.0),
        );
      canvas.drawPath(rimPath, glowPaint);
    }

    // 3. Specular glass wall reflection highlight (left edge sheen)
    final sheenPath = Path()
      ..moveTo(rrect.left + 6, rrect.top + 20)
      ..lineTo(rrect.left + 6, rrect.bottom - 24);

    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(bounds)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(sheenPath, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant _RealWaterBeakerPainter oldDelegate) {
    return oldDelegate.compact != compact ||
        oldDelegate.goalMl != goalMl ||
        oldDelegate.fillProgress != fillProgress ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.tiltAngle != tiltAngle ||
        oldDelegate.flowStrength != flowStrength ||
        oldDelegate.palette != palette ||
        oldDelegate.isOverGoal != isOverGoal ||
        oldDelegate.isReducedMotion != isReducedMotion ||
        oldDelegate.ripples != ripples;
  }
}
