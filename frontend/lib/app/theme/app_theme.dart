import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_contrast.dart';
import '../../shared/theme/app_tokens.dart';

abstract final class AppTypography {
  static const family = 'Segoe UI';
  static const fallback = <String>[
    'Microsoft YaHei UI',
    'PingFang SC',
    'Noto Sans CJK SC',
    'Noto Sans SC',
    'Roboto',
  ];

  static TextStyle style({
    required double size,
    required FontWeight weight,
    required double height,
  }) {
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: 0,
    );
  }
}

final class AppTheme {
  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static const FlexSubThemesData _subThemes = FlexSubThemesData(
    defaultRadius: AppRadii.medium,
    buttonMinSize: Size(44, 44),
    inputDecoratorIsFilled: true,
    inputDecoratorBorderType: FlexInputBorderType.outline,
    popupMenuRadius: AppRadii.medium,
    dialogRadius: AppRadii.dialog,
    snackBarRadius: AppRadii.medium,
    tabBarItemSchemeColor: SchemeColor.primary,
  );

  static ThemeData _build(AppPaletteData palette, Brightness brightness) {
    final scheme = _scheme(palette, brightness);
    final base = brightness == Brightness.light
        ? FlexThemeData.light(
            useMaterial3: true,
            colorScheme: scheme,
            surfaceMode: FlexSurfaceMode.level,
            blendLevel: 0,
            subThemesData: _subThemes,
            visualDensity: VisualDensity.standard,
          )
        : FlexThemeData.dark(
            useMaterial3: true,
            colorScheme: scheme,
            surfaceMode: FlexSurfaceMode.level,
            blendLevel: 0,
            subThemesData: _subThemes,
            visualDensity: VisualDensity.standard,
          );
    final text = _textTheme(base.textTheme);
    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.medium),
      borderSide: BorderSide(color: palette.brand, width: 2),
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.canvas,
      disabledColor: palette.textTertiary,
      focusColor: palette.brand,
      textTheme: text,
      primaryTextTheme: text,
      iconTheme: IconThemeData(color: palette.text, size: 20),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 56,
        iconTheme: IconThemeData(color: palette.text, size: 20),
        titleTextStyle: text.titleMedium,
      ),
      cardTheme: CardThemeData(
        color: palette.canvas,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          side: BorderSide(color: palette.divider),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.canvas,
        elevation: 4,
        shadowColor: const Color(0x14000000),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: palette.textSecondary,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.canvas,
        elevation: 4,
        shadowColor: const Color(0x14000000),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          side: BorderSide(color: palette.divider),
        ),
        textStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.snackbarBackground,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: palette.snackbarText,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: 1,
        space: 1,
      ),
      dividerColor: palette.divider,
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          iconSize: 20,
          foregroundColor: palette.text,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          backgroundColor: palette.brand,
          foregroundColor: palette.onBrand,
          textStyle: text.labelMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: palette.text,
          textStyle: text.labelMedium,
          side: BorderSide(color: palette.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: palette.brand,
          textStyle: text.labelMedium,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputFill,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        labelStyle: text.bodySmall?.copyWith(color: palette.textSecondary),
        hintStyle: text.bodySmall?.copyWith(color: palette.textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: palette.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: palette.outline),
        ),
        focusedBorder: focusBorder,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: palette.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: palette.danger, width: 2),
        ),
      ),
      extensions: [palette.semanticColors],
    );
  }

  static ColorScheme _scheme(AppPaletteData palette, Brightness brightness) {
    return ColorScheme(
      brightness: brightness,
      primary: palette.brand,
      onPrimary: palette.onBrand,
      primaryContainer: palette.selectedOverlay,
      onPrimaryContainer: palette.text,
      secondary: palette.info,
      onSecondary: brightness == Brightness.light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF151B1E),
      secondaryContainer: palette.infoContainer,
      onSecondaryContainer: palette.info,
      tertiary: palette.agent,
      onTertiary: brightness == Brightness.light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF151B1E),
      tertiaryContainer: blendOn(
        palette.agent,
        palette.canvas,
        palette.containerAlpha,
      ),
      onTertiaryContainer: palette.agent,
      error: palette.danger,
      onError: brightness == Brightness.light
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF151B1E),
      errorContainer: palette.dangerContainer,
      onErrorContainer: palette.danger,
      surface: palette.canvas,
      onSurface: palette.text,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.outline,
      outlineVariant: palette.divider,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
      inverseSurface: brightness == Brightness.light
          ? AppPalette.dark.canvas
          : AppPalette.light.canvas,
      onInverseSurface: brightness == Brightness.light
          ? AppPalette.dark.text
          : AppPalette.light.text,
      inversePrimary: brightness == Brightness.light
          ? AppPalette.dark.brand
          : AppPalette.light.brand,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: palette.inputFill,
      surfaceContainerLow: palette.mutedSurface,
      surfaceContainer: palette.canvas,
      surfaceContainerHigh: palette.elevated,
      surfaceContainerHighest: palette.mutedSurface,
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: AppTypography.style(
        size: 20,
        weight: FontWeight.w600,
        height: 1.25,
      ),
      displayMedium: AppTypography.style(
        size: 20,
        weight: FontWeight.w600,
        height: 1.25,
      ),
      displaySmall: AppTypography.style(
        size: 20,
        weight: FontWeight.w600,
        height: 1.25,
      ),
      headlineLarge: AppTypography.style(
        size: 20,
        weight: FontWeight.w600,
        height: 1.25,
      ),
      headlineMedium: AppTypography.style(
        size: 20,
        weight: FontWeight.w600,
        height: 1.25,
      ),
      headlineSmall: AppTypography.style(
        size: 20,
        weight: FontWeight.w600,
        height: 1.25,
      ),
      titleLarge: AppTypography.style(
        size: 20,
        weight: FontWeight.w600,
        height: 1.25,
      ),
      titleMedium: AppTypography.style(
        size: 16,
        weight: FontWeight.w600,
        height: 1.25,
      ),
      titleSmall: AppTypography.style(
        size: 16,
        weight: FontWeight.w600,
        height: 1.25,
      ),
      bodyLarge: AppTypography.style(
        size: 15,
        weight: FontWeight.w400,
        height: 1.6,
      ),
      bodyMedium: AppTypography.style(
        size: 15,
        weight: FontWeight.w400,
        height: 1.6,
      ),
      bodySmall: AppTypography.style(
        size: 13,
        weight: FontWeight.w400,
        height: 1.35,
      ),
      labelLarge: AppTypography.style(
        size: 12,
        weight: FontWeight.w600,
        height: 1.35,
      ),
      labelMedium: AppTypography.style(
        size: 12,
        weight: FontWeight.w600,
        height: 1.35,
      ),
      labelSmall: AppTypography.style(
        size: 12,
        weight: FontWeight.w600,
        height: 1.35,
      ),
    );
  }
}
