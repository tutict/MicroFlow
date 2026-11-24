import '../entities/agent_approval.dart';
import '../entities/agent_artifact.dart';
import '../entities/agent_context_source.dart';
import '../entities/agent_run.dart';
import '../entities/agent_run_event.dart';
import '../entities/agent_run_step.dart';

abstract class AgentRuntimeRepository {
  const AgentRuntimeRepository();

  Future<List<AgentRunSummary>> listRuns({
    required String workspaceId,
    String? taskId,
  });

  Future<AgentRunSummary> getRun(String runId);

  Future<List<AgentRunSummary>> listActiveRuns({required String workspaceId});

  Future<List<AgentRunStep>> listSteps(String runId);

  /// Append-only event log. [afterSeq] is how a client catches up after a
  /// dropped socket without replaying what it already has.
  Future<List<AgentRunEvent>> listEvents(
    String runId, {
    int afterSeq = 0,
    int limit = 200,
  });

  Future<List<AgentApproval>> listApprovals(String runId, {String? status});

  Future<List<AgentContextSource>> listContextSources(String runId);

  Future<List<AgentArtifact>> listArtifacts(String runId);

  Future<AgentRunSummary> startTaskRun({
    required String workspaceId,
    required String taskId,
    String? agentKey,
    String? goal,
  });

  Future<AgentApproval> decideApproval({
    required String runId,
    required String approvalId,
    required bool approve,
    String? note,
  });

  Future<AgentRunSummary> cancelRun(String runId);

  Future<AgentRunSummary> retryRun(String runId);
}
