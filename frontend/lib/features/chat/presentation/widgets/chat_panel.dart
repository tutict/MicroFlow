import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/collaboration_event.dart';
import '../../domain/entities/collaboration_run.dart';
import '../../../workspace/domain/entities/knowledge_document.dart';
import '../../../workspace/presentation/state/workspace_shell_state.dart';
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
    this.knowledgeDocuments = const [],
    this.onKnowledgeCitationTap,
    required this.participants,
    required this.activeParticipantCount,
    required this.suggestedMentions,
    required this.collaborationModeAvailable,
    required this.collaborationModeEnabled,
    required this.onCollaborationModeChanged,
    this.collaborationStatusText,
    this.collaborationSnapshot,
    this.collaborationRuns = const [],
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
  final List<KnowledgeDocument> knowledgeDocuments;
  final ValueChanged<String>? onKnowledgeCitationTap;
  final List<ChatParticipantPreview> participants;
  final int activeParticipantCount;
  final List<String> suggestedMentions;
  final bool collaborationModeAvailable;
  final bool collaborationModeEnabled;
  final ValueChanged<bool>? onCollaborationModeChanged;
  final String? collaborationStatusText;
  final CollaborationStatusSnapshot? collaborationSnapshot;
  final List<CollaborationRun> collaborationRuns;
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
            child: Padding(
              padding: EdgeInsets.all(sectionGap),
              child: Column(
                children: [
                  if (collaborationSnapshot != null || collaborationRuns.isNotEmpty)
                    Flexible(
                      fit: FlexFit.loose,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: sectionGap),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: compact ? 180 : 220,
                          ),
                          child: _CollaborationStatusPanel(
                            snapshot: collaborationSnapshot,
                            compact: compact,
                            statusText: collaborationStatusText,
                            runs: collaborationRuns,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Container(
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
                        knowledgeDocuments: knowledgeDocuments,
                        onKnowledgeCitationTap: onKnowledgeCitationTap,
                        compact: compact,
                        emptyIcon: emptyStateIcon,
                        emptyTitle: emptyStateTitle,
                        emptyDescription: emptyStateDescription,
                      ),
                    ),
                  ),
                ],
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
                      knowledgeDocuments: knowledgeDocuments,
                      onKnowledgeCitationTap: onKnowledgeCitationTap,
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

class _CollaborationStatusPanel extends StatefulWidget {
  const _CollaborationStatusPanel({
    required this.snapshot,
    required this.compact,
    this.statusText,
    this.runs = const [],
  });

  final CollaborationStatusSnapshot? snapshot;
  final bool compact;
  final String? statusText;
  final List<CollaborationRun> runs;

  @override
  State<_CollaborationStatusPanel> createState() =>
      _CollaborationStatusPanelState();
}

