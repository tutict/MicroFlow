import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_tokens.dart';
import '../../../../shared/widgets/app_skeletons.dart';
import '../../../agent_runtime/domain/entities/agent_run.dart';
import '../../../agent_runtime/presentation/widgets/agent_run_detail_sheet.dart';
import '../../../agent_runtime/presentation/widgets/agent_run_status_chip.dart';
import '../../../workspace/domain/entities/workspace_member.dart';
import '../../domain/entities/my_work_agenda.dart';
import '../../domain/entities/task_item.dart';
import '../providers/task_queue_providers.dart';
import '../task_status_tone.dart';
import 'task_workbench_page.dart';

enum MyWorkScope { mine, allTasks }

/// Task entry point: the caller's own queue first, the whole workbench second.
///
/// The two views share one destination because both answer "what should I pick
/// up next" — a separate rail entry for each would make the user choose before
/// they know which one holds their work.
class MyWorkPage extends ConsumerStatefulWidget {
  const MyWorkPage({
    super.key,
    required this.workspaceId,
    this.members = const [],
    this.currentUserId = '',
    this.onRunAgent,
  });

  final String workspaceId;
  final List<WorkspaceMember> members;
  final String currentUserId;

  /// Null hides the "run agent" entry so the queue works without the runtime.
  final Future<void> Function(TaskItem task)? onRunAgent;

  @override
  ConsumerState<MyWorkPage> createState() => _MyWorkPageState();
}

class _MyWorkPageState extends ConsumerState<MyWorkPage> {
  MyWorkScope _scope = MyWorkScope.mine;
  MyWorkLane _lane = MyWorkLane.actionable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      key: const Key('my-work-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.destinationMyWork,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      l10n.myWorkSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('my-work-refresh'),
                tooltip: l10n.agentRunsRefresh,
                onPressed: () => ref
                    .read(taskQueueActionsProvider)
                    .refresh(widget.workspaceId),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _ScopeChip(
                key: const Key('my-work-scope-mine'),
                label: l10n.myWorkScopeMine,
                selected: _scope == MyWorkScope.mine,
                onSelected: () => setState(() => _scope = MyWorkScope.mine),
              ),
              _ScopeChip(
                key: const Key('my-work-scope-all'),
                label: l10n.myWorkScopeAll,
                selected: _scope == MyWorkScope.allTasks,
                onSelected: () => setState(() => _scope = MyWorkScope.allTasks),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: _scope == MyWorkScope.mine
              ? _MyWorkQueue(
                  workspaceId: widget.workspaceId,
                  lane: _lane,
                  onLaneSelected: (lane) => setState(() => _lane = lane),
                  onRunAgent: widget.onRunAgent,
                  onShowAllTasks: () =>
                      setState(() => _scope = MyWorkScope.allTasks),
                )
              : TaskWorkbenchView(
                  key: const Key('task-workbench'),
                  workspaceId: widget.workspaceId,
                  repository: ref.watch(taskRepositoryProvider),
                  members: widget.members,
                  currentUserId: widget.currentUserId,
                  onRunAgent: widget.onRunAgent,
                  showTitle: false,
                ),
        ),
      ],
    );
  }
}

class _MyWorkQueue extends ConsumerWidget {
  const _MyWorkQueue({
    required this.workspaceId,
    required this.lane,
    required this.onLaneSelected,
    required this.onShowAllTasks,
    this.onRunAgent,
  });

  final String workspaceId;
  final MyWorkLane lane;
  final ValueChanged<MyWorkLane> onLaneSelected;
  final VoidCallback onShowAllTasks;
  final Future<void> Function(TaskItem task)? onRunAgent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final agenda = ref.watch(myWorkAgendaProvider(workspaceId));
    // A failing run list must not hide the queue: the badge is decoration.
    final runs =
        ref.watch(taskRunIndexProvider(workspaceId)).asData?.value ??
        const <String, AgentRunSummary>{};

