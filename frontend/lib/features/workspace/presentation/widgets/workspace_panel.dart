import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../core/utils/date_time_formatter.dart';
import '../../../../shared/theme/app_tokens.dart';
import '../../../../shared/widgets/app_layout.dart';

class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel({
    super.key,
    required this.workspaceName,
    required this.description,
    required this.channels,
    required this.conversations,
    required this.members,
    required this.recentInteractions,
    required this.selectedConversationId,
    required this.onOpenConversation,
    this.compact = false,
  });

  final String workspaceName;
  final String description;
  final List<WorkspaceConversationSummary> channels;
  final List<WorkspaceConversationSummary> conversations;
  final List<WorkspaceMemberSummary> members;
  final List<WorkspaceRecentInteractionSummary> recentInteractions;
  final String selectedConversationId;
  final ValueChanged<WorkspaceConversationSummary> onOpenConversation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final unreadTotal = conversations.fold<int>(
      0,
      (sum, conversation) => sum + conversation.unreadCount,
    );

    return Material(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: description,
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    child: Text(
                      'MF',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workspaceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          unreadTotal == 0
                              ? l10n.conversationCountLabel(
                                  conversations.length,
                                )
                              : '$unreadTotal ${l10n.unreadLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionLabel(
              label: l10n.conversations,
              count: conversations.length,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ConversationInbox(
              conversations: conversations,
              selectedConversationId: selectedConversationId,
              onOpenConversation: onOpenConversation,
            ),
            if (members.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Divider(height: 1, color: theme.dividerColor),
              _SecondarySection(
                title: l10n.members,
                count: members.length,
                children: [
                  for (final member in members) _MemberListRow(member: member),
                ],
              ),
            ],
            if (recentInteractions.isNotEmpty) ...[
              Divider(height: 1, color: theme.dividerColor),
              _SecondarySection(
                title: l10n.recentInteractions,
                count: recentInteractions.length,
                initiallyExpanded: compact,
                children: [
                  for (final interaction in recentInteractions)
                    _RecentInteractionRow(interaction: interaction),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '$count',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SecondarySection extends StatelessWidget {
  const _SecondarySection({
    required this.title,
    required this.count,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String title;
  final int count;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
      initiallyExpanded: initiallyExpanded,
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count'),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.expand_more_rounded),
        ],
      ),
      children: children,
    );
  }
}

enum WorkspaceConversationKind { channel, directMessage, agentThread }

class WorkspaceConversationSummary {
  const WorkspaceConversationSummary({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.accent,
    required this.lastActivityAt,
    this.unreadCount = 0,
    this.isAvailable = true,
  });

  final String id;
  final String title;
  final String subtitle;
  final WorkspaceConversationKind kind;
  final Color accent;
  final String? lastActivityAt;
  final int unreadCount;
  final bool isAvailable;
}

class WorkspaceMemberSummary {
  const WorkspaceMemberSummary({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.accent,
    required this.isCurrentUser,
  });

  final String id;
  final String displayName;
  final String subtitle;
  final Color accent;
  final bool isCurrentUser;
}

class WorkspaceRecentInteractionSummary {
  const WorkspaceRecentInteractionSummary({
    required this.authorLabel,
    required this.preview,
    required this.timestampLabel,
    required this.accent,
    required this.isAgent,
  });

  final String authorLabel;
  final String preview;
  final String timestampLabel;
  final Color accent;
  final bool isAgent;
}

class _ConversationInbox extends StatelessWidget {
  const _ConversationInbox({
    required this.conversations,
    required this.selectedConversationId,
    required this.onOpenConversation,
  });

  final List<WorkspaceConversationSummary> conversations;
  final String selectedConversationId;
  final ValueChanged<WorkspaceConversationSummary> onOpenConversation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final groups =
        <
          ({
            String title,
            IconData icon,
            List<WorkspaceConversationSummary> items,
          })
        >[
          (
            title: l10n.teamChannels,
            icon: Icons.tag_rounded,
            items: _byKind(WorkspaceConversationKind.channel),
          ),
          (
            title: l10n.directMessages,
            icon: Icons.person_outline_rounded,
            items: _byKind(WorkspaceConversationKind.directMessage),
          ),
          (
            title: l10n.agentThreads,
            icon: Icons.smart_toy_outlined,
            items: _byKind(WorkspaceConversationKind.agentThread),
          ),
        ];
    final visibleGroups = groups
        .where((group) => group.items.isNotEmpty)
        .toList(growable: false);

    if (visibleGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (
          var groupIndex = 0;
          groupIndex < visibleGroups.length;
          groupIndex++
        )
          Padding(
            padding: EdgeInsets.only(
              bottom: groupIndex == visibleGroups.length - 1
                  ? 0
                  : AppSpacing.md,
            ),
            child: _ConversationSection(
              title: visibleGroups[groupIndex].title,
              icon: visibleGroups[groupIndex].icon,
              conversations: visibleGroups[groupIndex].items,
              selectedConversationId: selectedConversationId,
              onOpenConversation: onOpenConversation,
            ),
          ),
      ],
    );
  }

  List<WorkspaceConversationSummary> _byKind(WorkspaceConversationKind kind) {
    final result = conversations
        .where((conversation) => conversation.kind == kind)
        .toList(growable: false);
    result.sort(_sortByLastActivityDesc);
    return result;
  }
}

class _ConversationSection extends StatelessWidget {
  const _ConversationSection({
    required this.title,
    required this.icon,
    required this.conversations,
    required this.selectedConversationId,
    required this.onOpenConversation,
  });

  final String title;
  final IconData icon;
  final List<WorkspaceConversationSummary> conversations;
  final String selectedConversationId;
  final ValueChanged<WorkspaceConversationSummary> onOpenConversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs),
          child: Row(
            children: [
              Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final conversation in conversations)
          _ConversationRow(
            conversation: conversation,
            selected: conversation.id == selectedConversationId,
            onTap: () => onOpenConversation(conversation),
          ),
      ],
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final WorkspaceConversationSummary conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final timestamp = conversation.lastActivityAt == null
        ? ''
        : _formatConversationTimestamp(conversation.lastActivityAt!);
    final subtitle = [
      if (conversation.subtitle.isNotEmpty) conversation.subtitle,
      if (timestamp.isNotEmpty) timestamp,
    ].join(' - ');
    final trailing = !conversation.isAvailable
        ? Text(l10n.previewLabel)
        : conversation.unreadCount > 0
        ? _UnreadCount(value: conversation.unreadCount)
        : null;

    return AppListRow(
      title: conversation.title,
      subtitle: subtitle,
      leading: Icon(_iconForConversation(conversation.kind)),
      trailing: trailing,
      selected: selected,
      compact: true,
      onTap: onTap,
    );
  }
}

