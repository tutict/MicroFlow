import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_theme_extensions.dart';
import '../../../../shared/theme/app_tokens.dart';
import '../../domain/entities/agent_run.dart';
import '../providers/agent_runtime_providers.dart';
import 'agent_run_card.dart';

/// Execution view of the inspector.
///
/// Polls only while a run is active. Idle workspaces cost nothing, and a run
/// that reaches a terminal state stops the timer on the next tick.
class AgentExecutionPanel extends ConsumerStatefulWidget {
  const AgentExecutionPanel({
    super.key,
    required this.workspaceId,
    this.taskId,
    this.title,
  });

  final String workspaceId;
  final String? taskId;
  final String? title;

  @override
  ConsumerState<AgentExecutionPanel> createState() =>
      _AgentExecutionPanelState();
}

class _AgentExecutionPanelState extends ConsumerState<AgentExecutionPanel> {
  static const _pollInterval = Duration(seconds: 3);

  AgentRunsQuery get _query =>
      (workspaceId: widget.workspaceId, taskId: widget.taskId);
  Timer? _poller;

  void _configurePolling(bool needed) {
    if (!needed) {
      _poller?.cancel();
      _poller = null;
      return;
    }
    _poller ??= Timer.periodic(_pollInterval, (_) {
      if (mounted && !ref.read(agentRuntimeConnectedProvider)) {
        ref
            .read(agentWorkspaceRunsProvider(widget.workspaceId).notifier)
            .refreshActive(taskId: widget.taskId);
      }
    });
  }

  @override
  void didUpdateWidget(covariant AgentExecutionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.taskId != widget.taskId) {
      _configurePolling(false);
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final semantic = AppSemanticColors.of(context);
    final runs = ref.watch(agentRunsProvider(_query));
    final connected = ref.watch(agentRuntimeConnectedProvider);
    final readError = ref.watch(
      agentReadErrorProvider((
        resource: AgentReadResource.runs,
        id: widget.workspaceId,
      )),
    );
    final active = runs.value?.any((run) => run.status.isActive) ?? false;
    _configurePolling(
      active && !connected && !runs.hasError && readError == null,
    );

    return RefreshIndicator(
      onRefresh: () => ref
          .read(agentWorkspaceRunsProvider(widget.workspaceId).notifier)
          .refresh(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title ?? l10n.agentRunsTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                key: const Key('agent-runs-refresh'),
                tooltip: l10n.agentRunsRefresh,
                visualDensity: VisualDensity.compact,
                onPressed: () => ref
                    .read(
                      agentWorkspaceRunsProvider(widget.workspaceId).notifier,
                    )
                    .refresh(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          if (readError != null && runs.hasValue)
            Semantics(
              liveRegion: true,
              child: Text(
                readError.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: semantic.danger,
                ),
              ),
            ),
          if (!connected && active)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.agentRunsOfflineStatus,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          runs.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: LinearProgressIndicator(),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                error.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: semantic.danger,
                ),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text(
                    l10n.agentRunsEmpty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              final ordered = [...items]
                ..sort((left, right) {
                  final leftPriority = _priority(left.status);
                  final rightPriority = _priority(right.status);
                  if (leftPriority != rightPriority) {
                    return leftPriority.compareTo(rightPriority);
                  }
                  return (right.createdAt ?? '').compareTo(
                    left.createdAt ?? '',
                  );
                });
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final run in ordered)
                    AgentRunCard(key: ValueKey(run.id), run: run),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Waiting approvals first: that is the only bucket that blocks a human.
  int _priority(AgentRunStatus status) {
    return switch (status) {
      AgentRunStatus.waitingApproval => 0,
      AgentRunStatus.running || AgentRunStatus.contextBuilding => 1,
      AgentRunStatus.queued => 2,
      AgentRunStatus.failed => 3,
      _ => 4,
    };
  }
}
