import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/chat_message.dart';
import 'chat_message_list.dart';
import 'input_box.dart';

class ChatPanel extends StatelessWidget {
  const ChatPanel({
    super.key,
    required this.channelName,
    required this.conversationLabel,
    required this.conversationDescription,
    required this.statusLabel,
    required this.statusColor,
    required this.canSendMessage,
    required this.composerHintText,
    required this.emptyStateTitle,
    required this.emptyStateDescription,
    required this.emptyStateIcon,
    required this.messages,
    required this.currentUserId,
    required this.currentUserLabel,
    required this.participants,
    required this.activeParticipantCount,
    required this.suggestedMentions,
    required this.collaborationModeAvailable,
    required this.collaborationModeEnabled,
    required this.onCollaborationModeChanged,
    this.collaborationStatusText,
    required this.isSendingMessage,
    required this.messageError,
    required this.onSend,
    this.compact = false,
  });

  final String channelName;
  final String conversationLabel;
  final String conversationDescription;
  final String statusLabel;
  final Color statusColor;
  final bool canSendMessage;
  final String composerHintText;
  final String emptyStateTitle;
  final String emptyStateDescription;
  final IconData emptyStateIcon;
  final List<ChatMessage> messages;
  final String currentUserId;
  final String currentUserLabel;
  final List<ChatParticipantPreview> participants;
  final int activeParticipantCount;
  final List<String> suggestedMentions;
  final bool collaborationModeAvailable;
  final bool collaborationModeEnabled;
  final ValueChanged<bool>? onCollaborationModeChanged;
  final String? collaborationStatusText;
  final bool isSendingMessage;
  final String? messageError;
  final Future<void> Function(String value) onSend;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final outerRadius = compact ? 18.0 : 30.0;
    final outerPadding = compact ? 12.0 : 28.0;
    final sectionGap = compact ? 10.0 : 20.0;
    final participantStrip = Wrap(
      spacing: compact ? 8 : 12,
      runSpacing: compact ? 8 : 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ParticipantAvatarStack(participants: participants),
        _ChatStatPill(
          icon: Icons.groups_2_rounded,
          label: l10n.activeCountLabel(activeParticipantCount),
        ),
        _ChatStatPill(
          icon: Icons.chat_bubble_outline_rounded,
          label: l10n.messageCountLabel(messages.length),
        ),
      ],
    );
    final compactHeader = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                channelName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                statusLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        StatusBadge(label: statusLabel, color: statusColor),
      ],
    );
    final headerInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 10,
            vertical: compact ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.18 : 0.1,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            conversationLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(height: compact ? 10 : 12),
        Text(
          channelName,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        Text(
          conversationDescription,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
          ),
        ),
        SizedBox(height: compact ? 10 : 14),
        participantStrip,
      ],
    );
    final panel = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.brightness == Brightness.dark
              ? const [Color(0xFF162229), Color(0xFF111C22)]
              : const [Color(0xFFFCFDFD), Color(0xFFF2F6F7)],
        ),
        borderRadius: BorderRadius.circular(outerRadius),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? const Color(0xFF23323A)
              : const Color(0xFFD9E3E7),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark
                ? const Color(0x30000000)
                : const Color(0x160E1A22),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          if (!compact)
            Container(
              height: 4,
              margin: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    statusColor.withValues(alpha: 0.8),
                    theme.colorScheme.primary.withValues(alpha: 0.18),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              outerPadding,
              compact ? 10 : 24,
              outerPadding,
              compact ? 10 : 20,
            ),
            child: compact
                ? compactHeader
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: headerInfo),
                      const SizedBox(width: 20),
                      StatusBadge(label: statusLabel, color: statusColor),
                    ],
                  ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          Expanded(
            child: Container(
              margin: EdgeInsets.all(sectionGap),
              decoration: BoxDecoration(
                color: compact
                    ? theme.colorScheme.surfaceContainerLowest
                    : theme.colorScheme.surface.withValues(
                        alpha: theme.brightness == Brightness.dark
                            ? 0.48
                            : 0.76,
                      ),
                borderRadius: BorderRadius.circular(compact ? 16 : 20),
                border: Border.all(
                  color: compact
                      ? theme.dividerColor
                      : theme.dividerColor.withValues(alpha: 0.82),
                ),
              ),
              child: ChatMessageList(
                messages: messages,
                currentUserId: currentUserId,
                currentUserLabel: currentUserLabel,
                compact: compact,
                emptyIcon: emptyStateIcon,
                emptyTitle: emptyStateTitle,
                emptyDescription: emptyStateDescription,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(sectionGap, 0, sectionGap, sectionGap),
            child: InputBox(
              onSend: canSendMessage ? onSend : null,
              enabled: canSendMessage,
              isSending: isSendingMessage,
              errorText: messageError,
              placeholderText: composerHintText,
              helperText: canSendMessage ? null : conversationDescription,
              suggestedMentions: canSendMessage ? suggestedMentions : const [],
              collaborationModeVisible:
                  canSendMessage && collaborationModeAvailable,
              collaborationModeEnabled: collaborationModeEnabled,
              collaborationStatusText: collaborationStatusText,
              onCollaborationModeChanged: onCollaborationModeChanged,
              compact: compact,
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (compact) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: compactHeader,
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest
                          .withValues(alpha: 0.72),
                    ),
                    child: ChatMessageList(
                      messages: messages,
                      currentUserId: currentUserId,
                      currentUserLabel: currentUserLabel,
                      compact: true,
                      emptyIcon: emptyStateIcon,
                      emptyTitle: emptyStateTitle,
                      emptyDescription: emptyStateDescription,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              InputBox(
                onSend: canSendMessage ? onSend : null,
                enabled: canSendMessage,
                isSending: isSendingMessage,
                errorText: messageError,
                placeholderText: composerHintText,
                helperText: canSendMessage ? null : conversationDescription,
                suggestedMentions: canSendMessage
                    ? suggestedMentions
                    : const [],
                collaborationModeVisible:
                    canSendMessage && collaborationModeAvailable,
                collaborationModeEnabled: collaborationModeEnabled,
                collaborationStatusText: collaborationStatusText,
                onCollaborationModeChanged: onCollaborationModeChanged,
                compact: true,
              ),
            ],
          );
        }
        if (constraints.maxHeight.isFinite) {
          return panel;
        }
        return SizedBox(height: compact ? 600 : 760, child: panel);
      },
    );
  }
}