class _UnreadCount extends StatelessWidget {
  const _UnreadCount({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Text(
        '$value',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MemberListRow extends StatelessWidget {
  const _MemberListRow({required this.member});

  final WorkspaceMemberSummary member;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppListRow(
      title: member.displayName,
      subtitle: member.subtitle,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: member.accent.withValues(alpha: 0.14),
        foregroundColor: member.accent,
        child: Text(_initialsFor(member.displayName)),
      ),
      trailing: member.isCurrentUser ? Text(l10n.memberYouLabel) : null,
      compact: true,
    );
  }
}

class _RecentInteractionRow extends StatelessWidget {
  const _RecentInteractionRow({required this.interaction});

  final WorkspaceRecentInteractionSummary interaction;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      title: interaction.authorLabel,
      subtitle: interaction.preview,
      leading: Icon(
        interaction.isAgent ? Icons.smart_toy_outlined : Icons.person_outline,
        color: interaction.accent,
      ),
      trailing: Text(interaction.timestampLabel),
      compact: true,
    );
  }
}

IconData _iconForConversation(WorkspaceConversationKind kind) {
  return switch (kind) {
    WorkspaceConversationKind.channel => Icons.tag_rounded,
    WorkspaceConversationKind.directMessage => Icons.person_outline_rounded,
    WorkspaceConversationKind.agentThread => Icons.smart_toy_outlined,
  };
}

String _initialsFor(String value) {
  final cleaned = value.replaceAll('@', '').trim();
  if (cleaned.isEmpty) return 'MF';
  final parts = cleaned
      .split(RegExp(r'[\s_-]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
  return cleaned.substring(0, cleaned.length >= 2 ? 2 : 1).toUpperCase();
}

int _sortByLastActivityDesc(
  WorkspaceConversationSummary left,
  WorkspaceConversationSummary right,
) {
  final leftTime = DateTime.tryParse(left.lastActivityAt ?? '');
  final rightTime = DateTime.tryParse(right.lastActivityAt ?? '');
  if (leftTime == null && rightTime == null) {
    return left.title.compareTo(right.title);
  }
  if (leftTime == null) return 1;
  if (rightTime == null) return -1;
  return rightTime.compareTo(leftTime);
}

String _formatConversationTimestamp(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(parsed.year, parsed.month, parsed.day);
  if (day == today) return formatShortTimestamp(parsed);
  return '${parsed.month}/${parsed.day}';
}
