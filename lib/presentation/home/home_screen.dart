import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/liquid_theme.dart';
import '../theme/liquid_tokens.dart';
import '../view_models/connection_view_model.dart';
import '../view_models/hydration_view_model.dart';
import '../widgets/glass_card.dart';
import 'widgets/beaker_vessel.dart';
import '../widgets/raid_badges.dart';
import 'widgets/sip_feedback_overlay.dart';
import 'widgets/sip_log_list.dart';
import 'widgets/freshness_indicator.dart';

String _formatVolume(int ml) => ml.toString().replaceAllMapped(
  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
  (m) => '${m[1]},',
);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hydration = ref.watch(hydrationViewModelProvider);
    final colors = context.liquidColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LiquidTokens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _HomeAppBar(),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Today’s hydration',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(
                      height: 250,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          BeakerVessel(),
                          Positioned.fill(child: SipFeedbackOverlay()),
                        ],
                      ),
                    ),
                    if (hydration.currentMl == 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Your next sip starts here',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      '${_formatVolume(hydration.currentMl)} / ${_formatVolume(hydration.goalMl)} ml',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hydration.stateLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '+${hydration.xpToday} XP today',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    const FreshnessIndicator(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _BossRaidCard(),
              const SizedBox(height: 24),
              Text(
                'Today’s sips',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const SipLogList(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeAppBar extends ConsumerWidget {
  const _HomeAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(
      connectionViewModelProvider.select((c) => c.isConnected),
    );
    final level = ref.watch(hydrationViewModelProvider.select((h) => h.level));
    final currentLevelXp = ref.watch(
      hydrationViewModelProvider.select((h) => h.currentLevelXp),
    );
    final nextLevelXp = ref.watch(
      hydrationViewModelProvider.select((h) => h.nextLevelXp),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Column: Brand + inline status + level/XP
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SipSync',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: Color(0xFF0D5D68),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Inline ONLINE / OFFLINE pill badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? const Color(0xFFCCFBF1)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(
                        LiquidTokens.radiusPill,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isConnected
                                ? const Color(0xFF00C48C)
                                : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isConnected ? 'ONLINE' : 'OFFLINE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                            color: isConnected
                                ? const Color(0xFF059669)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  level >= 50
                      ? 'Home · LVL 50 · MAX LEVEL'
                      : 'Home · LVL $level [${_formatVolume(currentLevelXp)} / ${_formatVolume(nextLevelXp)} XP]',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Right: Profile Avatar circle (battery pill intentionally omitted)
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Color(0xFF006677),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }
}

class _BossRaidCard extends ConsumerWidget {
  const _BossRaidCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hydration = ref.watch(hydrationViewModelProvider);
    final boss = hydration.bossRaid;
    final progress = boss.progress;
    final remainingMl = boss.remainingMl;
    final pctComplete = (boss.progress * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(LiquidTokens.radiusCard),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A6673).withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Retro sprite + [ BOSS RAID ] · ACT + Defeat Dehydration + loot XP
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RaidBadge(index: boss.act - 1, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        children: [
                          const Text(
                            '[ BOSS RAID ]',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFEF4444),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            ' · ${boss.actName}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      boss.bossName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(LiquidTokens.radiusPill),
                ),
                child: Text(
                  boss.isComplete ? 'COMPLETE' : '+${boss.lootXp} XP',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF059669),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // HP Damage labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'BOSS HP DAMAGE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$pctComplete% Complete',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D9488),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Thick rounded progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFCCFBF1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF0A6673),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Bottom details: ml to knockout + LOOT
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  boss.isComplete
                      ? 'All 10 bosses defeated!'
                      : '${_formatVolume(remainingMl)} ml to Knockout',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'LOOT: ${boss.lootName}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
