import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_approval.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_artifact.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_context_source.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_run.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_run_event.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_run_step.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/repositories/agent_runtime_repository.dart';

class RecordingRuntimeRepository implements AgentRuntimeRepository {
  RecordingRuntimeRepository({this.runs = const [], this.runToStart});

  List<AgentRunSummary> runs;
  AgentRunSummary? runToStart;
  final events = <String, List<AgentRunEvent>>{};
  final listQueries = <({String workspaceId, String? taskId})>[];
  final listResponses = <Future<List<AgentRunSummary>>>[];
  final activeQueries = <String>[];
  final getQueries = <String>[];
  final eventQueries = <({String runId, int afterSeq, int limit})>[];
  int? failEventsAfter;
  final approvals = <AgentApproval>[];
  final stepRecords = <Map<String, Object?>>[];
  bool failSteps = false;
  Object? controlError;

  @override
  Future<List<AgentRunSummary>> listRuns({
    required String workspaceId,
    String? taskId,
  }) async {
    listQueries.add((workspaceId: workspaceId, taskId: taskId));
    if (listResponses.isNotEmpty) return listResponses.removeAt(0);
    return runs
        .where(
          (run) =>
              run.workspaceId == workspaceId &&
              (taskId == null || run.taskId == taskId),
        )
        .take(50)
        .toList();
  }

  @override
  Future<List<AgentRunSummary>> listActiveRuns({
    required String workspaceId,
  }) async {
    activeQueries.add(workspaceId);
    return runs
        .where((run) => run.workspaceId == workspaceId && run.status.isActive)
        .toList();
  }

  @override
  Future<AgentRunSummary> getRun(String runId) async {
    getQueries.add(runId);
    return runs.firstWhere((run) => run.id == runId);
  }

  @override
  Future<List<AgentRunStep>> listSteps(String runId) async {
    if (failSteps) throw StateError('Step service disconnected');
    return stepRecords.map(AgentRunStep.fromJson).toList();
  }

  @override
  Future<List<AgentRunEvent>> listEvents(
    String runId, {
    int afterSeq = 0,
    int limit = 200,
  }) async {
    eventQueries.add((runId: runId, afterSeq: afterSeq, limit: limit));
    if (failEventsAfter != null && afterSeq >= failEventsAfter!) {
      throw StateError('Event service disconnected');
    }
    return (events[runId] ?? [])
        .where((event) => event.seq > afterSeq)
        .take(limit)
        .toList();
  }

  @override
  Future<List<AgentApproval>> listApprovals(
    String runId, {
    String? status,
  }) async => approvals.where((approval) => approval.runId == runId).toList();

  @override
  Future<List<AgentContextSource>> listContextSources(String runId) async =>
      const [];

  @override
  Future<List<AgentArtifact>> listArtifacts(String runId) async => const [];

  @override
  Future<AgentRunSummary> startTaskRun({
    required String workspaceId,
    required String taskId,
    String? agentKey,
    String? goal,
  }) async => runToStart!;

  @override
  Future<AgentApproval> decideApproval({
    required String runId,
    required String approvalId,
    required bool approve,
    String? note,
  }) async => AgentApproval(
    id: approvalId,
    runId: runId,
    toolKey: 'task.update_status',
    action: 'Update task',
    riskLevel: 'INTERNAL_WRITE',
    status: approve
        ? AgentApprovalStatus.approved
        : AgentApprovalStatus.rejected,
  );

  @override
  Future<AgentRunSummary> cancelRun(String runId) async {
    if (controlError != null) throw controlError!;
    return getRun(runId);
  }

  @override
  Future<AgentRunSummary> retryRun(String runId) async => getRun(runId);
}

AgentRunSummary testRun({
  String id = 'run_1',
  String workspaceId = 'ws_1',
  String taskId = 'task_1',
  AgentRunStatus status = AgentRunStatus.queued,
  String? createdAt,
  String? updatedAt,
  String? goal,
}) => AgentRunSummary(
  id: id,
  workspaceId: workspaceId,
  taskId: taskId,
  agentKey: 'assistant',
  kind: 'TASK',
  goal: goal ?? '$workspaceId/$taskId',
  status: status,
  pendingApprovalId: status == AgentRunStatus.waitingApproval
      ? 'apr_$id'
      : null,
  createdAt: createdAt ?? '2026-11-23T10:00:00Z',
  updatedAt: updatedAt ?? '2026-11-23T10:00:00Z',
);
