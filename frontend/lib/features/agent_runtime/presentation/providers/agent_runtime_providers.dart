import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/agent_run.dart';
import '../../domain/repositories/agent_runtime_repository.dart';
import '../../../auth/presentation/providers/auth_session_controller.dart';
import 'agent_run_detail_providers.dart';
import 'agent_run_events_controller.dart';
import 'agent_run_list_controller.dart';
import 'agent_runtime_repository_provider.dart';

export 'agent_run_list_controller.dart';
export 'agent_run_detail_providers.dart';
export 'agent_run_events_controller.dart';
export 'agent_runtime_repository_provider.dart';
export 'agent_runtime_sync.dart';
export 'agent_read_error_provider.dart';

/// Query key for the run list. A record gives value equality for free, which is
/// what Riverpod family caching needs.
typedef AgentRunsQuery = ({String workspaceId, String? taskId});

final agentTaskRunHistoryProvider = FutureProvider.autoDispose
    .family<List<AgentRunSummary>, AgentRunsQuery>((ref, query) async {
      if (query.taskId == null) {
        throw ArgumentError('Task history requires a task id');
      }
      ref.watch(agentRunHistoryRevisionProvider(query.workspaceId));
      final runs = await ref
          .watch(agentRuntimeRepositoryProvider)
          .listRuns(workspaceId: query.workspaceId, taskId: query.taskId);
      if (ref.mounted &&
          ref.exists(agentWorkspaceRunsProvider(query.workspaceId))) {
        ref
            .read(agentWorkspaceRunsProvider(query.workspaceId).notifier)
            .upsertAll(runs);
      }
      return runs;
    });

final agentRunsProvider = FutureProvider.autoDispose
    .family<List<AgentRunSummary>, AgentRunsQuery>((ref, query) async {
      final runs = await ref.watch(
        agentWorkspaceRunsProvider(query.workspaceId).future,
      );
      if (query.taskId == null) return runs;
      final history = await ref.watch(
        agentTaskRunHistoryProvider(query).future,
      );
      return mergeAgentRunSnapshots([
        ...history,
        ...runs.where((run) => run.taskId == query.taskId),
      ]);
    });

/// Mutations go through one object so every screen invalidates the same keys.
class AgentRunActions {
  AgentRunActions(this._ref, this._startRepository);

  final Ref _ref;
  final AgentRuntimeRepository _startRepository;
  final _pendingStarts = <(String, String), Future<AgentRunSummary>>{};
  bool _active = true;

  Future<void> decide({
    required String runId,
    required String approvalId,
    required bool approve,
    String? note,
  }) async {
    await _ref
        .read(agentRuntimeRepositoryProvider)
        .decideApproval(
          runId: runId,
          approvalId: approvalId,
          approve: approve,
          note: note,
        );
    final run = await _ref.read(agentRuntimeRepositoryProvider).getRun(runId);
    _applyRun(run);
  }

  Future<void> cancel(String runId) async {
    final run = await _ref
        .read(agentRuntimeRepositoryProvider)
        .cancelRun(runId);
    _applyRun(run);
  }

  Future<void> retry(String runId) async {
    final run = await _ref.read(agentRuntimeRepositoryProvider).retryRun(runId);
    _applyRun(run);
  }

  Future<AgentRunSummary> startOnTask({
    required String workspaceId,
    required String taskId,
    String? agentKey,
    String? goal,
  }) {
    final key = (workspaceId, taskId);
    final pending = _pendingStarts[key];
    if (pending != null) return pending;
    // Register before dispatch so every entry point joins the same HTTP write.
    // Each actions instance belongs to one repository/session lifecycle.
    final operation = Future<AgentRunSummary>.microtask(() async {
      try {
        if (!_active) throw StateError('Session changed; please retry');
        final run = await _startRepository.startTaskRun(
          workspaceId: workspaceId,
          taskId: taskId,
          agentKey: agentKey,
          goal: goal,
        );
        if (_active) _applyRun(run);
        return run;
      } finally {
        _pendingStarts.remove(key);
      }
    });
    _pendingStarts[key] = operation;
    return operation;
  }

  void _applyRun(AgentRunSummary run) {
    if (!_ref.mounted) return;
    if (_ref.exists(agentWorkspaceRunsProvider(run.workspaceId))) {
      _ref
          .read(agentWorkspaceRunsProvider(run.workspaceId).notifier)
          .upsert(run);
    }
    _ref.invalidate(agentRunProvider(run.id));
    _ref.invalidate(agentRunStepsProvider(run.id));
    _ref.invalidate(agentRunApprovalsProvider(run.id));
    _ref.invalidate(agentRunArtifactsProvider(run.id));
    _ref.invalidate(agentRunEventsProvider(run.id));
    if (run.taskId != null) {
      _ref
          .read(agentTaskQueueRevisionProvider(run.workspaceId).notifier)
          .changed();
    }
  }
}

final agentRunActionsProvider = Provider<AgentRunActions>((ref) {
  final repository = ref.watch(agentRuntimeRepositoryProvider);
  ref.watch(
    authSessionControllerProvider.select(
      (state) =>
          (state.asData?.value?.userId, state.asData?.value?.accessToken),
    ),
  );
  final actions = AgentRunActions(ref, repository);
  ref.onDispose(() => actions._active = false);
  return actions;
});
