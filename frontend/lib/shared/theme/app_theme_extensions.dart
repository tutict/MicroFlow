import 'package:flutter/material.dart';

@immutable
final class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.info,
    required this.warning,
    required this.danger,
    required this.neutral,
    required this.successContainer,
    required this.infoContainer,
    required this.warningContainer,
    required this.dangerContainer,
    required this.neutralContainer,
    required this.channel,
    required this.directMessage,
    required this.agentThread,
    required this.selectedOverlay,
    required this.mutedSurface,
    required this.focus,
  });

  final Color success;
  final Color info;
  final Color warning;
  final Color danger;
  final Color neutral;
  final Color successContainer;
  final Color infoContainer;
  final Color warningContainer;
  final Color dangerContainer;
  final Color neutralContainer;
  final Color channel;
  final Color directMessage;
  final Color agentThread;
  final Color selectedOverlay;
  final Color mutedSurface;
  final Color focus;

  static AppSemanticColors of(BuildContext context) {
    return Theme.of(context).extension<AppSemanticColors>()!;
  }

  Color tone(DiagnosticToneLike tone) {
    return switch (tone) {
      DiagnosticToneLike.success => success,
      DiagnosticToneLike.info => info,
      DiagnosticToneLike.warning => warning,
      DiagnosticToneLike.danger => danger,
      DiagnosticToneLike.neutral => neutral,
    };
  }

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? info,
    Color? warning,
    Color? danger,
    Color? neutral,
    Color? successContainer,
    Color? infoContainer,
    Color? warningContainer,
    Color? dangerContainer,
    Color? neutralContainer,
    Color? channel,
    Color? directMessage,
    Color? agentThread,
    Color? selectedOverlay,
    Color? mutedSurface,
    Color? focus,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      info: info ?? this.info,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      neutral: neutral ?? this.neutral,
      successContainer: successContainer ?? this.successContainer,
      infoContainer: infoContainer ?? this.infoContainer,
      warningContainer: warningContainer ?? this.warningContainer,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      neutralContainer: neutralContainer ?? this.neutralContainer,
      channel: channel ?? this.channel,
      directMessage: directMessage ?? this.directMessage,
      agentThread: agentThread ?? this.agentThread,
      selectedOverlay: selectedOverlay ?? this.selectedOverlay,
      mutedSurface: mutedSurface ?? this.mutedSurface,
      focus: focus ?? this.focus,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppSemanticColors(
      success: mix(success, other.success),
      info: mix(info, other.info),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      neutral: mix(neutral, other.neutral),
      successContainer: mix(successContainer, other.successContainer),
      infoContainer: mix(infoContainer, other.infoContainer),
      warningContainer: mix(warningContainer, other.warningContainer),
      dangerContainer: mix(dangerContainer, other.dangerContainer),
      neutralContainer: mix(neutralContainer, other.neutralContainer),
      channel: mix(channel, other.channel),
      directMessage: mix(directMessage, other.directMessage),
      agentThread: mix(agentThread, other.agentThread),
      selectedOverlay: mix(selectedOverlay, other.selectedOverlay),
      mutedSurface: mix(mutedSurface, other.mutedSurface),
      focus: mix(focus, other.focus),
    );
  }
}

enum DiagnosticToneLike { success, info, warning, danger, neutral }
