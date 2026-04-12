import '../entities/agent_diagnostic.dart';
import '../entities/agent_descriptor.dart';
import '../entities/agent_run.dart';

abstract interface class AgentRepository {
  Future<List<AgentDescriptor>> listAgents(String workspaceId);

  Future<List<AgentRun>> listRuns(String workspaceId);

  Future<List<AgentDiagnostic>> listDiagnostics(String workspaceId);

  Future<void> updateRoleStrategy({
    required String workspaceId,
    required String agentKey,
    required String roleStrategy,
  });
}
