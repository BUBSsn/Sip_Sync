import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/liquid_theme.dart';
import '../../theme/liquid_tokens.dart';
import '../../theme/reduced_motion.dart';

/// Interactive liquid slider featuring a droplet thumb, water-filled track,
/// elastic release physics via [SpringSimulation], and haptic step clicks.
///
/// **Design Invariants**:
/// - Ephemeral live updates during drag via [onChanged] (60/120 fps text updates).
/// - Persisted commits on release via [onChangeEnd] (writing to disk).
/// - Fallback to standard non-elastic circular thumb when reduced motion is enabled.
/// - Minimum 48dp touch target height conforming to WCAG AA accessibility standards.
class DropletSlider extends ConsumerStatefulWidget {
  const DropletSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.onChangeEnd,
    this.unit = '',
    this.formatter,
    this.minLabel,
    this.maxLabel,
    this.enabled = true,
    this.label,
  }) : assert(min < max, 'min must be less than max'),
       assert(step > 0, 'step must be positive');

  /// Current discrete value of the slider.
  final double value;

  /// Minimum allowed value.
  final double min;

  /// Maximum allowed value.
  final double max;

  /// Discrete step interval between snap points.
  final double step;

  /// Dispatched continuously as user drags (ephemeral preview).
  final ValueChanged<double> onChanged;

  /// Dispatched when user releases finger or completes tap (persistent commit).
  final ValueChanged<double>? onChangeEnd;

  /// Semantic unit suffix (e.g. "ml", "mins").
  final String unit;

  /// Formatter for custom value display.
  final String Function(double value)? formatter;

  /// Optional label rendered beneath track at the min boundary (e.g. "1L").
  final String? minLabel;

  /// Optional label rendered beneath track at the max boundary (e.g. "4L").
  final String? maxLabel;

  /// Whether the slider responds to user gestures.
  final bool enabled;

  /// Screen reader label for accessibility.
  final String? label;

  @override
  ConsumerState<DropletSlider> createState() => _DropletSliderState();
}

