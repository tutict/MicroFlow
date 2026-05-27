import 'package:flutter/material.dart';

final class AppTheme {
  static ThemeData light() {
    return _buildTheme(
      brightness: Brightness.light,
      background: const Color(0xFFF6F7F5),
      surface: const Color(0xFFFFFFFF),
      primary: const Color(0xFF1F6F5C),
      accent: const Color(0xFF38658A),
      text: const Color(0xFF151B1E),
      outline: const Color(0xFFDDE4E0),
      divider: const Color(0xFFE3E7E4),
      inputFill: const Color(0xFFFAFBF8),
      shadow: const Color(0x0F0F1720),
      appBarBackground: const Color(0xFFF6F7F5),
    );
  }

  static ThemeData dark() {
    return _buildTheme(
      brightness: Brightness.dark,
      background: const Color(0xFF0F1314),
      surface: const Color(0xFF171D1F),
      primary: const Color(0xFF66BBA5),
      accent: const Color(0xFF8AA6B8),
      text: const Color(0xFFE8EEEC),
      outline: const Color(0xFF2D3939),
      divider: const Color(0xFF253130),
      inputFill: const Color(0xFF1C2425),
      shadow: const Color(0x30000000),
      appBarBackground: const Color(0xFF0F1314),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color primary,
    required Color accent,
    required Color text,
    required Color outline,
    required Color divider,
    required Color inputFill,
    required Color shadow,
    required Color appBarBackground,
  }) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          secondary: accent,
          surface: surface,
          onSurface: text,
          outline: outline,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      cardColor: surface,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          height: 0.98,
        ),
        displayMedium: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          height: 1,
        ),
        displaySmall: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          height: 1.02,
        ),
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 15, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45),
        bodySmall: TextStyle(fontSize: 12, height: 1.35),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
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
        shadowColor: shadow,
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
          foregroundColor: Colors.white,
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
          borderRadius: BorderRadius.circular(999),
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
    );
  }
}
