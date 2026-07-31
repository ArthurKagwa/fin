import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const primary = Color(0xFFa53b26);
  static const onPrimary = Color(0xFFffffff);
  static const primaryContainer = Color(0xFFc25139);
  static const onPrimaryContainer = Color(0xFFfffbff);
  static const primaryFixed = Color(0xFFffdad3);
  static const primaryFixedDim = Color(0xFFffb4a4);
  static const secondary = Color(0xFF376847);
  static const onSecondary = Color(0xFFffffff);
  static const secondaryContainer = Color(0xFFb6edc2);
  static const onSecondaryContainer = Color(0xFF3b6d4b);
  static const secondaryFixed = Color(0xFFb9efc5);
  static const onSecondaryFixed = Color(0xFF00210e);
  static const tertiary = Color(0xFF78746e);
  static const onTertiary = Color(0xFFffffff);
  static const tertiaryContainer = Color(0xFF78746e);
  static const tertiaryFixedDim = Color(0xFFccc5bf);
  static const onTertiaryFixed = Color(0xFF1e1b17);
  static const onTertiaryFixedVariant = Color(0xFF4a4641);
  static const surface = Color(0xFFfef8f5);
  static const onSurface = Color(0xFF1d1b19);
  static const onSurfaceVariant = Color(0xFF57423d);
  static const surfaceContainerLowest = Color(0xFFfef8f5);
  static const surfaceContainerLow = Color(0xFFf8f2ef);
  static const surfaceContainer = Color(0xFFf2ede9);
  static const surfaceContainerHigh = Color(0xFFede7e4);
  static const surfaceContainerHighest = Color(0xFFe7e1de);
  static const surfaceDim = Color(0xFFded9d6);
  static const surfaceBright = Color(0xFFfef8f5);
  static const surfaceTint = Color(0xFFa53b26);
  static const outline = Color(0xFF8b716c);
  static const error = Color(0xFFba1a1a);
  static const onError = Color(0xFFffffff);
  static const errorContainer = Color(0xFFffdad6);
  static const onErrorContainer = Color(0xFF93000a);
  static const background = Color(0xFFfef8f5);
  static const onBackground = Color(0xFF1d1b19);

  /// Drifting off pace but not yet off plan. Deliberately not [error] — a
  /// month that is merely running fast is a fact to notice, not a failure.
  /// One value for both themes: it already reads clearly against a dark
  /// surface, and it isn't part of the M3 [ColorScheme] this file otherwise
  /// mirrors light/dark for.
  static const caution = Color(0xFFB8860B);
}

/// The dark counterpart to [AppColors] — same M3 roles, same brand hues
/// (terracotta primary, green secondary), lightened/darkened per Material 3's
/// dark-theme convention rather than just inverting light values naively.
abstract final class _AppDarkColors {
  static const primary = Color(0xFFffb4a4); // AppColors.primaryFixedDim
  static const onPrimary = Color(0xFF5c1608);
  static const primaryContainer = Color(0xFF7d2a17);
  static const onPrimaryContainer = Color(0xFFffdad3); // AppColors.primaryFixed
  static const secondary = Color(0xFF9bd1a8);
  static const onSecondary = Color(0xFF04391c);
  static const secondaryContainer = Color(0xFF1f4e2f);
  static const onSecondaryContainer = Color(0xFFb6edc2);
  static const tertiary = Color(0xFFccc5bf); // AppColors.tertiaryFixedDim
  static const onTertiary = Color(0xFF322f2a);
  static const tertiaryContainer = Color(0xFF4a4641);
  static const onTertiaryContainer = Color(0xFFe4e1db);
  static const surface = Color(0xFF15130f);
  static const onSurface = Color(0xFFe7e1de); // AppColors.surfaceContainerHighest
  static const onSurfaceVariant = Color(0xFFd6c2bc);
  static const surfaceContainerLowest = Color(0xFF0f0d0a);
  static const surfaceContainerLow = Color(0xFF1d1b19); // AppColors.onSurface
  static const surfaceContainer = Color(0xFF211f1c);
  static const surfaceContainerHigh = Color(0xFF2b2824);
  static const surfaceContainerHighest = Color(0xFF363330);
  static const surfaceDim = Color(0xFF15130f);
  static const surfaceBright = Color(0xFF3c3835);
  static const outline = Color(0xFFa08c86);
  static const error = Color(0xFFffb4ab);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000a);
  static const onErrorContainer = Color(0xFFffdad6);
}

const editorialShadow = BoxShadow(
  color: Color(0x142b2927),
  blurRadius: 30,
  offset: Offset(0, 8),
);

