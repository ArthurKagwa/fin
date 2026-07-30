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
  static const caution = Color(0xFFB8860B);
}

const editorialShadow = BoxShadow(
  color: Color(0x142b2927),
  blurRadius: 30,
  offset: Offset(0, 8),
);

ThemeData buildAppTheme() {
  final colorScheme = const ColorScheme(
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
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.headlineMedium,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceContainerLowest,
      indicatorColor: AppColors.secondaryContainer.withValues(alpha: 0.5),
      labelTextStyle: WidgetStatePropertyAll(
        textTheme.labelMedium?.copyWith(letterSpacing: 0),
      ),
    ),
  );
}