class _CollaborationStatusPanelState extends State<_CollaborationStatusPanel> {
  _CollaborationRunScopeFilter _runScopeFilter =
      _CollaborationRunScopeFilter.all;
  _CollaborationRunStatusFilter _statusFilter =
      _CollaborationRunStatusFilter.all;
  String? _agentFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final activeSnapshot = widget.snapshot;
    final statusColor = activeSnapshot == null
        ? theme.colorScheme.primary
        : _collaborationStatusColor(activeSnapshot.status);
    final progress = activeSnapshot == null
        ? null
        : _collaborationProgress(activeSnapshot);
    final roundLabel = activeSnapshot != null && activeSnapshot.maxRounds > 0
        ? l10n.collaborationRoundStatus(
            activeSnapshot.round,
            activeSnapshot.maxRounds,
          )
        : null;
    final stageSequence = activeSnapshot == null
        ? const <String>[]
        : _collaborationStageSequence(activeSnapshot.maxRounds);
    final availableAgents = _collaborationAgents(widget.runs);
    final filteredRuns = widget.runs
        .where(
          (group) =>
              _matchesRunScope(
                group,
                activeCollaborationId: activeSnapshot?.collaborationId,
              ) &&
              _matchesStatus(group) &&
              _matchesAgent(group),
        )
        .toList(growable: false)
      ..sort((left, right) {
        final rightAt =
            DateTime.tryParse(right.lastEventAt) ??
            DateTime.tryParse(right.startedAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final leftAt =
            DateTime.tryParse(left.lastEventAt) ??
            DateTime.tryParse(left.startedAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return rightAt.compareTo(leftAt);
      });
    final hasActiveFilteredRun = filteredRuns.any(
      (group) => group.collaborationId == activeSnapshot?.collaborationId,
    );

    return Container(
      padding: EdgeInsets.all(widget.compact ? 14 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.14 : 0.08,
        ),
        borderRadius: BorderRadius.circular(widget.compact ? 18 : 20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.collaborationMode,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (widget.statusText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.statusText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                          height: 1.45,
                        ),
                      ),
                    ] else if (widget.runs.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.teamRunsAvailable,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (activeSnapshot != null)
                StatusBadge(
                  label: _formatCollaborationStatusLabel(
                    l10n,
                    activeSnapshot.status,
                  ),
                  color: statusColor,
                )
              else
                Text(
                  l10n.history,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          if (roundLabel != null && progress != null) ...[
            SizedBox(height: widget.compact ? 12 : 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: widget.compact ? 7 : 8,
                      backgroundColor: statusColor.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  roundLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          if (stageSequence.isNotEmpty) ...[
            SizedBox(height: widget.compact ? 12 : 14),
            Text(
              stageSequence
                  .map((stage) => _formatCollaborationStage(l10n, stage))
                  .join(' / '),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (activeSnapshot != null) ...[
            SizedBox(height: widget.compact ? 12 : 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppPill(
                  label: activeSnapshot.trigger,
                  icon: Icons.alternate_email_rounded,
                  backgroundColor: theme.colorScheme.surface.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.32 : 0.7,
                  ),
                  borderColor: theme.dividerColor.withValues(alpha: 0.82),
                ),
                if (activeSnapshot.activeAgentKey != null &&
                    activeSnapshot.activeAgentKey!.isNotEmpty)
                  AppPill(
                    label: '@${activeSnapshot.activeAgentKey}',
                    icon: Icons.smart_toy_rounded,
                    backgroundColor: statusColor.withValues(alpha: 0.12),
                    borderColor: statusColor.withValues(alpha: 0.18),
                    labelColor: statusColor,
                    iconColor: statusColor,
                  ),
                AppPill(
                  label: _compactCollaborationId(
                    activeSnapshot.collaborationId,
                  ),
                  icon: Icons.route_rounded,
                  backgroundColor: theme.colorScheme.surface.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.32 : 0.7,
                  ),
                  borderColor: theme.dividerColor.withValues(alpha: 0.82),
                ),
              ],
            ),
          ],
          if (activeSnapshot != null &&
              activeSnapshot.detail != null &&
              activeSnapshot.detail!.trim().isNotEmpty) ...[
            SizedBox(height: widget.compact ? 10 : 12),
            Text(
              activeSnapshot.detail!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
                height: 1.5,
              ),
            ),
          ],
          if (widget.runs.isNotEmpty) ...[
            SizedBox(height: widget.compact ? 12 : 14),
            Text(
              activeSnapshot == null ? l10n.recentRuns : l10n.runHistory,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _CollaborationRunFilters(
              compact: widget.compact,
              activeSnapshot: activeSnapshot,
              runScopeFilter: _runScopeFilter,
              statusFilter: _statusFilter,
              agentFilter: _agentFilter,
              availableAgents: availableAgents,
              onRunScopeChanged: (value) {
                setState(() => _runScopeFilter = value);
              },
              onStatusChanged: (value) {
                setState(() => _statusFilter = value);
              },
              onAgentChanged: (value) {
                setState(() => _agentFilter = value);
              },
            ),
            const SizedBox(height: 10),
            if (filteredRuns.isEmpty)
              Text(
                l10n.noRunsMatchFilters,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  height: 1.45,
                ),
              )
            else
              ...filteredRuns.asMap().entries.map((groupEntry) {
                final group = groupEntry.value;
                final isInitiallyExpanded =
                    group.collaborationId == activeSnapshot?.collaborationId
                    ? true
                    : !hasActiveFilteredRun && groupEntry.key == 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CollaborationRunCard(
                    group: group,
                    compact: widget.compact,
                    initiallyExpanded: isInitiallyExpanded,
                    isActiveRun:
                        group.collaborationId ==
                        activeSnapshot?.collaborationId,
                  ),
                );
              }),
          ],
          ],
        ),
      ),
    );
  }

  bool _matchesRunScope(
    CollaborationRun group, {
    required String? activeCollaborationId,
  }) {
    if (_runScopeFilter == _CollaborationRunScopeFilter.all) {
      return true;
    }
    return activeCollaborationId != null &&
        group.collaborationId == activeCollaborationId;
  }

  bool _matchesStatus(CollaborationRun group) {
    return switch (_statusFilter) {
      _CollaborationRunStatusFilter.all => true,
      _CollaborationRunStatusFilter.running => group.status == 'RUNNING',
      _CollaborationRunStatusFilter.completed => group.status == 'COMPLETED',
      _CollaborationRunStatusFilter.aborted =>
        group.status == 'ABORTED' || group.status == 'FAILED',
    };
  }

  bool _matchesAgent(CollaborationRun group) {
    final agent = _agentFilter;
    if (agent == null || agent.isEmpty) {
      return true;
    }
    return group.agentKeys.contains(agent) ||
        group.events.any((entry) => entry.agentKey == agent);
  }
}

