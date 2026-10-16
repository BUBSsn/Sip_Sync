import 'package:flutter/material.dart';

import 'liquid_tokens.dart';

/// Extension allowing widgets to access the active [LiquidColorPalette]
/// directly from [ThemeData] via `context.liquidColors`.
class LiquidThemeExtension extends ThemeExtension<LiquidThemeExtension> {
  const LiquidThemeExtension({required this.palette});

  final LiquidColorPalette palette;

  @override
  ThemeExtension<LiquidThemeExtension> copyWith({LiquidColorPalette? palette}) {
    return LiquidThemeExtension(palette: palette ?? this.palette);
  }

  @override
  ThemeExtension<LiquidThemeExtension> lerp(
    covariant ThemeExtension<LiquidThemeExtension>? other,
    double t,
  ) {
    if (other is! LiquidThemeExtension) return this;
    // Keep discrete or discrete-switched palette during animations
    return t < 0.5 ? this : other;
  }
}

/// Helper extension on [BuildContext] for ergonomic token access.
extension LiquidContext on BuildContext {
  LiquidColorPalette get liquidColors =>
      Theme.of(this).extension<LiquidThemeExtension>()?.palette ??
      LiquidTokens.lightColors;
}

/// ThemeData generator for SipSync.
class LiquidTheme {
  LiquidTheme._();

  /// Light theme data.
  static ThemeData get light => _buildTheme(
    brightness: Brightness.light,
    palette: LiquidTokens.lightColors,
  );

  /// Dark (deep-water) theme data.
  static ThemeData get dark => _buildTheme(
    brightness: Brightness.dark,
    palette: LiquidTokens.darkColors,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required LiquidColorPalette palette,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      secondary: palette.aquaHighlight,
      onSecondary: palette.textPrimary,
      error: palette.error,
      onError: Colors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      cardColor: palette.surface,
      fontFamily: 'Roboto',
      extensions: [LiquidThemeExtension(palette: palette)],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.onPrimary,
        unselectedItemColor: palette.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
