import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/rest_client.dart';
import '../../domain/entities/agent_connector.dart';
import '../../domain/repositories/connector_repository.dart';
import '../dto/agent_connector_dto.dart';

class ConnectorRepositoryImpl implements ConnectorRepository {
  const ConnectorRepositoryImpl(this._restClient);

  final RestClient _restClient;

  @override
  Future<List<AgentConnector>> list(String workspaceId) async {
    final response = await _restClient.getJsonList(
      ApiEndpoints.workspaceConnectors(workspaceId),
    );
    return response
        .map((json) => AgentConnectorDto.fromJson(json).toDomain())
        .toList();
  }

  @override
  Future<AgentConnector> create(
    String workspaceId,
    ConnectorDraft draft,
  ) async {
    final response = await _restClient.postJson(
      ApiEndpoints.workspaceConnectors(workspaceId),
      body: _body(draft),
    );
    return AgentConnectorDto.fromJson(response).toDomain();
  }

  @override
  Future<AgentConnector> update(
    String workspaceId,
    String connectorId,
    ConnectorDraft draft,
  ) async {
    final response = await _restClient.putJson(
      ApiEndpoints.workspaceConnector(workspaceId, connectorId),
      body: _body(draft),
    );
    return AgentConnectorDto.fromJson(response).toDomain();
  }

  @override
  Future<void> delete(String workspaceId, String connectorId) {
    return _restClient.delete(
      ApiEndpoints.workspaceConnector(workspaceId, connectorId),
    );
  }

  @override
  Future<ConnectorCheck> test(String workspaceId, String connectorId) async {
    final response = await _restClient.postJson(
      ApiEndpoints.workspaceConnectorTest(workspaceId, connectorId),
      body: const {},
    );
    return ConnectorCheckDto.fromJson(response).toDomain();
  }

  /// Secrets are only sent when the user actually typed new ones; an omitted
  /// field tells the server to keep what it already has.
  Map<String, Object?> _body(ConnectorDraft draft) {
    return {
      'kind': draft.kind.storedValue,
      'name': draft.name,
      'config': draft.config,
      if (draft.secrets != null) 'secrets': draft.secrets,
      'sharingScope': draft.sharingScope.storedValue,
      'sharedUserIds': draft.sharedUserIds,
      'readEnabled': draft.readEnabled,
      'writeEnabled': draft.writeEnabled,
    };
  }
}
