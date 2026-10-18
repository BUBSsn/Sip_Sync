import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/liquid_theme.dart';
import '../theme/theme_mode_provider.dart';
import '../view_models/hydration_view_model.dart';

/// Shared header geometry; expands naturally with accessibility text scaling.
class SipTabHeader extends StatelessWidget {
  const SipTabHeader({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 88),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    color: context.liquidColors.surface,
    alignment: Alignment.centerLeft,
    child: child,
  );
}

class SipHeaderActions extends ConsumerWidget {
  const SipHeaderActions({super.key, this.darkModeButtonKey});
  final Key? darkModeButtonKey;
  static const circleSize = 48.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.liquidColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          key: darkModeButtonKey,
          tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          style: IconButton.styleFrom(
            backgroundColor: colors.primary.withValues(alpha: 0.08),
            foregroundColor: colors.primary,
            fixedSize: const Size.square(circleSize),
            minimumSize: const Size.square(circleSize),
            maximumSize: const Size.square(circleSize),
            visualDensity: VisualDensity.standard,
            shape: const CircleBorder(),
          ),
          icon: Icon(
            dark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          label: 'User profile',
          image: true,
          child: const CircleAvatar(
            radius: circleSize / 2,
            backgroundColor: Color(0xFF075E6C),
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }
}

/// Shared title styling for every tab, including light and dark appearances.
TextStyle sipHeaderTitleStyle(BuildContext context) => TextStyle(
  fontFamily: LiquidTheme.homeFont,
  fontFamilyFallback: LiquidTheme.homeFontFallback,
  fontSize: 20,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.5,
  color: context.liquidColors.textPrimary,
);

/// Uses saved intake progression so all tabs stay synchronized after each sip.
class SipHeaderXpLabel extends ConsumerWidget {
  const SipHeaderXpLabel({super.key, required this.tabName});
  final String tabName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hydration = ref.watch(hydrationViewModelProvider);
    final progress = hydration.level >= 50
        ? 'MAX XP'
        : '${hydration.currentLevelXp}/${hydration.nextLevelXp} XP';
    return Text(
      '$tabName · [$progress]',
      style: TextStyle(
        fontFamily: LiquidTheme.homeFont,
        fontFamilyFallback: LiquidTheme.homeFontFallback,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: context.liquidColors.textSecondary,
      ),
    );
  }
}
