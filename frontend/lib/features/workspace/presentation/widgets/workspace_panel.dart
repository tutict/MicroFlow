import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../core/utils/date_time_formatter.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/status_badge.dart';

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
    final outerRadius = compact ? 20.0 : 30.0;
    final outerPadding = compact ? 14.0 : 18.0;
    final shellSurface = theme.colorScheme.surface.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.5 : 0.76,
    );
    final nestedSurface = theme.colorScheme.surface.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.34 : 0.62,
    );
    final subtleBorder = theme.dividerColor.withValues(alpha: 0.82);

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.4 : 0.82,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: subtleBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.14,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'MF',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.workspace,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.62,
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            workspaceName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _WorkspaceMetric(
                      value: '${conversations.length}',
                      label: l10n.conversations,
                    ),
                    _WorkspaceMetric(
                      value: '$unreadTotal',
                      label: l10n.unreadLabel,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.conversations,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.conversationCountLabel(conversations.length),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: shellSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: subtleBorder),
            ),
            child: _ConversationInbox(
              conversations: conversations,
              selectedConversationId: selectedConversationId,
              onOpenConversation: onOpenConversation,
            ),
          ),
          if (members.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.members,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l10n.membersCountLabel(members.length),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.72,
                      ),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: shellSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: subtleBorder),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < members.length; index++) ...[
                    _MemberListTile(member: members[index]),
                    if (index != members.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.recentInteractions,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.messageCountLabel(recentInteractions.length),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: shellSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: subtleBorder),
            ),
            child: recentInteractions.isEmpty
                ? _EmptyCollaborationState(message: l10n.noRecentInteractions)
                : Column(
                    children: [
                      for (
                        var index = 0;
                        index < recentInteractions.length;
                        index++
                      ) ...[
                        _RecentInteractionTile(
                          interaction: recentInteractions[index],
                        ),
                        if (index != recentInteractions.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.recentActivityLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: shellSurface,
        borderRadius: BorderRadius.circular(outerRadius),
        border: Border.all(color: subtleBorder),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark
                ? const Color(0x22000000)
                : const Color(0x120E1A22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              outerPadding,
              compact ? 14 : 18,
              outerPadding,
              compact ? 14 : 16,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.38 : 0.78,
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(outerRadius),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: compact ? 38 : 42,
                      height: compact ? 38 : 42,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.14,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'MF',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 10 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.workspace,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.62,
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            workspaceName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 12 : 14),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                    height: 1.45,
                  ),
                ),
                SizedBox(height: compact ? 12 : 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _WorkspaceMetric(
                      value: '${conversations.length}',
                      label: l10n.conversations,
                    ),
                    _WorkspaceMetric(
                      value: '$unreadTotal',
                      label: l10n.unreadLabel,
                    ),
                  ],
                ),
                SizedBox(height: compact ? 12 : 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge(
                      label: l10n.localFirst,
                      color: const Color(0xFF1F6F5C),
                    ),
                    StatusBadge(
                      label: l10n.sqlite,
                      color: const Color(0xFF52796F),
                    ),
                    StatusBadge(
                      label: l10n.virtualThreads,
                      color: const Color(0xFF6C7A89),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              outerPadding,
              compact ? 14 : 18,
              outerPadding,
              compact ? 14 : 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.conversations,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Text(
                        l10n.conversationCountLabel(conversations.length),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.74,
                          ),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 12 : 14),
                Container(
                  padding: EdgeInsets.all(compact ? 12 : 14),
                  decoration: BoxDecoration(
                    color: nestedSurface,
                    borderRadius: BorderRadius.circular(compact ? 16 : 18),
                    border: Border.all(color: subtleBorder),
                  ),
                  child: _ConversationInbox(
                    conversations: conversations,
                    selectedConversationId: selectedConversationId,
                    onOpenConversation: onOpenConversation,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceMetric extends StatelessWidget {
  const _WorkspaceMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppPill(
      label: label,
      value: value,
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      borderColor: Colors.white.withValues(alpha: 0.12),
      valueColor: Colors.white,
      labelColor: Colors.white.withValues(alpha: 0.72),
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
    final teamChannels =
        conversations
            .where(
              (conversation) =>
                  conversation.kind == WorkspaceConversationKind.channel,
            )
            .toList(growable: false)
          ..sort(_sortByLastActivityDesc);
    final directMessages =
        conversations
            .where(
              (conversation) =>
                  conversation.kind == WorkspaceConversationKind.directMessage,
            )
            .toList(growable: false)
          ..sort(_sortByLastActivityDesc);
    final agentThreads =
        conversations
            .where(
              (conversation) =>
                  conversation.kind == WorkspaceConversationKind.agentThread,
            )
            .toList(growable: false)
          ..sort(_sortByLastActivityDesc);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (teamChannels.isNotEmpty)
          _ConversationSection(
            title: l10n.teamChannels,
            icon: Icons.forum_rounded,
            conversations: teamChannels,
            selectedConversationId: selectedConversationId,
            onOpenConversation: onOpenConversation,
          ),
        if (directMessages.isNotEmpty) ...[
          if (teamChannels.isNotEmpty) const SizedBox(height: 12),
          _ConversationSection(
            title: l10n.directMessages,
            icon: Icons.person_rounded,
            conversations: directMessages,
            selectedConversationId: selectedConversationId,
            onOpenConversation: onOpenConversation,
          ),
        ],
        if (agentThreads.isNotEmpty) ...[
          if (teamChannels.isNotEmpty || directMessages.isNotEmpty)
            const SizedBox(height: 12),
          _ConversationSection(
            title: l10n.agentThreads,
            icon: Icons.smart_toy_rounded,
            conversations: agentThreads,
            selectedConversationId: selectedConversationId,
            onOpenConversation: onOpenConversation,
          ),
        ],
      ],
    );
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
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        ...conversations.map(
          (conversation) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ConversationTile(
              conversation: conversation,
              isSelected: conversation.id == selectedConversationId,
              onTap: () => onOpenConversation(conversation),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.isSelected,
    required this.onTap,
  });

  final WorkspaceConversationSummary conversation;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selectedBackground = theme.colorScheme.primary.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.18 : 0.12,
    );
    final leadingBackground = isSelected
        ? theme.colorScheme.primary
        : conversation.accent.withValues(alpha: 0.12);
    final activityLabel = conversation.lastActivityAt == null
        ? ''
        : _formatConversationTimestamp(conversation.lastActivityAt!);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? selectedBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.24)
                  : theme.dividerColor.withValues(alpha: 0.48),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: leadingBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _iconForConversation(conversation.kind),
                  size: 18,
                  color: isSelected ? Colors.white : conversation.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (activityLabel.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              activityLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.54,
                                ),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (!conversation.isAvailable)
                          AppPill(
                            label: l10n.previewLabel,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHigh,
                            borderColor: theme.dividerColor.withValues(
                              alpha: 0.72,
                            ),
                            labelColor: theme.colorScheme.onSurface.withValues(
                              alpha: 0.72,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          )
                        else if (conversation.unreadCount > 0)
                          AppPill(
                            label: '${conversation.unreadCount}',
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.12),
                            borderColor: theme.colorScheme.primary.withValues(
                              alpha: 0.18,
                            ),
                            labelColor: theme.colorScheme.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conversation.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.62,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberListTile extends StatelessWidget {
  const _MemberListTile({required this.member});

  final WorkspaceMemberSummary member;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.34 : 0.64,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.82)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: member.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              _initialsFor(member.displayName),
              style: theme.textTheme.titleSmall?.copyWith(
                color: member.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (member.isCurrentUser)
                      AppPill(
                        label: l10n.memberYouLabel,
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        borderColor: theme.colorScheme.primary.withValues(
                          alpha: 0.16,
                        ),
                        labelColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  member.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentInteractionTile extends StatelessWidget {
  const _RecentInteractionTile({required this.interaction});

  final WorkspaceRecentInteractionSummary interaction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.34 : 0.64,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.82)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: interaction.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              _initialsFor(interaction.authorLabel),
              style: theme.textTheme.titleSmall?.copyWith(
                color: interaction.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        interaction.authorLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (interaction.isAgent)
                      StatusBadge(
                        label: l10n.aiBadge,
                        color: const Color(0xFF1F6F5C),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  interaction.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  interaction.timestampLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCollaborationState extends StatelessWidget {
  const _EmptyCollaborationState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.3 : 0.58,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.82)),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
          height: 1.45,
        ),
      ),
    );
  }
}

IconData _iconForConversation(WorkspaceConversationKind kind) {
  return switch (kind) {
    WorkspaceConversationKind.channel => Icons.tag_rounded,
    WorkspaceConversationKind.directMessage => Icons.person_rounded,
    WorkspaceConversationKind.agentThread => Icons.smart_toy_rounded,
  };
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

int _sortByLastActivityDesc(
  WorkspaceConversationSummary left,
  WorkspaceConversationSummary right,
) {
  final leftTime = DateTime.tryParse(left.lastActivityAt ?? '');
  final rightTime = DateTime.tryParse(right.lastActivityAt ?? '');
  if (leftTime == null && rightTime == null) {
    return left.title.compareTo(right.title);
  }
  if (leftTime == null) {
    return 1;
  }
  if (rightTime == null) {
    return -1;
  }
  return rightTime.compareTo(leftTime);
}

String _formatConversationTimestamp(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) {
    return '';
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(parsed.year, parsed.month, parsed.day);
  if (day == today) {
    return formatShortTimestamp(parsed);
  }
  return '${parsed.month}/${parsed.day}';
}
