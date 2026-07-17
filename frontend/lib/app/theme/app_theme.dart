import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import '../../shared/theme/app_theme_extensions.dart';

final class AppTheme {
  static const _lightBackground = Color(0xFFF7F8F7);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightPrimary = Color(0xFF176B50);
  static const _lightAccent = Color(0xFF38658A);
  static const _lightText = Color(0xFF151B1E);
  static const _lightOutline = Color(0xFFDDE4E0);
  static const _lightDivider = Color(0xFFE3E7E4);
  static const _lightInputFill = Color(0xFFFAFBF8);
  static const _darkBackground = Color(0xFF060908);
  static const _darkSurface = Color(0xFF111715);
  static const _darkPrimary = Color(0xFF48D597);
  static const _darkAccent = Color(0xFF8AA6B8);
  static const _darkText = Color(0xFFF0F6F2);
  static const _darkOutline = Color(0xFF2A3831);
  static const _darkDivider = Color(0xFF22302A);
  static const _darkInputFill = Color(0xFF151D1A);

  static ThemeData light({ColorScheme? dynamicScheme}) {
    return _buildTheme(
      baseTheme: FlexThemeData.light(
        useMaterial3: true,
        colorScheme: dynamicScheme ?? _lightScheme,
        surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
        blendLevel: 6,
        subThemesData: _subThemes,
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
      ),
      brightness: Brightness.light,
      background: _lightBackground,
      surface: _lightSurface,
      primary: dynamicScheme?.primary ?? _lightPrimary,
      accent: dynamicScheme?.secondary ?? _lightAccent,
      text: dynamicScheme?.onSurface ?? _lightText,
      outline: dynamicScheme?.outlineVariant ?? _lightOutline,
      divider: _lightDivider,
      inputFill: _lightInputFill,
      appBarBackground: _lightBackground,
      semanticColors: const AppSemanticColors(
        success: Color(0xFF168A4D),
        info: Color(0xFF2F6F9F),
        warning: Color(0xFFB66A16),
        danger: Color(0xFFBA3B2F),
        neutral: Color(0xFF6C7A89),
      ),
    );
  }

  static ThemeData dark({ColorScheme? dynamicScheme}) {
    return _buildTheme(
      baseTheme: FlexThemeData.dark(
        useMaterial3: true,
        colorScheme: dynamicScheme ?? _darkScheme,
        surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
        blendLevel: 8,
        subThemesData: _subThemes,
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
      ),
      brightness: Brightness.dark,
      background: _darkBackground,
      surface: _darkSurface,
      primary: dynamicScheme?.primary ?? _darkPrimary,
      accent: dynamicScheme?.secondary ?? _darkAccent,
      text: dynamicScheme?.onSurface ?? _darkText,
      outline: dynamicScheme?.outlineVariant ?? _darkOutline,
      divider: _darkDivider,
      inputFill: _darkInputFill,
      appBarBackground: _darkBackground,
      semanticColors: const AppSemanticColors(
        success: Color(0xFF48D597),
        info: Color(0xFF7BB8D8),
        warning: Color(0xFFF0A744),
        danger: Color(0xFFFF7D72),
        neutral: Color(0xFF91A09A),
      ),
    );
  }

  static const FlexSubThemesData _subThemes = FlexSubThemesData(
    defaultRadius: 8,
    buttonMinSize: Size(44, 44),
    inputDecoratorIsFilled: true,
    inputDecoratorBorderType: FlexInputBorderType.outline,
    popupMenuRadius: 10,
    dialogRadius: 12,
    snackBarRadius: 10,
    tabBarItemSchemeColor: SchemeColor.primary,
  );

  static final ColorScheme _lightScheme =
      ColorScheme.fromSeed(
        seedColor: _lightPrimary,
        brightness: Brightness.light,
      ).copyWith(
        primary: _lightPrimary,
        secondary: _lightAccent,
        surface: _lightSurface,
        onSurface: _lightText,
        outline: _lightOutline,
        outlineVariant: _lightDivider,
      );

  static final ColorScheme _darkScheme =
      ColorScheme.fromSeed(
        seedColor: _darkPrimary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: _darkPrimary,
        secondary: _darkAccent,
        surface: _darkSurface,
        onSurface: _darkText,
        outline: _darkOutline,
        outlineVariant: _darkDivider,
      );

  static ThemeData _buildTheme({
    required ThemeData baseTheme,
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color primary,
    required Color accent,
    required Color text,
    required Color outline,
    required Color divider,
    required Color inputFill,
    required Color appBarBackground,
    required AppSemanticColors semanticColors,
  }) {
    return baseTheme.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      cardColor: surface,
      textTheme: _textTheme(baseTheme.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: text.withValues(alpha: 0.9)),
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: outline),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: baseTheme.colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: text,
          padding: const EdgeInsets.all(9),
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: outline),
        ),
        textStyle: TextStyle(
          color: text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: outline),
        ),
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        contentTextStyle: TextStyle(
          color: text.withValues(alpha: 0.82),
          fontSize: 14,
          height: 1.5,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF213039)
            : const Color(0xFF18252D),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface.withValues(
          alpha: brightness == Brightness.dark ? 0.44 : 0.92,
        ),
        disabledColor: inputFill,
        selectedColor: primary.withValues(
          alpha: brightness == Brightness.dark ? 0.24 : 0.14,
        ),
        secondarySelectedColor: accent.withValues(
          alpha: brightness == Brightness.dark ? 0.2 : 0.12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: TextStyle(
          color: text,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        secondaryLabelStyle: TextStyle(
          color: text,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        brightness: brightness,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: outline),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: primary.withValues(
            alpha: brightness == Brightness.dark ? 0.2 : 0.12,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: primary.withValues(alpha: 0.18)),
        ),
        labelColor: primary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 0,
        ),
        unselectedLabelColor: text.withValues(alpha: 0.62),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0,
        ),
        splashBorderRadius: BorderRadius.circular(8),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(inputFill),
        headingTextStyle: TextStyle(
          color: text.withValues(alpha: 0.72),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        dataTextStyle: TextStyle(
          color: text,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        dividerThickness: 1,
        horizontalMargin: 16,
        columnSpacing: 28,
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      dividerColor: divider,
      extensions: [semanticColors],
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        height: 1.1,
      ),
      displayMedium: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        height: 1.12,
      ),
      displaySmall: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.15,
      ),
      headlineLarge: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      headlineMedium: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      headlineSmall: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.45),
      bodySmall: const TextStyle(fontSize: 12, height: 1.35),
      labelMedium: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelSmall: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );
  }
}
