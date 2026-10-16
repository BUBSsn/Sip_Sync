import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/domain.dart';
import '../../theme/liquid_theme.dart';
import '../../theme/liquid_tokens.dart';
import '../../view_models/today_sips_view_model.dart';
import 'adjust_sip_dialog.dart';
import '../../widgets/glass_card.dart';

/// Droplet timeline displaying today's automated sip log entries (Pillar 2).
///
/// Entries are ordered newest first by timestamp, with volume-proportional droplet icons,
/// glassmorphic card styling, and three-dot overflow actions (adjust volume, delete entry).
class SipLogList extends ConsumerWidget {
  const SipLogList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.liquidColors;
    final sips = ref.watch(todaySipsViewModelProvider);

    if (sips.isEmpty) {
      return const _EmptySipLogState();
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sips.length,
      separatorBuilder: (_, _) => const SizedBox(height: LiquidTokens.spaceSm),
      itemBuilder: (context, index) {
        final sip = sips[index];
        return _SipLogItem(
          key: ValueKey(sip.id),
          sip: sip,
          palette: palette,
          onAdjust: (newVol) async {
            try {
              await ref
                  .read(todaySipsViewModelProvider.notifier)
                  .updateSipVolume(sip.id, newVol);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not save the sip change. Please retry.',
                    ),
                  ),
                );
              }
            }
          },
          onDelete: () async {
            try {
              await ref
                  .read(todaySipsViewModelProvider.notifier)
                  .deleteSip(sip.id);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not delete the sip. Please retry.'),
                  ),
                );
              }
            }
          },
        );
      },
    );
  }
}

class _SipLogItem extends StatelessWidget {
  const _SipLogItem({
    super.key,
    required this.sip,
    required this.palette,
    required this.onAdjust,
    required this.onDelete,
  });

  final SipEvent sip;
  final LiquidColorPalette palette;
  final ValueChanged<int> onAdjust;
  final VoidCallback onDelete;

  double _getDropletSize(int ml) {
    // Proportional droplet scale: 14dp (small sips <= 30ml) to 26dp (large sips >= 250ml)
    final clamped = ml.clamp(30, 250);
    return 14.0 + (clamped - 30) / 220.0 * 12.0;
  }

  String _formatTime(DateTime timestamp) {
    final local = timestamp.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$formattedHour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final dropletRadius = _getDropletSize(sip.volumeMl);

    final formattedTime = _formatTime(sip.timestamp);
    return Semantics(
      label: '${sip.volumeMl} milliliters sip logged at $formattedTime',
      child: GlassCard(
        padding: const EdgeInsets.symmetric(
          horizontal: LiquidTokens.spaceMd,
          vertical: LiquidTokens.spaceSm,
        ),
        borderRadius: BorderRadius.circular(LiquidTokens.radiusCard),
        child: Row(
          children: [
            // Proportional Water Droplet Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.waterShallow.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.water_drop,
                size: dropletRadius * 1.5,
                color: palette.aquaHighlight,
              ),
            ),
            const SizedBox(width: LiquidTokens.spaceMd),

            // Sip Volume & Timestamp
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${sip.volumeMl}ml sip',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatTime(sip.timestamp)}${sip.timestampEstimated ? ' · time estimated' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Three-Dot Overflow Menu
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: palette.textSecondary.withValues(alpha: 0.8),
                size: 20,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LiquidTokens.radiusSm),
              ),
              color: palette.surface,
              onSelected: (action) {
                if (action == 'adjust') {
                  AdjustSipDialog.show(
                    context: context,
                    initialVolumeMl: sip.volumeMl,
                    onSave: onAdjust,
                    onDelete: onDelete,
                  );
                } else if (action == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'adjust',
                  child: Row(
                    children: [
                      Icon(Icons.tune, size: 18, color: palette.textPrimary),
                      const SizedBox(width: LiquidTokens.spaceSm),
                      const Text('Adjust volume'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: palette.dryState,
                      ),
                      const SizedBox(width: LiquidTokens.spaceSm),
                      Text(
                        'Delete entry',
                        style: TextStyle(color: palette.dryState),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySipLogState extends StatelessWidget {
  const _EmptySipLogState();

  @override
  Widget build(BuildContext context) {
    final palette = context.liquidColors;

    return GlassCard(
      padding: const EdgeInsets.all(LiquidTokens.spaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.water_drop_outlined,
            size: 36,
            color: palette.textSecondary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: LiquidTokens.spaceSm),
          Text(
            'No sips logged yet today',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Place your cup on the coaster or take a sip to start flowing!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
