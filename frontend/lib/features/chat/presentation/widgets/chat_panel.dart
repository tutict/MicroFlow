import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../shared/theme/app_theme_extensions.dart';
import '../../../../shared/theme/app_tokens.dart';
import '../../../../shared/widgets/app_layout.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/collaboration_event.dart';
import '../../domain/entities/collaboration_run.dart';
import '../../../workspace/domain/entities/knowledge_document.dart';
import '../../../workspace/presentation/state/workspace_shell_state.dart';
import '../../domain/entities/chat_message.dart';
import 'chat_message_list.dart';
import 'input_box.dart';

class _CanvasExtent extends InheritedWidget {
  const _CanvasExtent({required this.height, required super.child});

  final double height;

  static double heightOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_CanvasExtent>();
    return scope?.height ?? MediaQuery.sizeOf(context).height;
  }

  @override
  bool updateShouldNotify(_CanvasExtent oldWidget) =>
      height != oldWidget.height;
}

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
    final hasCollaboration =
        collaborationSnapshot != null || collaborationRuns.isNotEmpty;
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppToolbar(
              title: channelName,
              subtitle: conversationLabel,
              compact: compact,
              leading: Icon(
                canSendMessage
                    ? Icons.forum_outlined
                    : Icons.lock_outline_rounded,
                size: 20,
              ),
              actions: [
                if (!compact)
                  Tooltip(
                    message: l10n.activeCountLabel(activeParticipantCount),
                    child: _ParticipantAvatarStack(participants: participants),
                  ),
                AppStatusDot(
                  label: statusLabel,
                  color: statusColor,
                  compact: true,
                ),
              ],
            ),
            if (hasCollaboration)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  0,
                ),
                child: _CollaborationStatusPanel(
                  snapshot: collaborationSnapshot,
                  compact: compact,
                  statusText: collaborationStatusText,
                  runs: collaborationRuns,
                ),
              ),
            Expanded(
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
            Divider(height: 1, color: theme.dividerColor),
            Padding(
              padding: EdgeInsets.all(compact ? AppSpacing.xs : AppSpacing.sm),
              child: InputBox(
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
                compact: compact,
              ),
            ),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (compact ? 600.0 : 760.0);
        final scoped = _CanvasExtent(height: height, child: content);
        if (constraints.maxHeight.isFinite) {
          return scoped;
        }
        return SizedBox(height: height, child: scoped);
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
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final activeSnapshot = widget.snapshot;
    final statusColor = activeSnapshot == null
        ? theme.colorScheme.primary
        : _collaborationStatusColor(context, activeSnapshot.status);
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
    final filteredRuns =
        widget.runs
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

    final agentLabel = activeSnapshot?.activeAgentKey;
    final summary = _CollaborationSummary(
      expanded: _expanded,
      title: l10n.collaborationMode,
      roundLabel: roundLabel,
      trigger: activeSnapshot?.trigger,
      agentLabel: agentLabel == null || agentLabel.isEmpty
          ? null
          : '@$agentLabel',
      historyLabel: activeSnapshot == null && widget.runs.isNotEmpty
          ? l10n.history
          : null,
      onToggle: () => setState(() => _expanded = !_expanded),
    );
    if (!_expanded) {
      return summary;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        summary,
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: _CanvasExtent.heightOf(context) * 0.4,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadii.medium),
                border: Border.all(color: theme.dividerColor),
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
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (widget.statusText != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.statusText!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ] else if (widget.runs.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  l10n.teamRunsAvailable,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
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
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
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
                              borderRadius: BorderRadius.circular(
                                AppRadii.small,
                              ),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: widget.compact ? 7 : 8,
                                backgroundColor: statusColor.withValues(
                                  alpha: 0.12,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  statusColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          const SizedBox.shrink(),
                        ],
                      ),
                    ],
                    if (stageSequence.isNotEmpty) ...[
                      SizedBox(height: widget.compact ? 12 : 14),
                      Text(
                        stageSequence
                            .map(
                              (stage) => _formatCollaborationStage(l10n, stage),
                            )
                            .join(' / '),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
                            backgroundColor: theme.colorScheme.surface
                                .withValues(
                                  alpha: theme.brightness == Brightness.dark
                                      ? 0.32
                                      : 0.7,
                                ),
                            borderColor: theme.dividerColor.withValues(
                              alpha: 0.82,
                            ),
                          ),
                          if (activeSnapshot.activeAgentKey != null &&
                              activeSnapshot.activeAgentKey!.isNotEmpty)
                            AppPill(
                              label: '@${activeSnapshot.activeAgentKey}',
                              icon: Icons.smart_toy_rounded,
                              backgroundColor: statusColor.withValues(
                                alpha: 0.12,
                              ),
                              borderColor: statusColor.withValues(alpha: 0.18),
                              labelColor: statusColor,
                              iconColor: statusColor,
                            ),
                          AppPill(
                            label: _compactCollaborationId(
                              activeSnapshot.collaborationId,
                            ),
                            icon: Icons.route_rounded,
                            backgroundColor: theme.colorScheme.surface
                                .withValues(
                                  alpha: theme.brightness == Brightness.dark
                                      ? 0.32
                                      : 0.7,
                                ),
                            borderColor: theme.dividerColor.withValues(
                              alpha: 0.82,
                            ),
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
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (widget.runs.isNotEmpty) ...[
                      SizedBox(height: widget.compact ? 12 : 14),
                      Text(
                        activeSnapshot == null
                            ? l10n.recentRuns
                            : l10n.runHistory,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
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
                      const SizedBox(height: AppSpacing.xs),
                      if (filteredRuns.isEmpty)
                        Text(
                          l10n.noRunsMatchFilters,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        ...filteredRuns.asMap().entries.map((groupEntry) {
                          final group = groupEntry.value;
                          final isInitiallyExpanded =
                              group.collaborationId ==
                                  activeSnapshot?.collaborationId
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
            ),
          ),
        ),
      ],
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

class _CollaborationSummary extends StatelessWidget {
  const _CollaborationSummary({
    required this.expanded,
    required this.title,
    required this.onToggle,
    this.roundLabel,
    this.trigger,
    this.agentLabel,
    this.historyLabel,
  });

  final bool expanded;
  final String title;
  final VoidCallback onToggle;
  final String? roundLabel;
  final String? trigger;
  final String? agentLabel;
  final String? historyLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    if (roundLabel != null) Text(roundLabel!),
                    if (agentLabel != null) Text(agentLabel!),
                    if (trigger != null) Text(trigger!),
                    if (historyLabel != null) Text(historyLabel!),
                  ],
                ),
              ),
              IconButton(
                tooltip: expanded
                    ? l10n.hideCollaborationDetails
                    : l10n.showCollaborationDetails,
                onPressed: onToggle,
                icon: Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      color: theme.colorScheme.onSurfaceVariant,
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
    final statusColor = _collaborationStatusColor(context, group.status);
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
      if (agentKeys.isNotEmpty)
        agentKeys.map((agentKey) => '@$agentKey').join(', '),
      if (stages.isNotEmpty)
        stages
            .map((stage) => _formatCollaborationStage(l10n, stage))
            .join(' / '),
      if (group.triggerMessageId != null && group.triggerMessageId!.isNotEmpty)
        _compactReference(group.triggerMessageId!),
    ];

    return Material(
      color: theme.colorScheme.surface.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.3 : 0.68,
      ),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.82)),
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
            width: 8,
            height: 8,
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
                    fontWeight: FontWeight.w600,
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
              color: theme.colorScheme.onSurfaceVariant,
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
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (detailParts.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      detailParts.join(' • '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
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
    final statusColor = _collaborationStatusColor(context, entry.status);
    final timestamp = DateTime.tryParse(entry.createdAt)?.toLocal();
    final roundLabel = entry.maxRounds > 0
        ? 'R${entry.round}/${entry.maxRounds}'
        : entry.round > 0
        ? 'R${entry.round}'
        : 'R0';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _collaborationTimelineTitle(l10n, entry),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (timestamp != null)
                Text(
                  '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
                color: theme.colorScheme.onSurfaceVariant,
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
    final visibleParticipants = participants.take(3).toList();
    final extra = participants.length - visibleParticipants.length;

    if (visibleParticipants.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 34,
      width:
          26.0 * (visibleParticipants.length - 1) + 34 + (extra > 0 ? 28 : 0),
      child: Stack(
        children: [
          if (extra > 0)
            Positioned(
              left: visibleParticipants.length * 26,
              child: SizedBox(
                width: 28,
                height: 34,
                child: Center(child: Text('+$extra')),
              ),
            ),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
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

Color _collaborationStatusColor(BuildContext context, String value) {
  final semantic = AppSemanticColors.of(context);
  return switch (value) {
    'COMPLETED' => semantic.success,
    'ABORTED' => semantic.danger,
    'RUNNING' => semantic.info,
    _ => semantic.neutral,
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
