import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../agent_runtime/domain/entities/agent_run.dart';
import '../../../agent_runtime/presentation/providers/agent_runtime_providers.dart';
import '../../domain/entities/my_work_agenda.dart';

/// The queue behind the "my work" destination.
///
/// Kept separate from [AgentRunsQuery] state so a status change on one task
/// refetches the queue without touching the execution panel.
final myWorkAgendaProvider = FutureProvider.autoDispose
    .family<MyWorkAgenda, String>((ref, workspaceId) {
      ref.watch(agentTaskQueueRevisionProvider(workspaceId));
      return ref.watch(taskRepositoryProvider).myWork(workspaceId: workspaceId);
    });

/// taskId -> the most relevant run for that task.
///
/// The agenda only needs "is there a run, and how did it end", so the whole
/// workspace run list is folded into a map instead of one request per task.
final taskRunIndexProvider = FutureProvider.autoDispose
    .family<Map<String, AgentRunSummary>, String>((ref, workspaceId) async {
      final runs = await ref.watch(
        agentRunsProvider((workspaceId: workspaceId, taskId: null)).future,
      );
      final index = <String, AgentRunSummary>{};
      for (final run in runs) {
        final taskId = run.taskId;
        if (taskId == null || taskId.isEmpty) {
          continue;
        }
        final current = index[taskId];
        if (current == null || _shouldReplace(current, run)) {
          index[taskId] = run;
        }
      }
      return index;
    });

/// A live run outranks a finished one: the queue is about what is happening now.
bool _shouldReplace(AgentRunSummary current, AgentRunSummary candidate) {
  if ((current.status == AgentRunStatus.waitingApproval) !=
      (candidate.status == AgentRunStatus.waitingApproval)) {
    return candidate.status == AgentRunStatus.waitingApproval;
  }
  if (current.status.isActive != candidate.status.isActive) {
    return candidate.status.isActive;
  }
  return _recency(candidate) > _recency(current);
}

int _recency(AgentRunSummary run) {
  return DateTime.tryParse(run.createdAt ?? '')?.millisecondsSinceEpoch ?? 0;
}

class TaskQueueActions {
  TaskQueueActions(this._ref);

  final Ref _ref;
  final _pendingStatuses = <(String, String), Future<void>>{};

  Future<void> setStatus({
    required String workspaceId,
    required String taskId,
    required String status,
  }) {
    final key = (workspaceId, taskId);
    final pending = _pendingStatuses[key];
    if (pending != null) return pending;
    final repository = _ref.read(taskRepositoryProvider);
    // Keep the write shared even if a row disappears during a lane switch or
    // refresh. Schedule it after registration so every failure releases it.
    final operation = Future<void>.microtask(() async {
      try {
        await repository.updateStatus(
          workspaceId: workspaceId,
          taskId: taskId,
          status: status,
        );
        if (_ref.mounted) _ref.invalidate(myWorkAgendaProvider(workspaceId));
      } finally {
        _pendingStatuses.remove(key);
      }
    });
    _pendingStatuses[key] = operation;
    return operation;
  }

  /// Manual refresh: both halves of the queue view, because a run may have
  /// advanced without the client hearing about it.
  void refresh(String workspaceId) {
    _ref.invalidate(myWorkAgendaProvider(workspaceId));
    if (_ref.exists(agentWorkspaceRunsProvider(workspaceId))) {
      _ref.read(agentWorkspaceRunsProvider(workspaceId).notifier).refresh();
    }
  }
}

final taskQueueActionsProvider = Provider<TaskQueueActions>((ref) {
  return TaskQueueActions(ref);
});
