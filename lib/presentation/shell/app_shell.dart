import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import '../theme/liquid_theme.dart';
import '../theme/liquid_tokens.dart';
import '../../data/wifi/wifi_coaster_repository.dart';
import '../view_models/hydration_view_model.dart';
import '../widgets/raid_badges.dart';

/// App navigation shell featuring a 3-tab bottom bar matching the visual reference:
/// - Full-height blue active tab indicator block
/// - Preserved tab states via [IndexedStack]
/// - Embedded debug hardware simulator panel (excluded in release builds)
/// - Automatic calendar day rollover detection via lifecycle resume and midnight timer
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _midnightTimer;

  static const List<Widget> _screens = [
    HomeScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final repository = ref.read(coasterRepositoryProvider);
      if (repository is WifiCoasterRepository) repository.connect();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDayRollover();
      final repository = ref.read(coasterRepositoryProvider);
      if (repository is WifiCoasterRepository) repository.reconnect();
    }
  }

  void _checkDayRollover([DateTime? customNow]) {
    // Always refresh on resume: DateTime objects can change their displayed
    // local date when the OS timezone changes, hiding a date transition.
    ref
        .read(historyRepositoryProvider)
        .checkDayRolloverTrigger(customNow ?? DateTime.now())
        .catchError((Object _) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not refresh daily history. Please reopen the app to retry.',
                ),
              ),
            );
          }
        });
    _scheduleMidnightTimer();
  }

  void _scheduleMidnightTimer() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final duration = tomorrow.difference(now);

    _midnightTimer = Timer(duration, () {
      _checkDayRollover();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark
        ? LiquidTokens.darkColors
        : (_currentIndex == 0
            ? LiquidTokens.homeColors
            : context.liquidColors);
    ref.listen(hydrationViewModelProvider, (previous, next) {
      if (previous == null) return;
      int defeated(BossRaidStatus raid) =>
          raid.act - 1 + (raid.isComplete ? 1 : 0);
      final before = defeated(previous.bossRaid);
      final after = defeated(next.bossRaid);
      for (var index = before; index < after; index++) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Row(
              children: [
                RaidBadge(index: index, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Boss defeated! ${BossRaidStatus.badgeNames[index]} badge earned. View it in Settings.',
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: palette.background,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        height: 64,
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(
            top: BorderSide(
              color: palette.glassBorder.withValues(alpha: 0.4),
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildTabItem(
              index: 0,
              icon: Icons.water_drop_outlined,
              activeIcon: Icons.water_drop_outlined,
              label: 'HOME',
              palette: palette,
              isDark: isDark,
            ),
            _buildTabItem(
              index: 1,
              icon: Icons.insights_rounded,
              activeIcon: Icons.insights_rounded,
              label: 'HISTORY',
              palette: palette,
              isDark: isDark,
            ),
            _buildTabItem(
              index: 2,
              icon: Icons.tune_rounded,
              activeIcon: Icons.tune_rounded,
              label: 'SETTINGS',
              palette: palette,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required dynamic palette,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;
    final activeColor = isDark ? palette.aquaHighlight as Color : const Color(0xFF0A6673);
    final inactiveColor = isDark ? palette.textSecondary as Color : const Color(0xFF64748B);
    final activePillColor = isDark
        ? (palette.primary as Color).withValues(alpha: 0.22)
        : const Color(0xFFCCFBF1);

    return Expanded(
      child: Semantics(
        selected: isSelected,
        label: '$label Tab',
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (_currentIndex != index) {
                setState(() => _currentIndex = index);
              }
            },
            child: SizedBox(
              height: 64, // Guarantees >= 48dp tap target
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: activePillColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(activeIcon, color: activeColor, size: 20),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Icon(icon, color: inactiveColor, size: 22),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontFamily: LiquidTheme.homeFont,
                          fontFamilyFallback: LiquidTheme.homeFontFallback,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          letterSpacing: 0.1,
                          color: isSelected ? activeColor : inactiveColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
