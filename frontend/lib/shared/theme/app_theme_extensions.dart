import 'package:flutter/material.dart';

@immutable
final class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.info,
    required this.warning,
    required this.danger,
    required this.neutral,
  });

  final Color success;
  final Color info;
  final Color warning;
  final Color danger;
  final Color neutral;

  static AppSemanticColors of(BuildContext context) {
    return Theme.of(context).extension<AppSemanticColors>()!;
  }

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? info,
    Color? warning,
    Color? danger,
    Color? neutral,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      info: info ?? this.info,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) {
      return this;
    }
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
    );
  }
}
