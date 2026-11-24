import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/rest_client.dart';
import '../../domain/entities/agent_approval.dart';
import '../../domain/entities/agent_artifact.dart';
import '../../domain/entities/agent_context_source.dart';
import '../../domain/entities/agent_run.dart';
import '../../domain/entities/agent_run_event.dart';
import '../../domain/entities/agent_run_step.dart';
import '../../domain/repositories/agent_runtime_repository.dart';
import '../dto/agent_approval_dto.dart';
import '../dto/agent_artifact_dto.dart';
import '../dto/agent_context_source_dto.dart';
import '../dto/agent_run_dto.dart';

class AgentRuntimeRepositoryImpl implements AgentRuntimeRepository {
  const AgentRuntimeRepositoryImpl(this._restClient);

  final RestClient _restClient;

  @override
  Future<List<AgentRunSummary>> listRuns({
    required String workspaceId,
    String? taskId,
  }) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.workspaceAgentRuns(workspaceId),
      queryParameters: {
        if (taskId != null && taskId.isNotEmpty) 'taskId': taskId,
      },
    );
    return response
        .map((json) => AgentRunDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<AgentRunSummary> getRun(String runId) async {
    final response = await _restClient.getJson(ApiEndpoints.agentRun(runId));
    return AgentRunDto.fromJson(response).toDomain();
  }

  @override
  Future<List<AgentRunSummary>> listActiveRuns({
    required String workspaceId,
  }) async {
    final runs = <AgentRunSummary>[];
    String? afterId;
    while (true) {
      final page = await _restClient.getJsonList(
        ApiEndpoints.workspaceAgentRuns(workspaceId),
        queryParameters: {
          'activeOnly': 'true',
          'limit': '200',
          'afterId': ?afterId,
        },
      );
      if (page.isEmpty) break;
      final items = page
          .map((row) => AgentRunDto.fromJson(row).toDomain())
          .toList();
      runs.addAll(items);
      if (page.length < 200) break;
      final next = items.last.id;
      if (next.isEmpty || (afterId != null && next.compareTo(afterId) <= 0)) {
        throw StateError('Active run paging did not advance');
      }
      afterId = next;
    }
    return runs;
  }

  @override
  Future<List<AgentRunStep>> listSteps(String runId) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.agentRunSteps(runId),
    );
    return response.map(AgentRunStep.fromJson).toList();
  }

  @override
  Future<List<AgentRunEvent>> listEvents(
    String runId, {
    int afterSeq = 0,
    int limit = 200,
  }) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.agentRunEvents(runId),
      queryParameters: {'afterSeq': '$afterSeq', 'limit': '$limit'},
    );
    return response.map(AgentRunEvent.fromJson).toList();
  }

  @override
  Future<List<AgentApproval>> listApprovals(
    String runId, {
    String? status,
  }) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.agentRunApprovals(runId),
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return response
        .map((json) => AgentApprovalDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<List<AgentContextSource>> listContextSources(String runId) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.agentRunContextSources(runId),
    );
    return response
        .map((json) => AgentContextSourceDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<List<AgentArtifact>> listArtifacts(String runId) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.agentRunArtifacts(runId),
    );
    return response
        .map((json) => AgentArtifactDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<AgentRunSummary> startTaskRun({
    required String workspaceId,
    required String taskId,
    String? agentKey,
    String? goal,
  }) async {
    final response = await _restClient.postJson(
      ApiEndpoints.taskAgentRuns(workspaceId, taskId),
      body: {
        if (agentKey != null && agentKey.isNotEmpty) 'agentKey': agentKey,
        if (goal != null && goal.isNotEmpty) 'goal': goal,
      },
    );
    return AgentRunDto.fromJson(response).toDomain();
  }

  @override
  Future<AgentApproval> decideApproval({
    required String runId,
    required String approvalId,
    required bool approve,
    String? note,
  }) async {
    final response = await _restClient.postJson(
      ApiEndpoints.agentApprovalDecision(runId, approvalId),
      body: {
        'decision': approve ? 'APPROVE' : 'REJECT',
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return AgentApprovalDto.fromJson(response).toDomain();
  }

  @override
  Future<AgentRunSummary> cancelRun(String runId) async {
    final response = await _restClient.postJson(
      ApiEndpoints.agentRunCancel(runId),
      body: const {},
    );
    return AgentRunDto.fromJson(response).toDomain();
  }

  @override
  Future<AgentRunSummary> retryRun(String runId) async {
    final response = await _restClient.postJson(
      ApiEndpoints.agentRunRetry(runId),
      body: const {},
    );
    return AgentRunDto.fromJson(response).toDomain();
  }
}
