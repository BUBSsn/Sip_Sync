import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../theme/liquid_theme.dart';
import '../view_models/hydration_view_model.dart';
import 'glass_card.dart';

const raidBadgeIcons = [
  Icons.water_drop,
  Icons.shield,
  Icons.waves,
  Icons.visibility,
  Icons.diamond,
  Icons.tsunami,
  Icons.air,
  Icons.wb_sunny,
  Icons.nightlight_round,
  Icons.workspace_premium,
];
const raidBadgeColors = [
  Color(0xFF0284C7),
  Color(0xFF059669),
  Color(0xFF0891B2),
  Color(0xFF7C3AED),
  Color(0xFFDB2777),
  Color(0xFF2563EB),
  Color(0xFF0D9488),
  Color(0xFFD97706),
  Color(0xFF6366F1),
  Color(0xFFB45309),
];

/// Ten distinct vector emblems stay sharp at every phone resolution.
class RaidBadge extends StatelessWidget {
  const RaidBadge({
    super.key,
    required this.index,
    this.unlocked = true,
    this.size = 48,
  });
  final int index;
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? raidBadgeColors[index] : Colors.blueGrey;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: unlocked ? 0.13 : 0.06),
        border: Border.all(
          color: color.withValues(alpha: unlocked ? 0.8 : 0.25),
          width: 2,
        ),
      ),
      child: Icon(
        raidBadgeIcons[index],
        color: color.withValues(alpha: unlocked ? 1 : 0.4),
        size: size * 0.52,
      ),
    );
  }
}

class RaidBadgeCollection extends ConsumerWidget {
  const RaidBadgeCollection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild on intake and corrections; the saved history is the source of truth.
    ref.watch(hydrationViewModelProvider);
    final history = ref.watch(historyRepositoryProvider);
    final total = history.currentSummaries.fold<int>(
      0,
      (sum, day) => sum + day.totalMl,
    );
    final earned = BossRaidStatus.defeatedCount(total);
    final palette = context.liquidColors;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Raid badges · $earned / 10',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your journey carries across days. Each boss awards a unique badge.',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < 10; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Semantics(
                label:
                    '${BossRaidStatus.badgeNames[i]}, ${i < earned ? "earned" : "locked"}',
                child: Row(
                  children: [
                    RaidBadge(index: i, unlocked: i < earned),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            BossRaidStatus.badgeNames[i],
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: palette.textPrimary,
                            ),
                          ),
                          Text(
                            '${i + 1}. ${BossRaidStatus.bossNames[i]} · ${BossRaidStatus.hpForAct(i + 1)} HP',
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      i < earned ? Icons.check_circle : Icons.lock_outline,
                      size: 18,
                      color: i < earned
                          ? raidBadgeColors[i]
                          : palette.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
