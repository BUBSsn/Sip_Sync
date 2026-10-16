import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/domain.dart';
import '../../theme/liquid_theme.dart';
import '../../theme/liquid_tokens.dart';
import '../../view_models/connection_view_model.dart';
import '../../view_models/freshness_view_model.dart';

/// Freshness meter widget replacing the static "Last sip: Xm ago" copy (Pillar 2).
///
/// Transitions gently between fresh, fading, and dry phases based on settings threshold.
/// Never communicates through color alone: icon and text are always explicitly paired.
/// Displays a reconnection hint if the smart coaster hardware is disconnected.
class FreshnessIndicator extends ConsumerWidget {
  const FreshnessIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.liquidColors;
    final freshness = ref.watch(freshnessViewModelProvider);
    final connection = ref.watch(connectionViewModelProvider);

    // Disconnected state: frozen last known time + reconnect hint
    if (!connection.isConnected) {
      return Semantics(
        label: 'Coaster offline, reconnecting',
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LiquidTokens.spaceMd,
            vertical: LiquidTokens.spaceXs,
          ),
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(LiquidTokens.radiusPill),
            border: Border.all(
              color: palette.glassBorder.withValues(alpha: 0.5),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 15, color: palette.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Coaster offline • Reconnecting...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final IconData icon;
    final String label;
    final Color color;

    switch (freshness.phase) {
      case FreshnessPhase.fresh:
        icon = Icons.water_drop;
        label = freshness.lastSipTime == null
            ? 'Fresh Start'
            : '${freshness.elapsedDisplay} • Fresh';
        color = palette.aquaHighlight;
        break;

      case FreshnessPhase.fading:
        icon = Icons.schedule;
        label = '${freshness.elapsedDisplay} • Fading';
        color = palette.primary;
        break;

      case FreshnessPhase.dry:
        icon = Icons.spa_outlined;
        label = freshness.lastSipTime == null
            ? 'Ready for first sip'
            : 'Time for a sip • Low';
        color = palette.dryState;
        break;
    }

    return Semantics(
      label: 'Freshness status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LiquidTokens.spaceMd,
          vertical: LiquidTokens.spaceXs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(LiquidTokens.radiusPill),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