    return agenda.when(
      loading: () => const AccountingDashboardSkeleton(),
      error: (error, _) => _QueueError(
        message: '$error',
        onRetry: () => ref.read(taskQueueActionsProvider).refresh(workspaceId),
      ),
      data: (data) {
        final tasks = data.tasksFor(lane);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 640 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                    return PopupMenuButton<MyWorkLane>(
                      key: const Key('my-work-lane-menu'),
                      tooltip: l10n.chooseTaskGroup,
                      onSelected: onLaneSelected,
                      itemBuilder: (context) => [
                        for (final candidate in MyWorkLane.values)
                          PopupMenuItem(
                            key: Key('my-work-lane-${candidate.name}'),
                            value: candidate,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_laneLabel(l10n, candidate)} · ${data.countFor(candidate)}',
                                  ),
                                ),
                                if (candidate == lane)
                                  const Icon(Icons.check_rounded, size: 18),
                              ],
                            ),
                          ),
                      ],
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(AppRadii.small),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_laneLabel(l10n, lane)} · ${data.countFor(lane)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                const Icon(Icons.expand_more_rounded, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final candidate in MyWorkLane.values)
                        _LaneChip(
                          key: Key('my-work-lane-${candidate.name}'),
                          label: _laneLabel(l10n, candidate),
                          count: data.countFor(candidate),
                          selected: candidate == lane,
                          onSelected: () => onLaneSelected(candidate),
                        ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? _QueueEmpty(
                      agendaIsEmpty: data.isEmpty,
                      onShowAllTasks: onShowAllTasks,
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref
                          .read(taskQueueActionsProvider)
                          .refresh(workspaceId),
                      child: ListView.separated(
                        key: const Key('my-work-list'),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: tasks.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _MyWorkRow(
                            key: ValueKey((workspaceId, task.id)),
                            task: task,
                            run: runs[task.id],
                            onRunAgent: onRunAgent == null
                                ? null
                                : () => onRunAgent!(task),
                            onStatus: (status) => ref
                                .read(taskQueueActionsProvider)
                                .setStatus(
                                  workspaceId: workspaceId,
                                  taskId: task.id,
                                  status: status,
                                ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

String _laneLabel(AppLocalizations l10n, MyWorkLane lane) {
  return switch (lane) {
    MyWorkLane.actionable => l10n.myWorkLaneActionable,
    MyWorkLane.blocked => l10n.myWorkLaneBlocked,
    MyWorkLane.awaitingOthers => l10n.myWorkLaneAwaitingOthers,
    MyWorkLane.recentlyDone => l10n.myWorkLaneRecentlyDone,
    MyWorkLane.running => l10n.myWorkLaneRunning,
    MyWorkLane.waitingApproval => l10n.myWorkLaneWaitingApproval,
  };
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _LaneChip extends StatelessWidget {
  const _LaneChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      selected: selected,
      child: TextButton(
        onPressed: onSelected,
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          backgroundColor: selected ? theme.colorScheme.primaryContainer : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
          ),
        ),
        child: Text('$label · $count'),
      ),
    );
  }
}

class _MyWorkRow extends StatefulWidget {
  const _MyWorkRow({
    super.key,
    required this.task,
    required this.onStatus,
    this.run,
    this.onRunAgent,
  });

  final TaskItem task;
  final AgentRunSummary? run;
  final Future<void> Function()? onRunAgent;
  final Future<void> Function(String) onStatus;

  @override
  State<_MyWorkRow> createState() => _MyWorkRowState();
}

class _MyWorkRowState extends State<_MyWorkRow> {
  bool _pending = false;
  bool _starting = false;
  String? _error;

  Future<void> _select(String value) async {
    if (!mounted || _pending) return;
    setState(() {
      _pending = true;
      _starting = value == 'RUN_AGENT';
      _error = null;
    });
    try {
      if (value == 'RUN_AGENT') {
        await widget.onRunAgent?.call();
      } else {
        await widget.onStatus(value);
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() {
          _pending = false;
          _starting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final task = widget.task;
    final run = widget.run;
    return Semantics(
      container: true,
      label: task.title,
      child: DecoratedBox(
        decoration: BoxDecoration(color: theme.colorScheme.surface),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: AppSpacing.xxs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TaskStatusBadge(task: task),
                        if (task.projectName != null)
                          Text(
                            task.projectName!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        if (task.dueAt != null) _DueLabel(task: task),
                      ],
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        key: Key('my-work-action-error-${task.id}'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              if (run != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Tooltip(
                    message: l10n.myWorkRunTooltip,
                    child: InkWell(
                      key: Key('my-work-run-${task.id}'),
                      borderRadius: BorderRadius.circular(AppRadii.small),
                      onTap: () => showAgentRunDetailSheet(context, run.id),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 44,
                          minWidth: 44,
                        ),
                        child: Center(
                          widthFactor: 1,
                          heightFactor: 1,
                          child: AgentRunStatusChip(status: run.status),
                        ),
                      ),
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: _starting
                    ? l10n.taskRunPending
                    : l10n.taskChangeStatusAction,
                enabled: !_pending,
                icon: _starting ? const Icon(Icons.hourglass_empty) : null,
                onSelected: _select,
                itemBuilder: (context) => [
                  if (task.status == 'OPEN')
                    PopupMenuItem(
                      value: 'IN_PROGRESS',
                      child: Text(
                        l10n.taskStatusInProgress,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  if (task.status != 'BLOCKED')
                    PopupMenuItem(
                      value: 'BLOCKED',
                      child: Text(
                        l10n.taskStatusBlocked,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  if (!task.isDone)
                    PopupMenuItem(
                      value: 'DONE',
                      child: Text(
                        l10n.taskStatusDone,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  if (widget.onRunAgent != null)
                    PopupMenuItem(
                      value: 'RUN_AGENT',
                      key: Key('my-work-run-agent-${task.id}'),
                      child: Text(l10n.taskRunAgentAction),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueLabel extends StatelessWidget {
  const _DueLabel({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final due = task.dueAt!;
    final date =
        '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
    if (task.isOverdue) {
      return Text(
        l10n.myWorkOverdue,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Text(
      l10n.myWorkDueOn(date),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _QueueEmpty extends StatelessWidget {
  const _QueueEmpty({
    required this.agendaIsEmpty,
    required this.onShowAllTasks,
  });

  final bool agendaIsEmpty;
  final VoidCallback onShowAllTasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      key: const Key('my-work-empty'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              agendaIsEmpty ? Icons.check_circle_outline : Icons.inbox_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              agendaIsEmpty ? l10n.myWorkEmptyTitle : l10n.myWorkLaneEmpty,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (agendaIsEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.myWorkEmptyDescription,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.tonal(
                key: const Key('my-work-browse-all'),
                onPressed: onShowAllTasks,
                child: Text(l10n.myWorkScopeAll),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QueueError extends StatelessWidget {
  const _QueueError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      key: const Key('my-work-error'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 36),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.myWorkErrorTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              key: const Key('my-work-retry'),
              onPressed: onRetry,
              child: Text(l10n.retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