class _CollaborationRunFilters extends StatelessWidget {
  const _CollaborationRunFilters({
    required this.compact,
    required this.activeSnapshot,
    required this.runScopeFilter,
    required this.statusFilter,
    required this.agentFilter,
    required this.availableAgents,
    required this.onRunScopeChanged,
    required this.onStatusChanged,
    required this.onAgentChanged,
  });

  final bool compact;
  final CollaborationStatusSnapshot? activeSnapshot;
  final _CollaborationRunScopeFilter runScopeFilter;
  final _CollaborationRunStatusFilter statusFilter;
  final String? agentFilter;
  final List<String> availableAgents;
  final ValueChanged<_CollaborationRunScopeFilter> onRunScopeChanged;
  final ValueChanged<_CollaborationRunStatusFilter> onStatusChanged;
  final ValueChanged<String?> onAgentChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final helperStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
      fontWeight: FontWeight.w700,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.filterRuns, style: helperStyle),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(l10n.allRuns),
              selected: runScopeFilter == _CollaborationRunScopeFilter.all,
              onSelected: (_) {
                onRunScopeChanged(_CollaborationRunScopeFilter.all);
              },
            ),
            if (activeSnapshot != null)
              ChoiceChip(
                label: Text(l10n.currentRun),
                selected:
                    runScopeFilter == _CollaborationRunScopeFilter.current,
                onSelected: (_) {
                  onRunScopeChanged(_CollaborationRunScopeFilter.current);
                },
              ),
          ],
        ),
        SizedBox(height: compact ? 10 : 12),
        Text(l10n.filterByStatus, style: helperStyle),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(l10n.allStatuses),
              selected: statusFilter == _CollaborationRunStatusFilter.all,
              onSelected: (_) {
                onStatusChanged(_CollaborationRunStatusFilter.all);
              },
            ),
            ChoiceChip(
              label: Text(l10n.running),
              selected: statusFilter == _CollaborationRunStatusFilter.running,
              onSelected: (_) {
                onStatusChanged(_CollaborationRunStatusFilter.running);
              },
            ),
            ChoiceChip(
              label: Text(l10n.completed),
              selected: statusFilter == _CollaborationRunStatusFilter.completed,
              onSelected: (_) {
                onStatusChanged(_CollaborationRunStatusFilter.completed);
              },
            ),
            ChoiceChip(
              label: Text(l10n.stopped),
              selected: statusFilter == _CollaborationRunStatusFilter.aborted,
              onSelected: (_) {
                onStatusChanged(_CollaborationRunStatusFilter.aborted);
              },
            ),
          ],
        ),
        if (availableAgents.isNotEmpty) ...[
          SizedBox(height: compact ? 10 : 12),
          Text(l10n.filterByAgent, style: helperStyle),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(l10n.allAgents),
                selected: agentFilter == null,
                onSelected: (_) => onAgentChanged(null),
              ),
              ...availableAgents.map(
                (agent) => ChoiceChip(
                  label: Text('@$agent'),
                  selected: agentFilter == agent,
                  onSelected: (_) => onAgentChanged(agent),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CollaborationRunCard extends StatelessWidget {
  const _CollaborationRunCard({
    required this.group,
    required this.compact,
    required this.initiallyExpanded,
    required this.isActiveRun,
  });

  final CollaborationRun group;
  final bool compact;
  final bool initiallyExpanded;
  final bool isActiveRun;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final latestEntry = group.events.isEmpty
        ? _fallbackRunEvent(group)
        : group.events.last;
    final statusColor = _collaborationStatusColor(group.status);
    final stages = _distinctStages(group.events);
    final agentKeys = group.agentKeys.isNotEmpty
        ? group.agentKeys
        : _fallbackAgentKeys(group.events, group.activeAgentKey);
    final timestamp = DateTime.tryParse(group.lastEventAt)?.toLocal();
    final summaryParts = <String>[
      if (isActiveRun) l10n.live,
      l10n.eventsCount(group.events.length),
      if (group.maxRounds > 0) l10n.roundsCount(group.round, group.maxRounds),
      if (timestamp != null) _formatClock(timestamp),
      if (group.trigger != null && group.trigger!.isNotEmpty) group.trigger!,
    ];
    final detailParts = <String>[
      if (agentKeys.isNotEmpty) agentKeys.map((agentKey) => '@$agentKey').join(', '),
      if (stages.isNotEmpty)
        stages.map((stage) => _formatCollaborationStage(l10n, stage)).join(' / '),
      if (group.triggerMessageId != null && group.triggerMessageId!.isNotEmpty)
        _compactReference(group.triggerMessageId!),
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.3 : 0.68,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.82)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('collab_${group.collaborationId}'),
          initiallyExpanded: initiallyExpanded,
          tilePadding: EdgeInsets.fromLTRB(
            compact ? 12 : 14,
            compact ? 8 : 10,
            compact ? 12 : 14,
            compact ? 8 : 10,
          ),
          childrenPadding: EdgeInsets.fromLTRB(
            compact ? 12 : 14,
            0,
            compact ? 12 : 14,
            compact ? 12 : 14,
          ),
          leading: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  _compactCollaborationId(group.collaborationId),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                label: _formatCollaborationStatusLabel(
                  l10n,
                  latestEntry.status,
                ),
                color: statusColor,
              ),
            ],
          ),
          subtitle: Text(
            _collaborationTimelineTitle(l10n, latestEntry),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              height: 1.45,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summaryParts.join(' • '),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.76),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (detailParts.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      detailParts.join(' • '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (group.reason != null && group.reason!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.reasonLabel(group.reason!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 10),
            ...group.events.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CollaborationTimelineTile(entry: entry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CollaborationRunScopeFilter { all, current }

enum _CollaborationRunStatusFilter { all, running, completed, aborted }

class _CollaborationTimelineTile extends StatelessWidget {
  const _CollaborationTimelineTile({required this.entry});

  final CollaborationEvent entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final statusColor = _collaborationStatusColor(entry.status);
    final timestamp = DateTime.tryParse(entry.createdAt)?.toLocal();
    final roundLabel = entry.maxRounds > 0
        ? 'R${entry.round}/${entry.maxRounds}'
        : entry.round > 0
        ? 'R${entry.round}'
        : 'R0';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.3 : 0.68,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.82)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _collaborationTimelineTitle(l10n, entry),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (timestamp != null)
                Text(
                  '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppPill(
                label: roundLabel,
                icon: Icons.repeat_rounded,
                backgroundColor: theme.colorScheme.surface.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.32 : 0.74,
                ),
                borderColor: theme.dividerColor.withValues(alpha: 0.82),
              ),
              if (entry.stage != null && entry.stage!.isNotEmpty)
                AppPill(
                  label: _formatCollaborationStage(l10n, entry.stage!),
                  icon: _collaborationStageIcon(entry.stage!),
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  borderColor: statusColor.withValues(alpha: 0.18),
                  labelColor: statusColor,
                  iconColor: statusColor,
                ),
              if (entry.agentKey != null && entry.agentKey!.isNotEmpty)
                AppPill(
                  label: '@${entry.agentKey}',
                  icon: Icons.smart_toy_rounded,
                ),
            ],
          ),
          if (entry.detail != null && entry.detail!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              entry.detail!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
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

String _formatCollaborationStatusLabel(AppLocalizations l10n, String value) {
  return switch (value) {
    'RUNNING' => l10n.running,
    'COMPLETED' => l10n.completed,
    'ABORTED' => l10n.failed,
    _ => value,
  };
}

Color _collaborationStatusColor(String value) {
  return switch (value) {
    'COMPLETED' => const Color(0xFF1F8A5C),
    'ABORTED' => const Color(0xFFBA3B2F),
    'RUNNING' => const Color(0xFF3D7EA6),
    _ => const Color(0xFF6C7A89),
  };
}

double _collaborationProgress(CollaborationStatusSnapshot snapshot) {
  if (snapshot.maxRounds <= 0) {
    return snapshot.status == 'COMPLETED' ? 1 : 0;
  }
  final value = snapshot.round / snapshot.maxRounds;
  return value.clamp(0, 1).toDouble();
}

String _compactCollaborationId(String value) {
  return value.length > 12 ? '${value.substring(0, 12)}...' : value;
}

String _compactReference(String value) {
  return value.length > 14 ? '${value.substring(0, 14)}...' : value;
}

List<String> _collaborationAgents(List<CollaborationRun> groups) {
  final agents = <String>[];
  final seenAgents = <String>{};
  for (final group in groups) {
    for (final agent in group.agentKeys) {
      if (agent.isEmpty || !seenAgents.add(agent)) {
        continue;
      }
      agents.add(agent);
    }
    for (final entry in group.events) {
      final agent = entry.agentKey;
      if (agent == null || agent.isEmpty || !seenAgents.add(agent)) {
        continue;
      }
      agents.add(agent);
    }
  }
  return agents;
}

List<String> _fallbackAgentKeys(
  List<CollaborationEvent> events,
  String? activeAgentKey,
) {
  final agents = <String>[];
  final seenAgents = <String>{};
  for (final entry in events) {
    final agent = entry.agentKey;
    if (agent == null || agent.isEmpty || !seenAgents.add(agent)) {
      continue;
    }
    agents.add(agent);
  }
  if (activeAgentKey != null &&
      activeAgentKey.isNotEmpty &&
      seenAgents.add(activeAgentKey)) {
    agents.add(activeAgentKey);
  }
  return agents;
}

CollaborationEvent _fallbackRunEvent(CollaborationRun run) {
  return CollaborationEvent(
    id: run.collaborationId,
    workspaceId: run.workspaceId,
    channelId: run.channelId,
    collaborationId: run.collaborationId,
    eventType: 'COLLABORATION_${run.status}',
    status: run.status,
    round: run.round,
    maxRounds: run.maxRounds,
    createdAt: run.lastEventAt,
    stage: run.stage,
    agentKey: run.activeAgentKey,
    trigger: run.trigger,
    detail: run.detail,
  );
}

List<String> _distinctStages(List<CollaborationEvent> entries) {
  final stages = <String>[];
  final seenStages = <String>{};
  for (final entry in entries) {
    final stage = entry.stage;
    if (stage == null || stage.isEmpty || !seenStages.add(stage)) {
      continue;
    }
    stages.add(stage);
  }
  return stages;
}

String _formatClock(DateTime timestamp) {
  return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
}

List<String> _collaborationStageSequence(int maxRounds) {
  if (maxRounds <= 0) {
    return const [];
  }
  if (maxRounds == 1) {
    return const ['deliver'];
  }
  if (maxRounds == 2) {
    return const ['analyze', 'synthesize'];
  }
  return const ['analyze', 'critique', 'synthesize'];
}

String _formatCollaborationStage(AppLocalizations l10n, String value) {
  return switch (value) {
    'analyze' => l10n.analyzeStage,
    'critique' => l10n.critiqueStage,
    'synthesize' => l10n.synthesizeStage,
    'deliver' => l10n.deliverStage,
    _ => value,
  };
}

IconData _collaborationStageIcon(String value) {
  return switch (value) {
    'analyze' => Icons.search_rounded,
    'critique' => Icons.rule_rounded,
    'synthesize' => Icons.merge_type_rounded,
    'deliver' => Icons.done_all_rounded,
    _ => Icons.timeline_rounded,
  };
}

String _collaborationTimelineTitle(
  AppLocalizations l10n,
  CollaborationEvent entry,
) {
  final stage = entry.stage == null || entry.stage!.isEmpty
      ? entry.status
      : _formatCollaborationStage(l10n, entry.stage!);
  return switch (entry.status) {
    'RUNNING' => l10n.collaborationStageInProgress(stage),
    'COMPLETED' => l10n.collaborationStageCompleted(stage),
    'ABORTED' => l10n.collaborationStageStopped(stage),
    'FAILED' => l10n.collaborationStageFailed(stage),
    _ => l10n.collaborationStageStatus(stage, entry.status.toLowerCase()),
  };
}
