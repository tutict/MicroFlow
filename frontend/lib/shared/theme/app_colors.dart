import 'package:flutter/material.dart';

import 'app_contrast.dart';
import 'app_theme_extensions.dart';

@immutable
final class AppPaletteData {
  const AppPaletteData({
    required this.name,
    required this.background,
    required this.canvas,
    required this.mutedSurface,
    required this.inputFill,
    required this.elevated,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.outline,
    required this.brand,
    required this.onBrand,
    required this.success,
    required this.info,
    required this.warning,
    required this.danger,
    required this.neutral,
    required this.agent,
    required this.containerAlpha,
    required this.selectedAlpha,
    required this.snackbarBackground,
    required this.snackbarText,
  });

  final String name;
  final Color background;
  final Color canvas;
  final Color mutedSurface;
  final Color inputFill;
  final Color elevated;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;
  final Color outline;
  final Color brand;
  final Color onBrand;
  final Color success;
  final Color info;
  final Color warning;
  final Color danger;
  final Color neutral;
  final Color agent;
  final double containerAlpha;
  final double selectedAlpha;
  final Color snackbarBackground;
  final Color snackbarText;

  Color get channel => info;
  Color get directMessage => brand;
  Color get successContainer => blendOn(success, canvas, containerAlpha);
  Color get infoContainer => blendOn(info, canvas, containerAlpha);
  Color get warningContainer => blendOn(warning, canvas, containerAlpha);
  Color get dangerContainer => blendOn(danger, canvas, containerAlpha);
  Color get neutralContainer => blendOn(neutral, canvas, containerAlpha);
  Color get selectedOverlay => blendOn(brand, canvas, selectedAlpha);

  AppSemanticColors get semanticColors => AppSemanticColors(
    success: success,
    info: info,
    warning: warning,
    danger: danger,
    neutral: neutral,
    successContainer: successContainer,
    infoContainer: infoContainer,
    warningContainer: warningContainer,
    dangerContainer: dangerContainer,
    neutralContainer: neutralContainer,
    channel: channel,
    directMessage: directMessage,
    agentThread: agent,
    selectedOverlay: selectedOverlay,
    mutedSurface: mutedSurface,
    focus: brand,
  );

  List<ContrastPair> get contrastPairs {
    final surfaces = <(String, Color)>[
      ('canvas', canvas),
      ('background', background),
      ('muted', mutedSurface),
      ('input', inputFill),
    ];
    final pairs = <ContrastPair>[];
    void addText(String role, Color foreground) {
      for (final surface in surfaces) {
        pairs.add(
          ContrastPair(
            name: '$name $role on ${surface.$1}',
            foreground: foreground,
            background: surface.$2,
            minimum: 4.5,
          ),
        );
      }
    }

    addText('text', text);
    addText('secondary', textSecondary);
    addText('disabled', textTertiary);
    pairs.add(
      ContrastPair(
        name: '$name brand fill',
        foreground: onBrand,
        background: brand,
        minimum: 4.5,
      ),
    );
    for (final entry in <(String, Color, Color)>[
      ('success', success, successContainer),
      ('info', info, infoContainer),
      ('warning', warning, warningContainer),
      ('danger', danger, dangerContainer),
      ('neutral', neutral, neutralContainer),
      ('agent', agent, canvas),
    ]) {
      pairs.add(
        ContrastPair(
          name: '$name ${entry.$1} on canvas',
          foreground: entry.$2,
          background: canvas,
          minimum: 4.5,
        ),
      );
      if (entry.$1 != 'agent') {
        pairs.add(
          ContrastPair(
            name: '$name ${entry.$1} on container',
            foreground: entry.$2,
            background: entry.$3,
            minimum: 4.5,
          ),
        );
      }
    }
    for (final surface in surfaces) {
      pairs.add(
        ContrastPair(
          name: '$name outline on ${surface.$1}',
          foreground: outline,
          background: surface.$2,
          minimum: 3,
        ),
      );
      pairs.add(
        ContrastPair(
          name: '$name focus on ${surface.$1}',
          foreground: brand,
          background: surface.$2,
          minimum: 3,
        ),
      );
    }
    pairs.add(
      ContrastPair(
        name: '$name text on selected',
        foreground: text,
        background: selectedOverlay,
        minimum: 4.5,
      ),
    );
    pairs.add(
      ContrastPair(
        name: '$name snackbar',
        foreground: snackbarText,
        background: snackbarBackground,
        minimum: 4.5,
      ),
    );
    return pairs;
  }
}

abstract final class AppPalette {
  static const light = AppPaletteData(
    name: 'light',
    background: Color(0xFFF4F7F5),
    canvas: Color(0xFFFFFFFF),
    mutedSurface: Color(0xFFEEF3F0),
    inputFill: Color(0xFFF7FAF8),
    elevated: Color(0xFFFFFFFF),
    text: Color(0xFF151B1E),
    textSecondary: Color(0xFF3E4A46),
    textTertiary: Color(0xFF52605A),
    divider: Color(0xFFE1E8E4),
    outline: Color(0xFF6E7F76),
    brand: Color(0xFF0F6A52),
    onBrand: Color(0xFFFFFFFF),
    success: Color(0xFF3F6B12),
    info: Color(0xFF1F5F8A),
    warning: Color(0xFF8A4B00),
    danger: Color(0xFF9E2B24),
    neutral: Color(0xFF5C6B66),
    agent: Color(0xFF804620),
    containerAlpha: 0.10,
    selectedAlpha: 0.12,
    snackbarBackground: Color(0xFF232C28),
    snackbarText: Color(0xFFE7F1EC),
  );

  static const dark = AppPaletteData(
    name: 'dark',
    background: Color(0xFF121916),
    canvas: Color(0xFF1B2420),
    mutedSurface: Color(0xFF232C28),
    inputFill: Color(0xFF202824),
    elevated: Color(0xFF232C28),
    text: Color(0xFFE7F1EC),
    textSecondary: Color(0xFFC3D0CA),
    textTertiary: Color(0xFF9FADA7),
    divider: Color(0xFF2C3833),
    outline: Color(0xFF8FA099),
    brand: Color(0xFF8EDDC0),
    onBrand: Color(0xFF06281C),
    success: Color(0xFFD5EC9A),
    info: Color(0xFFB7D7F2),
    warning: Color(0xFFF3D19A),
    danger: Color(0xFFFFC2BA),
    neutral: Color(0xFFC5D1CC),
    agent: Color(0xFFEBB998),
    containerAlpha: 0.16,
    selectedAlpha: 0.18,
    snackbarBackground: Color(0xFF232C28),
    snackbarText: Color(0xFFE7F1EC),
  );
}