ThemeData buildAppTheme([Brightness brightness = Brightness.light]) {
  final isDark = brightness == Brightness.dark;

  final colorScheme = isDark
      ? const ColorScheme(
          brightness: Brightness.dark,
          primary: _AppDarkColors.primary,
          onPrimary: _AppDarkColors.onPrimary,
          primaryContainer: _AppDarkColors.primaryContainer,
          onPrimaryContainer: _AppDarkColors.onPrimaryContainer,
          secondary: _AppDarkColors.secondary,
          onSecondary: _AppDarkColors.onSecondary,
          secondaryContainer: _AppDarkColors.secondaryContainer,
          onSecondaryContainer: _AppDarkColors.onSecondaryContainer,
          tertiary: _AppDarkColors.tertiary,
          onTertiary: _AppDarkColors.onTertiary,
          tertiaryContainer: _AppDarkColors.tertiaryContainer,
          onTertiaryContainer: _AppDarkColors.onTertiaryContainer,
          surface: _AppDarkColors.surface,
          onSurface: _AppDarkColors.onSurface,
          onSurfaceVariant: _AppDarkColors.onSurfaceVariant,
          outline: _AppDarkColors.outline,
          error: _AppDarkColors.error,
          onError: _AppDarkColors.onError,
          errorContainer: _AppDarkColors.errorContainer,
          onErrorContainer: _AppDarkColors.onErrorContainer,
          surfaceContainerLowest: _AppDarkColors.surfaceContainerLowest,
          surfaceContainerLow: _AppDarkColors.surfaceContainerLow,
          surfaceContainer: _AppDarkColors.surfaceContainer,
          surfaceContainerHigh: _AppDarkColors.surfaceContainerHigh,
          surfaceContainerHighest: _AppDarkColors.surfaceContainerHighest,
          surfaceDim: _AppDarkColors.surfaceDim,
          surfaceBright: _AppDarkColors.surfaceBright,
          surfaceTint: _AppDarkColors.primary,
        )
      : const ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.onPrimaryContainer,
          secondary: AppColors.secondary,
          onSecondary: AppColors.onSecondary,
          secondaryContainer: AppColors.secondaryContainer,
          onSecondaryContainer: AppColors.onSecondaryContainer,
          tertiary: AppColors.tertiary,
          onTertiary: AppColors.onTertiary,
          tertiaryContainer: AppColors.tertiaryContainer,
          onTertiaryContainer: AppColors.onTertiary,
          surface: AppColors.surface,
          onSurface: AppColors.onSurface,
          onSurfaceVariant: AppColors.onSurfaceVariant,
          outline: AppColors.outline,
          error: AppColors.error,
          onError: AppColors.onError,
          errorContainer: AppColors.errorContainer,
          onErrorContainer: AppColors.onErrorContainer,
          surfaceContainerLowest: AppColors.surfaceContainerLowest,
          surfaceContainerLow: AppColors.surfaceContainerLow,
          surfaceContainer: AppColors.surfaceContainer,
          surfaceContainerHigh: AppColors.surfaceContainerHigh,
          surfaceContainerHighest: AppColors.surfaceContainerHighest,
          surfaceDim: AppColors.surfaceDim,
          surfaceBright: AppColors.surfaceBright,
          surfaceTint: AppColors.surfaceTint,
        );

  final textTheme = GoogleFonts.dmSansTextTheme().copyWith(
    displayLarge: GoogleFonts.playfairDisplay(
      fontSize: 48,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.02 * 48,
      height: 1.1,
    ),
    displayMedium: GoogleFonts.playfairDisplay(
      fontSize: 40,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.02 * 40,
      height: 1.1,
    ),
    displaySmall: GoogleFonts.playfairDisplay(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    headlineLarge: GoogleFonts.playfairDisplay(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    headlineMedium: GoogleFonts.playfairDisplay(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    headlineSmall: GoogleFonts.playfairDisplay(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    titleLarge: GoogleFonts.dmSans(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.01 * 24,
    ),
    titleMedium: GoogleFonts.dmSans(
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: GoogleFonts.dmSans(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.05 * 14,
    ),
    bodyLarge: GoogleFonts.dmSans(fontSize: 18, height: 1.6),
    bodyMedium: GoogleFonts.dmSans(fontSize: 16, height: 1.6),
    bodySmall: GoogleFonts.dmSans(fontSize: 14, height: 1.4),
    labelLarge: GoogleFonts.dmSans(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.05 * 14,
    ),
    labelMedium: GoogleFonts.dmSans(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.05 * 12,
    ),
    labelSmall: GoogleFonts.dmSans(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.05 * 11,
    ),
  ).apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.headlineMedium,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: isDark ? BorderSide(color: colorScheme.outline.withValues(alpha: 0.15)) : BorderSide.none,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.primary),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surfaceContainerLowest,
      indicatorColor: colorScheme.secondaryContainer.withValues(alpha: 0.5),
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelMedium?.copyWith(letterSpacing: 0),
      ),
    ),
  );
}
