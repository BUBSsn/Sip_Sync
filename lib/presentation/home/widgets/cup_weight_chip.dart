import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/liquid_theme.dart';
import '../../theme/liquid_tokens.dart';
import '../../theme/reduced_motion.dart';
import '../../view_models/live_weight_provider.dart';

/// Live scale chip displaying the physical cup weight sampled by the coaster hardware (Pillar 2).
///
/// Subtly pulses when the scale registers weight updates.
class CupWeightChip extends ConsumerWidget {
  const CupWeightChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.liquidColors;
    final weight = ref.watch(liveWeightProvider);
    final isReducedMotion = shouldReduceMotion(context, ref);

    final chip = Semantics(
      label: 'Coaster cup weight: ${weight.toStringAsFixed(0)} grams',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LiquidTokens.spaceSm,
          vertical: 4.0,
        ),
        decoration: BoxDecoration(
          color: palette.glassFill,
          borderRadius: BorderRadius.circular(LiquidTokens.radiusSm),
          border: Border.all(
            color: palette.glassBorder.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.scale_outlined, size: 14, color: palette.textSecondary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Cup Weight: ${weight.toStringAsFixed(0)}g',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.textSecondary,
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    if (isReducedMotion) {
      return chip;
    }

    // Subtle scale and shimmer pulse on weight shift
    return chip
        .animate(key: ValueKey(weight))
        .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1.0, 1.0),
          duration: LiquidTokens.durationShort,
          curve: Curves.easeOutBack,
        );
  }
}
