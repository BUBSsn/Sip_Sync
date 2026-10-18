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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      Theme(data: LiquidTheme.home, child: const _HomeContent());
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.liquidColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: colors.surface,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: const _HomeAppBar(),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const GlassCard(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          child: FreshnessIndicator(),
                        ),
                        const SizedBox(height: 16),
                        const _HydrationCard(),
                        const SizedBox(height: 16),
                        const _BossRaidCard(),
                        const SizedBox(height: 26),
                        Text(
                          'Today’s sips',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const SipLogList(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HydrationCard extends ConsumerWidget {
  const _HydrationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hydration = ref.watch(hydrationViewModelProvider);
    final colors = context.liquidColors;
    final readout = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          hydration.stateLabel,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _formatVolume(hydration.currentMl),
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 42,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.8,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '/ ${_formatVolume(hydration.goalMl)} ml',
          style: TextStyle(color: colors.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricTile(
              label: 'of daily goal',
              value: '${(hydration.visualProgress * 100).round()}%',
              background: const Color(0xFFEFEDFF),
            ),
            _MetricTile(
              label: 'XP today',
              value: '+${hydration.xpToday}',
              background: const Color(0xFFD8FAEB),
            ),
          ],
        ),
        if (hydration.currentMl == 0) ...[
          const SizedBox(height: 14),
          Text(
            'Your next sip starts here',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );
    const vessel = SizedBox(
      width: 102,
      height: 238,
      child: BeakerVessel(width: 102, height: 238, compact: true),
    );
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Today’s hydration',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Let large accessibility text use the full card width.
                  if (constraints.maxWidth < 260 ||
                      MediaQuery.textScalerOf(context).scale(16) > 24) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(child: vessel),
                        const SizedBox(height: 16),
                        readout,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      vessel,
                      const SizedBox(width: 20),
                      Expanded(child: readout),
                    ],
                  );
                },
              ),
            ],
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) => SipFeedbackOverlay(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.background,
  });
  final String label;
  final String value;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: context.liquidColors.primary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: context.liquidColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
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
                      fontWeight: FontWeight.w600,
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
                            fontWeight: FontWeight.w600,

                            letterSpacing: 0.1,
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
                    fontWeight: FontWeight.w500,

                    color: Color(0xFF64748B),
                    letterSpacing: 0.0,
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
        border: Border.all(color: const Color(0xFFF0F1F5), width: 1),
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
                            'Boss raid',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEF4444),
                              letterSpacing: 0.1,
                            ),
                          ),
                          Text(
                            ' · ${boss.actName}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.1,
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
                        fontWeight: FontWeight.w600,
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
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF059669),
                    letterSpacing: 0.0,
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
                  'Boss HP damage',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$pctComplete% Complete',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D9488),
                  letterSpacing: 0.0,
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
              backgroundColor: const Color(0xFFEFEDFF),
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

                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Loot: ${boss.lootName}',
                  style: const TextStyle(
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
