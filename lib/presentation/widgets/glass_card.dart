import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/liquid_theme.dart';
import '../theme/liquid_tokens.dart';
import '../theme/reduced_motion.dart';

/// A glassmorphic card widget with a frosted [BackdropFilter] glass surface,
/// subtle border, and inner light sheen highlight.
///
/// Automatically downgrades to an opaque, solid-color card when reduced effects
/// is active (system accessibility or manual toggle) for 60fps performance on low-end hardware.
class GlassCard extends ConsumerWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(LiquidTokens.spaceMd),
    this.margin,
    this.borderRadius,
    this.onTap,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.liquidColors;
    final radius =
        borderRadius ?? BorderRadius.circular(LiquidTokens.radiusCard);
    final reduceEffects = shouldReduceMotion(context, ref);

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      content = InkWell(onTap: onTap, borderRadius: radius, child: content);
    }

    if (reduceEffects) {
      // Solid fallback surface without expensive blur
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          color: palette.cardFallback,
          borderRadius: radius,
          border: Border.all(
            color: palette.glassBorder.withValues(alpha: 0.5),
            width: 1.0,
          ),
          boxShadow: LiquidTokens.cardShadow(palette),
        ),
        child: ClipRRect(borderRadius: radius, child: content),
      );
    }

    // Full glassmorphic frosted surface
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: LiquidTokens.cardShadow(palette),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LiquidTokens.glassSheenGradient(palette),
              borderRadius: radius,
              border: Border.all(color: palette.glassBorder, width: 1.0),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
