import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/liquid_theme.dart';
import '../theme/liquid_tokens.dart';
import '../theme/theme_mode_provider.dart';
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
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Theme(
      data: LiquidTheme.homeTheme(brightness),
      child: const _HomeContent(),
    );
  }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              darkBackground: const Color(0xFF1E1E38),
              textColor: isDark ? const Color(0xFFA5B4FC) : null,
              borderColor: isDark
                  ? const Color(0xFF818CF8).withValues(alpha: 0.25)
                  : null,
            ),
            _MetricTile(
              label: 'XP today',
              value: '+${hydration.xpToday}',
              background: const Color(0xFFD8FAEB),
              darkBackground: const Color(0xFF063327),
              textColor: isDark ? const Color(0xFF6EE7B7) : null,
              borderColor: isDark
                  ? const Color(0xFF34D399).withValues(alpha: 0.25)
                  : null,
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
    this.darkBackground,
    this.textColor,
    this.borderColor,
  });
  final String label;
  final String value;
  final Color background;
  final Color? darkBackground;
  final Color? textColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.liquidColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? (darkBackground ?? colors.surface) : background;
    final textCol =
        textColor ?? (isDark ? colors.aquaHighlight : colors.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: borderColor != null
            ? Border.all(color: borderColor!)
            : (isDark
                ? Border.all(color: colors.glassBorder.withValues(alpha: 0.5))
                : null),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: textCol,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: isDark ? colors.textSecondary : colors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
    final colors = context.liquidColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  Text(
                    'SipSync',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                      color: isDark
                          ? colors.aquaHighlight
                          : const Color(0xFF0D5D68),
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
                      color: isDark
                          ? (isConnected
                              ? const Color(0xFF064E3B)
                              : const Color(0xFF1E293B))
                          : (isConnected
                              ? const Color(0xFFCCFBF1)
                              : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(
                        LiquidTokens.radiusPill,
                      ),
                      border: isDark
                          ? Border.all(
                              color: (isConnected
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF475569))
                                  .withValues(alpha: 0.35),
                              width: 1.0,
                            )
                          : null,
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
                                : (isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8)),
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
                            color: isDark
                                ? (isConnected
                                    ? const Color(0xFF6EE7B7)
                                    : const Color(0xFF94A3B8))
                                : (isConnected
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF64748B)),
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
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? colors.textSecondary
                        : const Color(0xFF64748B),
                    letterSpacing: 0.0,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Right: Dark Mode Toggle Button + Profile Avatar circle
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: isDark ? 'Switch to light mode' : 'Switch to dark mode',
              child: Tooltip(
                message:
                    isDark ? 'Switch to light mode' : 'Switch to dark mode',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('home_dark_mode_button'),
                    borderRadius: BorderRadius.circular(
                      LiquidTokens.radiusPill,
                    ),
                    onTap: () {
                      ref.read(themeModeProvider.notifier).toggle();
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.primary.withValues(alpha: 0.18)
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? colors.aquaHighlight.withValues(alpha: 0.35)
                              : const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_outlined,
                          color: isDark
                              ? colors.aquaHighlight
                              : const Color(0xFF006677),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark
                    ? colors.primary.withValues(alpha: 0.22)
                    : const Color(0xFF006677),
                shape: BoxShape.circle,
                border: isDark
                    ? Border.all(
                        color: colors.aquaHighlight.withValues(alpha: 0.3),
                        width: 1.2,
                      )
                    : null,
              ),
              child: Center(
                child: Icon(
                  Icons.person,
                  color: isDark ? colors.aquaHighlight : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
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
    final colors = context.liquidColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(LiquidTokens.radiusCard),
        border: Border.all(
          color: isDark ? colors.glassBorder : const Color(0xFFF0F1F5),
          width: 1,
        ),
        boxShadow: LiquidTokens.cardShadow(colors),
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
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? colors.textSecondary
                                  : const Color(0xFF64748B),
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      boss.bossName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
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
                  color: isDark
                      ? const Color(0xFF064E3B)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(
                    LiquidTokens.radiusPill,
                  ),
                  border: isDark
                      ? Border.all(
                          color: const Color(0xFF34D399).withValues(alpha: 0.3),
                          width: 1,
                        )
                      : null,
                ),
                child: Text(
                  boss.isComplete ? 'COMPLETE' : '+${boss.lootXp} XP',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF6EE7B7)
                        : const Color(0xFF059669),
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
              Flexible(
                child: Text(
                  'Boss HP damage',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                    letterSpacing: 0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$pctComplete% Complete',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? colors.aquaHighlight
                      : const Color(0xFF0D9488),
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
              backgroundColor: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFEFEDFF),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? colors.aquaHighlight : const Color(0xFF0A6673),
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
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Loot: ${boss.lootName}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
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
