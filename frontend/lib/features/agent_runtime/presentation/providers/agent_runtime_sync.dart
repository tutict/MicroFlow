import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/dto/agent_run_dto.dart';
import '../../domain/entities/agent_run.dart';
import '../../domain/entities/agent_run_event.dart';
import 'agent_run_detail_providers.dart';
import 'agent_run_events_controller.dart';
import 'agent_run_list_controller.dart';
import 'agent_runtime_repository_provider.dart';

final agentRuntimeConnectedProvider =
    NotifierProvider<AgentRuntimeConnection, bool>(AgentRuntimeConnection.new);

class AgentRuntimeConnection extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(agentRuntimeRepositoryProvider);
    return false;
  }

  void setConnected(bool connected) => state = connected;
}

final agentRuntimeSyncProvider = Provider<AgentRuntimeSync>((ref) {
  ref.watch(agentRuntimeRepositoryProvider);
  return AgentRuntimeSync(ref);
});

/// Serial delivery per run deduplicates the channel and initiator subscriptions.
class AgentRuntimeSync {
  AgentRuntimeSync(this._ref);
  final Ref _ref;
  final _seen = <({String workspaceId, String runId}), int>{};
  final _pending = <({String workspaceId, String runId}), Future<void>>{};

  Future<void> receive(Map<String, Object?> payload) async {
    final workspaceId = payload['workspaceId'];
    final runId = payload['runId'];
    final seq = payload['seq'];
    if (workspaceId is! String ||
        workspaceId.isEmpty ||
        runId is! String ||
        runId.isEmpty ||
        seq is! num ||
        seq.toInt() <= 0) {
      return;
    }
    final key = (workspaceId: workspaceId, runId: runId);
    final next = (_pending[key] ?? Future.value())
        .catchError((Object _) {})
        .then((_) => _receive(key, seq.toInt(), payload));
    _pending[key] = next;
    try {
      await next;
    } finally {
      if (identical(_pending[key], next)) _pending.remove(key);
    }
  }

  Future<void> _receive(
    ({String workspaceId, String runId}) key,
    int seq,
    Map<String, Object?> payload,
  ) async {
    if (!_ref.mounted || seq <= (_seen[key] ?? 0)) return;
    final raw = payload['run'];
    final run = raw is Map
        ? AgentRunDto.fromJson(Map<String, Object?>.from(raw)).toDomain()
        : await _ref.read(agentRuntimeRepositoryProvider).getRun(key.runId);
    if (!_ref.mounted ||
        run.workspaceId != key.workspaceId ||
        run.id != key.runId) {
      return;
    }
    final hasGap = seq > (_seen[key] ?? 0) + 1;
    final listProvider = agentWorkspaceRunsProvider(key.workspaceId);
    AgentRunSummary? previous;
    if (_ref.exists(listProvider)) {
      for (final item
          in _ref.read(listProvider).value ?? const <AgentRunSummary>[]) {
        if (item.id == key.runId) previous = item;
      }
      _ref.read(listProvider.notifier).upsert(run);
    }
    _seen[key] = seq;
    final type = payload['type'] as String? ?? '';
    _ref.invalidate(agentRunProvider(key.runId));
    if (hasGap ||
        type.startsWith('MODEL_TURN_') ||
        type.startsWith('TOOL_') ||
        type.startsWith('APPROVAL_')) {
      _ref.invalidate(agentRunStepsProvider(key.runId));
    }
    if (hasGap || type.startsWith('APPROVAL_') || type == 'RUN_CANCELLED') {
      _ref.invalidate(agentRunApprovalsProvider(key.runId));
    }
    if (hasGap ||
        type == 'ARTIFACT_CREATED' ||
        (type == 'TOOL_COMPLETED' && payload['toolKey'] == 'artifact.create')) {
      _ref.invalidate(agentRunArtifactsProvider(key.runId));
    }
    if (hasGap ||
        type == 'RUN_CONTEXT_READY' ||
        type == 'RUN_RETRY_REQUESTED') {
      _ref.invalidate(agentRunContextSourcesProvider(key.runId));
    }
    if (run.taskId != null &&
        (previous?.status != run.status ||
            (type == 'TOOL_COMPLETED' &&
                payload['toolKey'] == 'task.update_status'))) {
      _ref
          .read(agentTaskQueueRevisionProvider(key.workspaceId).notifier)
          .changed();
    }
    if (_ref.exists(agentRunEventsProvider(key.runId))) {
      await _ref
          .read(agentRunEventsProvider(key.runId).notifier)
          .accept(AgentRunEvent.fromSocket(payload));
      if (_ref.mounted && _ref.exists(agentRunEventsProvider(key.runId))) {
        final trail = _ref.read(agentRunEventsProvider(key.runId)).value;
        await _applyHistoryHead(key, trail);
      }
    }
  }

  Future<void> _applyHistoryHead(
    ({String workspaceId, String runId}) key,
    List<AgentRunEvent>? trail,
  ) async {
    if (trail == null || trail.isEmpty || trail.last.seq <= (_seen[key] ?? 0)) {
      return;
    }
    final latest = trail.last;
    await _receive(key, latest.seq, {...latest.payload, 'type': latest.type});
  }

  Future<void> reconnect(String workspaceId) async {
    final listProvider = agentWorkspaceRunsProvider(workspaceId);
    final ids = {
      for (final key in _seen.keys)
        if (key.workspaceId == workspaceId) key.runId,
    };
    if (_ref.exists(listProvider)) {
      ids.addAll(
        (_ref.read(listProvider).value ?? const <AgentRunSummary>[]).map(
          (run) => run.id,
        ),
      );
      await _ref.read(listProvider.notifier).refresh();
      if (!_ref.mounted) return;
      ids.addAll(
        (_ref.read(listProvider).value ?? const <AgentRunSummary>[]).map(
          (run) => run.id,
        ),
      );
    }
    for (final id in ids) {
      if (!_ref.mounted) return;
      if (_ref.exists(agentRunEventsProvider(id))) {
        await _ref.read(agentRunEventsProvider(id).notifier).catchUp();
      }
      if (!_ref.mounted) return;
      if (_ref.exists(agentRunEventsProvider(id))) {
        final trail = _ref.read(agentRunEventsProvider(id)).value;
        final key = (workspaceId: workspaceId, runId: id);
        await _applyHistoryHead(key, trail);
      }
      _ref.invalidate(agentRunProvider(id));
      _ref.invalidate(agentRunStepsProvider(id));
      _ref.invalidate(agentRunApprovalsProvider(id));
      _ref.invalidate(agentRunArtifactsProvider(id));
      _ref.invalidate(agentRunContextSourcesProvider(id));
    }
    if (_ref.mounted) {
      _ref.read(agentTaskQueueRevisionProvider(workspaceId).notifier).changed();
    }
  }
}