class ChatParticipantPreview {
  const ChatParticipantPreview({required this.label, required this.accent});

  final String label;
  final Color accent;
}

class _ParticipantAvatarStack extends StatelessWidget {
  const _ParticipantAvatarStack({required this.participants});

  final List<ChatParticipantPreview> participants;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleParticipants = participants.take(4).toList();

    if (visibleParticipants.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 34,
      width: 26.0 * (visibleParticipants.length - 1) + 34,
      child: Stack(
        children: [
          for (var index = 0; index < visibleParticipants.length; index++)
            Positioned(
              left: index * 26,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: visibleParticipants[index].accent.withValues(
                    alpha: 0.16,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.cardColor, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initialsFor(visibleParticipants[index].label),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: visibleParticipants[index].accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatStatPill extends StatelessWidget {
  const _ChatStatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPill(
      label: label,
      icon: icon,
      backgroundColor: theme.colorScheme.surface.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.34 : 0.62,
      ),
      borderColor: theme.dividerColor.withValues(alpha: 0.8),
      labelColor: theme.colorScheme.onSurface.withValues(alpha: 0.8),
      iconColor: theme.colorScheme.onSurface.withValues(alpha: 0.66),
    );
  }
}

String _initialsFor(String value) {
  final cleaned = value.replaceAll('@', '').trim();
  if (cleaned.isEmpty) {
    return 'MF';
  }
  final parts = cleaned
      .split(RegExp(r'[\s_-]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
  return cleaned.substring(0, cleaned.length >= 2 ? 2 : 1).toUpperCase();
}
