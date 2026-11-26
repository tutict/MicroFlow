import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/agent_run.dart';
import 'agent_run_detail_providers.dart';
import 'agent_runtime_repository_provider.dart';
import 'agent_read_error_provider.dart';

final agentWorkspaceRunsProvider = AsyncNotifierProvider.autoDispose
    .family<AgentWorkspaceRunsController, List<AgentRunSummary>, String>(
      AgentWorkspaceRunsController.new,
    );

/// Recent history and complete active coverage share one workspace cache.
class AgentWorkspaceRunsController
    extends AsyncNotifier<List<AgentRunSummary>> {
  AgentWorkspaceRunsController(this.workspaceId);
  final String workspaceId;
  final _updatesDuringFetch = <String, AgentRunSummary>{};
  int _fetchGeneration = 0;
  bool _fetching = false;
  Future<void>? _activeRefresh;

  @override
  Future<List<AgentRunSummary>> build() {
    ref.watch(agentRuntimeRepositoryProvider);
    return _fetch();
  }

  Future<List<AgentRunSummary>> _fetch() async {
    final generation = ++_fetchGeneration;
    _fetching = true;
    try {
      final repository = ref.read(agentRuntimeRepositoryProvider);
      final groups = await Future.wait([
        repository.listRuns(workspaceId: workspaceId),
        repository.listActiveRuns(workspaceId: workspaceId),
      ]);
      final items = mergeAgentRunSnapshots([
        ...groups[0],
        ...groups[1],
        ..._updatesDuringFetch.values,
      ]);
      if (!ref.mounted) return items;
      if (generation == _fetchGeneration) {
        _setError(null);
        _updatesDuringFetch.clear();
      }
      return generation == _fetchGeneration ? items : state.value ?? items;
    } finally {
      if (generation == _fetchGeneration) _fetching = false;
    }
  }

  void upsert(AgentRunSummary run) => upsertAll([run]);
  void upsertAll(Iterable<AgentRunSummary> incoming) {
    if (!ref.mounted) return;
    final updates = incoming
        .where((run) => run.workspaceId == workspaceId)
        .toList();
    if (_fetching) {
      final pending = mergeAgentRunSnapshots([
        ..._updatesDuringFetch.values,
        ...updates,
      ]);
      _updatesDuringFetch.clear();
      _updatesDuringFetch.addEntries(
        pending.map((run) => MapEntry(run.id, run)),
      );
    }
    final current = state.value;
    if (current != null) {
      state = AsyncData(mergeAgentRunSnapshots([...current, ...updates]));
    }
  }

  Future<void> refresh() async {
    final request = _fetch();
    final generation = _fetchGeneration;
    try {
      final items = await request;
      if (ref.mounted && generation == _fetchGeneration) {
        state = AsyncData(items);
        ref
            .read(agentRunHistoryRevisionProvider(workspaceId).notifier)
            .changed();
      }
    } catch (error, stack) {
      if (ref.mounted && generation == _fetchGeneration) {
        _setError(error);
        final current = state.value;
        state = current == null ? AsyncError(error, stack) : AsyncData(current);
      }
    }
  }

  Future<void> refreshActive({String? taskId}) {
    final pending = _activeRefresh;
    if (pending != null) return pending;
    late final Future<void> next;
    next = _refreshActive(taskId).whenComplete(() {
      if (identical(_activeRefresh, next)) _activeRefresh = null;
    });
    _activeRefresh = next;
    return next;
  }

  Future<void> _refreshActive(String? taskId) async {
    final active =
        state.value
            ?.where(
              (run) =>
                  run.status.isActive &&
                  (taskId == null || run.taskId == taskId),
            )
            .toList() ??
        const <AgentRunSummary>[];
    final repository = ref.read(agentRuntimeRepositoryProvider);
    for (final run in active) {
      try {
        final updated = await repository.getRun(run.id);
        if (!ref.mounted) return;
        upsert(updated);
        ref.invalidate(agentRunProvider(updated.id));
        ref.invalidate(agentRunStepsProvider(updated.id));
        ref.invalidate(agentRunApprovalsProvider(updated.id));
        ref.invalidate(agentRunContextSourcesProvider(updated.id));
        ref.invalidate(agentRunArtifactsProvider(updated.id));
        if (updated.taskId != null && updated.status != run.status) {
          ref
              .read(agentTaskQueueRevisionProvider(workspaceId).notifier)
              .changed();
        }
      } catch (error, stack) {
        if (ref.mounted) {
          _setError(error);
          final current = state.value;
          state = current == null
              ? AsyncError(error, stack)
              : AsyncData(current);
        }
        return;
      }
    }
  }

  void _setError(Object? error) => ref
      .read(
        agentReadErrorProvider((
          resource: AgentReadResource.runs,
          id: workspaceId,
        )).notifier,
      )
      .setError(error);
}

List<AgentRunSummary> mergeAgentRunSnapshots(Iterable<AgentRunSummary> runs) {
  final byId = <String, AgentRunSummary>{};
  for (final incoming in runs) {
    final existing = byId[incoming.id];
    final existingAt = DateTime.tryParse(existing?.updatedAt ?? '');
    final incomingAt = DateTime.tryParse(incoming.updatedAt ?? '');
    if (existingAt != null &&
        incomingAt != null &&
        incomingAt.isBefore(existingAt)) {
      continue;
    }
    byId[incoming.id] = incoming;
  }
  final items = byId.values.toList()
    ..sort((left, right) {
      final rank = _runRank(left.status).compareTo(_runRank(right.status));
      return rank != 0
          ? rank
          : (right.createdAt ?? '').compareTo(left.createdAt ?? '');
    });
  return List.unmodifiable(items);
}

int _runRank(AgentRunStatus status) => switch (status) {
  AgentRunStatus.waitingApproval => 0,
  AgentRunStatus.running || AgentRunStatus.contextBuilding => 1,
  AgentRunStatus.queued => 2,
  AgentRunStatus.failed => 3,
  _ => 4,
};

final agentRunHistoryRevisionProvider =
    NotifierProvider.family<AgentRunHistoryRevision, int, String>(
      AgentRunHistoryRevision.new,
    );

class AgentRunHistoryRevision extends Notifier<int> {
  AgentRunHistoryRevision(this.workspaceId);
  final String workspaceId;
  @override
  int build() {
    ref.watch(agentRuntimeRepositoryProvider);
    return 0;
  }

  void changed() => state++;
}

final agentTaskQueueRevisionProvider =
    NotifierProvider.family<AgentTaskQueueRevision, int, String>(
      AgentTaskQueueRevision.new,
    );

class AgentTaskQueueRevision extends Notifier<int> {
  AgentTaskQueueRevision(this.workspaceId);
  final String workspaceId;
  @override
  int build() {
    ref.watch(agentRuntimeRepositoryProvider);
    return 0;
  }

  void changed() => state++;
}
