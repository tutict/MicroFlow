import '../dto/agent_diagnostic_dto.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/rest_client.dart';
import '../../domain/entities/agent_diagnostic.dart';
import '../dto/agent_descriptor_dto.dart';
import '../dto/agent_run_dto.dart';
import '../../domain/entities/agent_descriptor.dart';
import '../../domain/entities/agent_run.dart';
import '../../domain/repositories/agent_repository.dart';

class AgentRepositoryImpl implements AgentRepository {
  const AgentRepositoryImpl(this._restClient);

  final RestClient _restClient;

  @override
  Future<List<AgentDescriptor>> listAgents(String workspaceId) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.agents,
      queryParameters: {'workspaceId': workspaceId},
    );
    return response
        .map((json) => AgentDescriptorDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<List<AgentRun>> listRuns(String workspaceId) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.agentRuns,
      queryParameters: {'workspaceId': workspaceId},
    );
    return response
        .map((json) => AgentRunDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<List<AgentDiagnostic>> listDiagnostics(String workspaceId) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.agentDiagnostics,
      queryParameters: {'workspaceId': workspaceId},
    );
    return response
        .map((json) => AgentDiagnosticDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<void> updateRoleStrategy({
    required String workspaceId,
    required String agentKey,
    required String roleStrategy,
  }) async {
    await _restClient.putJson(
      ApiEndpoints.agentRoleStrategy(agentKey),
      queryParameters: {'workspaceId': workspaceId},
      body: {'roleStrategy': roleStrategy},
    );
  }
}
