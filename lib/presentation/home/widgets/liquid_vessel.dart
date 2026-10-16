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

/// Interactive Living Water Vessel widget (Pillar 1).
///
/// Combines:
/// - Paint-cycle isolated [LiquidVesselPainter] inside a [RepaintBoundary]
/// - Dual sine-wave living water physics with smooth level tweens
/// - Hardware sensor accelerometer tilt slosh with lifecycle pause/resume
/// - Interactive touch ripples (capped at 3 concurrent ripples)
/// - High-contrast glassmorphic central numeric readout pill (guaranteed AA contrast)
/// - Comprehensive reduced-motion fallback
class LiquidVessel extends ConsumerStatefulWidget {
  const LiquidVessel({
    super.key,
    this.width = 280.0,
    this.height = 360.0,
    this.readoutChild,
  });

  final double width;
  final double height;

  /// Optional widget positioned inside the central high-contrast pill
  /// (e.g. including cup weight chip).
  final Widget? readoutChild;

  @override
  ConsumerState<LiquidVessel> createState() => _LiquidVesselState();
}

class _LiquidVesselState extends ConsumerState<LiquidVessel>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _waveController;
  late final AnimationController _fillController;
  late final AnimationController _rippleController;

  late Animation<double> _fillAnimation;
  double _lastTargetProgress = 0.0;

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

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _fillController = AnimationController(
      vsync: this,
      duration: LiquidTokens.durationNormal,
    );
    _fillAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _fillController, curve: LiquidTokens.curveSettle),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(_updateRipples);

    _initSensors();
  }

  void _initSensors() {
    // Platform-safe accelerometer listener with fallback for emulators / desktop targets
    try {
      _accelerometerSub = accelerometerEventStream().listen(
        (event) {
          if (!mounted) return;
          // Normalize x-axis tilt (-10 to 10 m/s^2) to radians (-0.25 to 0.25)
          final normalized = (-event.x / 9.8).clamp(-0.25, 0.25);
          _targetTilt = normalized;
          // Spring dampening low-pass step
          _currentTilt += (_targetTilt - _currentTilt) * 0.12;
        },
        onError: (Object error) {
          // Graceful fallback on unsupported platforms or permission restrictions
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

  void _syncFillAnimation(double targetProgress) {
    if ((targetProgress - _lastTargetProgress).abs() > 0.001) {
      _fillAnimation =
          Tween<double>(
            begin: _fillAnimation.value,
            end: targetProgress.clamp(0.0, 1.0),
          ).animate(
            CurvedAnimation(
              parent: _fillController,
              curve: LiquidTokens.curveSettle,
            ),
          );
      _lastTargetProgress = targetProgress;
      _fillController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelerometerSub?.cancel();
    _waveController.dispose();
    _fillController.dispose();
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

    _syncFillAnimation(hydration.visualProgress);

    return Semantics(
      label:
          'Hydration Vessel. ${hydration.currentMl} of ${hydration.goalMl} milliliters consumed. State: ${hydration.stateLabel}.',
      child: GestureDetector(
        onTapDown: _handleTapDown,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. ISOLATED REPAINT BOUNDARY FOR WAVE CANVAS
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _waveController,
                    _fillController,
                    _rippleController,
                  ]),
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size(widget.width, widget.height),
                      painter: LiquidVesselPainter(
                        fillProgress: _fillAnimation.value,
                        wavePhase: _waveController.value * 2 * pi,
                        tiltAngle: _currentTilt,
                        palette: palette,
                        isOverGoal: hydration.isOverGoal,
                        isReducedMotion: isReducedMotion,
                        ripples: List.unmodifiable(_ripples),
                      ),
                    );
                  },
                ),
              ),

              // 2. ISOLATED TEXT READOUT PILL (GUARANTEED WCAG AA CONTRAST OVER DYNAMIC LIQUID)
              _VesselReadoutPill(
                hydration: hydration,
                palette: palette,
                extraChild: widget.readoutChild,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dedicated frosted glass readout badge ensuring text glyphs never suffer
/// contrast degradation when intersected by the moving liquid surface.
class _VesselReadoutPill extends StatelessWidget {
  const _VesselReadoutPill({
    required this.hydration,
    required this.palette,
    this.extraChild,
  });

  final HydrationSnapshot hydration;
  final LiquidColorPalette palette;
  final Widget? extraChild;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Hydration progress: ${hydration.currentMl} of ${hydration.goalMl} milliliters, ${hydration.stateLabel}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LiquidTokens.spaceLg,
          vertical: LiquidTokens.spaceMd,
        ),
        margin: const EdgeInsets.symmetric(horizontal: LiquidTokens.spaceMd),
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(LiquidTokens.radiusSheet),
          border: Border.all(
            color: palette.glassBorder.withValues(alpha: 0.7),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Large Primary Volume Readout
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${hydration.currentMl}',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                  color: palette.textPrimary,
                  height: 1.1,
                ),
              ),
            ),

            // Target Goal Readout
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '/ ${hydration.goalMl} ml',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: palette.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ),

            const SizedBox(height: LiquidTokens.spaceXs),

            // Dynamic Hydration Progression / Quenched Label
            AnimatedSwitcher(
              duration: LiquidTokens.durationShort,
              child: Container(
                key: ValueKey(hydration.stateLabel),
                padding: const EdgeInsets.symmetric(
                  horizontal: LiquidTokens.spaceSm,
                  vertical: 2.0,
                ),
                decoration: BoxDecoration(
                  color: hydration.isThirstQuenched
                      ? palette.aquaHighlight.withValues(alpha: 0.18)
                      : palette.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(LiquidTokens.radiusSm),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    hydration.stateLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: hydration.isThirstQuenched
                          ? palette.primary
                          : (hydration.isOverGoal
                                ? palette.aquaHighlight
                                : palette.primary),
                    ),
                  ),
                ),
              ),
            ),

            if (extraChild != null) ...[
              const SizedBox(height: LiquidTokens.spaceSm),
              extraChild!,
            ],
          ],
        ),
      ),
    );
  }
}
