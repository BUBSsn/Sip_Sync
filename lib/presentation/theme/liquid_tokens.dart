import 'package:flutter/material.dart';

import '../../domain/domain.dart';

/// Design tokens for SipSync, serving as the single source of truth for
/// colors, typography, gradients, radii, spacing, durations, and curves.
class LiquidTokens {
  LiquidTokens._();

  // --- Palette Definitions ---
  static const homeColors = LiquidColorPalette(
    background: Color(0xFFF8F8FC),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF006B7C),
    onPrimary: Color(0xFFFFFFFF),
    waterShallow: Color(0xFF53D6EB),
    waterMid: Color(0xFF08B8D1),
    waterDeep: Color(0xFF006B7C),
    aquaHighlight: Color(0xFF009DBB),
    glassFill: Color(0xFFFFFFFF),
    glassBorder: Color(0xFFF0F1F5),
    glassInnerHighlight: Color(0x80FFFFFF),
    textPrimary: Color(0xFF1D2533),
    textSecondary: Color(0xFF717985),
    goalSealGlow: Color(0xFF009DBB),
    dryState: Color(0xFF94A3B8),
    fadedState: Color(0xFF64B5F6),
    error: Color(0xFFE53935),
    cardFallback: Color(0xFFFFFFFF),
    comboGreen: Color(0xFF00C48C),
    bossViolet: Color(0xFF7C3AED),
  );

  static const lightColors = LiquidColorPalette(
    background: Color(0xFFF4F8FB),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF0277BD),
    onPrimary: Color(0xFFFFFFFF),
    waterShallow: Color(0xFFB3E5FC),
    waterMid: Color(0xFF29B6F6),
    waterDeep: Color(0xFF0277BD),
    aquaHighlight: Color(0xFF00E5FF),
    glassFill: Color(0xCCFFFFFF),
    glassBorder: Color(0x260277BD),
    glassInnerHighlight: Color(0x80FFFFFF),
    textPrimary: Color(0xFF142334),
    textSecondary: Color(0xFF627588),
    goalSealGlow: Color(0xFF00E5FF),
    dryState: Color(0xFF94A3B8),
    fadedState: Color(0xFF64B5F6),
    error: Color(0xFFE53935),
    cardFallback: Color(0xFFFFFFFF),
    comboGreen: Color(0xFF00C48C),
    bossViolet: Color(0xFF7C3AED),
  );

  static const darkColors = LiquidColorPalette(
    background: Color(0xFF0A111A),
    surface: Color(0xFF131F2E),
    primary: Color(0xFF29B6F6),
    onPrimary: Color(0xFF0A111A),
    waterShallow: Color(0xFF1976D2),
    waterMid: Color(0xFF0288D1),
    waterDeep: Color(0xFF01579B),
    aquaHighlight: Color(0xFF00E5FF),
    glassFill: Color(0xB3131F2E),
    glassBorder: Color(0x33FFFFFF),
    glassInnerHighlight: Color(0x26FFFFFF),
    textPrimary: Color(0xFFE6F2F8),
    textSecondary: Color(0xFF88A0B8),
    goalSealGlow: Color(0xFF00E5FF),
    dryState: Color(0xFF64748B),
    fadedState: Color(0xFF42A5F5),
    error: Color(0xFFEF5350),
    cardFallback: Color(0xFF131F2E),
    comboGreen: Color(0xFF00C48C),
    bossViolet: Color(0xFF7C3AED),
  );

  // --- Radii ---
  static const double radiusXs = 6.0;
  static const double radiusSm = 10.0;
  static const double radiusChip = 12.0;
  static const double radiusButton = 16.0;
  static const double radiusBadge = 20.0;
  static const double radiusCard = 24.0;
  static const double radiusLg = 24.0;
  static const double radiusSheet = 28.0;
  static const double radiusXl = 28.0;
  static const double radiusPill = 999.0;

  // --- Spacing ---
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;
  static const double spaceXxl = 40.0;

  // --- Durations ---
  static const Duration durationMicro = Duration(milliseconds: 150);
  static const Duration durationShort = Duration(milliseconds: 300);
  static const Duration durationMedium = Duration(milliseconds: 500);
  static const Duration durationNormal = Duration(milliseconds: 500);
  static const Duration durationLong = Duration(milliseconds: 800);
  static const Duration durationSipFeedback = Duration(milliseconds: 1200);
  static const Duration durationTareMeasure = Duration(milliseconds: 1500);
  static const Duration durationThirstQuenched = Duration(seconds: 3);

  // --- Curves ---
  static const Curve curveStandard = Curves.easeInOutCubic;
  static const Curve curveElastic = Curves.elasticOut;
  static const Curve curveSettle = Curves.easeOutBack;
  static const Curve curveOvershoot = Curves.easeOutBack;

  // --- Gradients ---
  static LinearGradient waterDepthGradient(LiquidColorPalette palette) =>
      LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.waterShallow, palette.waterMid, palette.waterDeep],
      );

  static LinearGradient glassSheenGradient(LiquidColorPalette palette) =>
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.glassInnerHighlight, palette.glassFill],
      );

  static RadialGradient goalSealGlowGradient(LiquidColorPalette palette) =>
      RadialGradient(
        colors: [
          palette.goalSealGlow.withValues(alpha: 0.6),
          palette.goalSealGlow.withValues(alpha: 0.0),
        ],
      );

  // --- Shadows ---
  static List<BoxShadow> cardShadow(LiquidColorPalette palette) => [
    BoxShadow(
      color: palette.primary.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> glowShadow(Color glowColor) => [
    BoxShadow(
      color: glowColor.withValues(alpha: 0.4),
      blurRadius: 12,
      spreadRadius: 2,
    ),
  ];

  // --- Re-exported Domain Single-Sources of Truth ---
  static const int minDailyGoalMl = UserSettings.minDailyGoalMl;
  static const int maxDailyGoalMl = UserSettings.maxDailyGoalMl;
  static const int defaultDailyGoalMl = UserSettings.defaultDailyGoalMl;
  static const int defaultInactivityThresholdMinutes =
      UserSettings.defaultInactivityThresholdMinutes;
  static const int minPortionLimitMl = UserSettings.minPortionLimitMl;
  static const int maxPortionLimitMl = UserSettings.maxPortionLimitMl;
  static const int defaultPortionLimitMl = UserSettings.defaultPortionLimitMl;
}

/// Immutable collection of semantic colors for a theme mode.
@immutable
class LiquidColorPalette {
  const LiquidColorPalette({
    required this.background,
    required this.surface,
    required this.primary,
    required this.onPrimary,
    required this.waterShallow,
    required this.waterMid,
    required this.waterDeep,
    required this.aquaHighlight,
    required this.glassFill,
    required this.glassBorder,
    required this.glassInnerHighlight,
    required this.textPrimary,
    required this.textSecondary,
    required this.goalSealGlow,
    required this.dryState,
    required this.fadedState,
    required this.error,
    required this.cardFallback,
    required this.comboGreen,
    required this.bossViolet,
  });

  final Color background;
  final Color surface;
  final Color primary;
  final Color onPrimary;
  final Color waterShallow;
  final Color waterMid;
  final Color waterDeep;
  final Color aquaHighlight;
  final Color glassFill;
  final Color glassBorder;
  final Color glassInnerHighlight;
  final Color textPrimary;
  final Color textSecondary;
  final Color goalSealGlow;
  final Color dryState;
  final Color fadedState;
  final Color error;
  final Color cardFallback;
  final Color comboGreen;
  final Color bossViolet;
}