class _DropletSliderState extends ConsumerState<DropletSlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _springController;
  late double _visualFraction;
  double _dragStretchX = 0.0;
  int? _lastHapticStep;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _visualFraction = _valueToFraction(widget.value);
    _lastHapticStep = _valueToStepIndex(widget.value);

    _springController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (!_isDragging && mounted) {
          setState(() {
            _visualFraction = _springController.value.clamp(0.0, 1.0);
          });
        }
      });
  }

  @override
  void didUpdateWidget(DropletSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && oldWidget.value != widget.value) {
      final newFraction = _valueToFraction(widget.value);
      if ((newFraction - _visualFraction).abs() > 0.001) {
        _visualFraction = newFraction;
      }
    }
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  double _valueToFraction(double value) {
    if (widget.max <= widget.min) return 0.0;
    return ((value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
  }

  double _fractionToValue(double fraction) {
    final raw = widget.min + fraction * (widget.max - widget.min);
    final clamped = raw.clamp(widget.min, widget.max);
    final stepped =
        widget.min +
        (((clamped - widget.min) / widget.step).round() * widget.step);
    return stepped.clamp(widget.min, widget.max);
  }

  int _valueToStepIndex(double value) {
    return (((value - widget.min) / widget.step).round());
  }

  void _onDragStart(DragStartDetails details, double trackWidth) {
    if (!widget.enabled) return;
    _isDragging = true;
    _springController.stop();
  }

  void _onDragUpdate(
    DragUpdateDetails details,
    double trackLeft,
    double trackWidth,
  ) {
    if (!widget.enabled || trackWidth <= 0) return;

    final touchX = details.localPosition.dx - trackLeft;
    final rawFraction = (touchX / trackWidth).clamp(0.0, 1.0);

    // Dynamic horizontal droplet stretching in drag direction
    final deltaDx = details.delta.dx;
    final stretch = (deltaDx / 12.0).clamp(-0.35, 0.35);

    final snappedValue = _fractionToValue(rawFraction);
    final currentStep = _valueToStepIndex(snappedValue);

    if (currentStep != _lastHapticStep) {
      _lastHapticStep = currentStep;
      HapticFeedback.selectionClick();
    }

    setState(() {
      _visualFraction = rawFraction;
      _dragStretchX = stretch;
    });

    widget.onChanged(snappedValue);
  }

  void _onDragEnd(DragEndDetails details, double trackWidth) {
    if (!widget.enabled) return;
    _isDragging = false;

    final reduceMotion = shouldReduceMotion(context, ref);
    final velocity = details.primaryVelocity ?? 0.0;

    // Velocity-aware snap target determination
    double targetValue = _fractionToValue(_visualFraction);
    if (velocity.abs() > 400) {
      final direction = velocity > 0 ? 1 : -1;
      targetValue = (targetValue + direction * widget.step).clamp(
        widget.min,
        widget.max,
      );
    }
    final targetFraction = _valueToFraction(targetValue);

    if (reduceMotion) {
      setState(() {
        _visualFraction = targetFraction;
        _dragStretchX = 0.0;
      });
      widget.onChangeEnd?.call(targetValue);
      return;
    }

    // Spring simulation overshoot and settling
    _dragStretchX = 0.0;
    final simulation = SpringSimulation(
      const SpringDescription(mass: 1.0, stiffness: 180.0, damping: 20.0),
      _visualFraction,
      targetFraction,
      trackWidth > 0 ? (velocity / trackWidth).clamp(-4.0, 4.0) : 0.0,
    );

    _springController.animateWith(simulation).then((_) {
      if (mounted) {
        widget.onChangeEnd?.call(targetValue);
      }
    });
  }

  void _onTapUp(TapUpDetails details, double trackLeft, double trackWidth) {
    if (!widget.enabled || trackWidth <= 0) return;

    final touchX = details.localPosition.dx - trackLeft;
    final targetFraction = (touchX / trackWidth).clamp(0.0, 1.0);
    final snappedValue = _fractionToValue(targetFraction);
    final snappedFraction = _valueToFraction(snappedValue);

    HapticFeedback.selectionClick();
    widget.onChanged(snappedValue);

    final reduceMotion = shouldReduceMotion(context, ref);
    if (reduceMotion) {
      setState(() {
        _visualFraction = snappedFraction;
      });
      widget.onChangeEnd?.call(snappedValue);
    } else {
      final simulation = SpringSimulation(
        const SpringDescription(mass: 1.0, stiffness: 220.0, damping: 22.0),
        _visualFraction,
        snappedFraction,
        0.0,
      );
      _springController.animateWith(simulation).then((_) {
        if (mounted) {
          widget.onChangeEnd?.call(snappedValue);
        }
      });
    }
  }

  void _step(int direction) {
    if (!widget.enabled) return;
    final newValue = (widget.value + direction * widget.step).clamp(
      widget.min,
      widget.max,
    );
    HapticFeedback.selectionClick();
    widget.onChanged(newValue);
    widget.onChangeEnd?.call(newValue);
    setState(() {
      _visualFraction = _valueToFraction(newValue);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.liquidColors;
    final reduceMotion = shouldReduceMotion(context, ref);

    final formattedValue = widget.formatter != null
        ? widget.formatter!(widget.value)
        : '${widget.value.round()} ${widget.unit}'.trim();
    final formattedIncreased = widget.formatter != null
        ? widget.formatter!(
            (widget.value + widget.step).clamp(widget.min, widget.max),
          )
        : '${(widget.value + widget.step).clamp(widget.min, widget.max).round()} ${widget.unit}'
              .trim();
    final formattedDecreased = widget.formatter != null
        ? widget.formatter!(
            (widget.value - widget.step).clamp(widget.min, widget.max),
          )
        : '${(widget.value - widget.step).clamp(widget.min, widget.max).round()} ${widget.unit}'
              .trim();

    return Semantics(
      slider: true,
      enabled: widget.enabled,
      label: widget.label ?? 'Slider',
      value: formattedValue,
      increasedValue: formattedIncreased,
      decreasedValue: formattedDecreased,
      onIncrease: widget.enabled ? () => _step(1) : null,
      onDecrease: widget.enabled ? () => _step(-1) : null,
      child: AnimatedOpacity(
        duration: LiquidTokens.durationShort,
        opacity: widget.enabled ? 1.0 : 0.38,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                const thumbRadius = 11.0;
                final trackLeft = thumbRadius;
                final trackWidth = math.max(
                  0.0,
                  constraints.maxWidth - thumbRadius * 2,
                );

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: widget.enabled
                      ? (d) => _onDragStart(d, trackWidth)
                      : null,
                  onHorizontalDragUpdate: widget.enabled
                      ? (d) => _onDragUpdate(d, trackLeft, trackWidth)
                      : null,
                  onHorizontalDragEnd: widget.enabled
                      ? (d) => _onDragEnd(d, trackWidth)
                      : null,
                  onTapUp: widget.enabled
                      ? (d) => _onTapUp(d, trackLeft, trackWidth)
                      : null,
                  child: Container(
                    height: 48.0, // Conforms to WCAG 48dp minimum touch target
                    alignment: Alignment.center,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, 48.0),
                        painter: _DropletSliderPainter(
                          fraction: _visualFraction,
                          thumbRadius: thumbRadius,
                          palette: palette,
                          stretchX: reduceMotion ? 0.0 : _dragStretchX,
                          reduceMotion: reduceMotion,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (widget.minLabel != null || widget.maxLabel != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.minLabel ?? '',
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w500,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          widget.maxLabel ?? '',
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w500,
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DropletSliderPainter extends CustomPainter {
  const _DropletSliderPainter({
    required this.fraction,
    required this.thumbRadius,
    required this.palette,
    required this.stretchX,
    required this.reduceMotion,
  });

  final double fraction;
  final double thumbRadius;
  final LiquidColorPalette palette;
  final double stretchX;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final trackHeight = 6.0;
    final centerY = size.height / 2;
    final trackLeft = thumbRadius;
    final trackRight = size.width - thumbRadius;
    final trackWidth = math.max(0.0, trackRight - trackLeft);

    final thumbX = trackLeft + fraction * trackWidth;

    // 1. Inactive Background Track
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        trackLeft,
        centerY - trackHeight / 2,
        trackRight,
        centerY + trackHeight / 2,
      ),
      const Radius.circular(3.0),
    );
    final bgPaint = Paint()
      ..color = palette.waterShallow.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(trackRect, bgPaint);

    // 2. Active Liquid-Filled Track
    if (thumbX > trackLeft) {
      final activeRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          trackLeft,
          centerY - trackHeight / 2,
          thumbX,
          centerY + trackHeight / 2,
        ),
        const Radius.circular(3.0),
      );
      final activePaint = Paint()
        ..shader = LinearGradient(
          colors: [palette.waterMid, palette.primary],
        ).createShader(Rect.fromLTRB(trackLeft, 0, thumbX, 0))
        ..style = PaintingStyle.fill;
      canvas.drawRRect(activeRect, activePaint);
    }

    // 3. Droplet Thumb
    canvas.save();
    canvas.translate(thumbX, centerY);

    if (reduceMotion) {
      // Standard circular thumb for reduced motion
      final thumbPaint = Paint()
        ..color = palette.primary
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset.zero, thumbRadius, thumbPaint);
    } else {
      // Fluid droplet thumb with horizontal elasticity and specular gloss
      final scaleX = 1.0 + stretchX.abs() * 0.35;
      final scaleY = 1.0 - stretchX.abs() * 0.2;
      canvas.scale(scaleX, scaleY);

      // Droplet shadow
      final shadowPaint = Paint()
        ..color = palette.primary.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(const Offset(0, 1.5), thumbRadius, shadowPaint);

      // Water droplet body
      final dropletPaint = Paint()
        ..shader =
            RadialGradient(
              center: const Alignment(-0.3, -0.3),
              radius: 0.9,
              colors: [palette.waterMid, palette.primary],
            ).createShader(
              Rect.fromCircle(center: Offset.zero, radius: thumbRadius),
            )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset.zero, thumbRadius, dropletPaint);

      // Specular highlight gloss dot
      final specularPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(-thumbRadius * 0.35, -thumbRadius * 0.35),
        thumbRadius * 0.28,
        specularPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DropletSliderPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.stretchX != stretchX ||
        oldDelegate.palette != palette ||
        oldDelegate.reduceMotion != reduceMotion;
  }
}
