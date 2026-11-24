import '../entities/agent_connector.dart';

abstract class ConnectorRepository {
  const ConnectorRepository();

  Future<List<AgentConnector>> list(String workspaceId);

  Future<AgentConnector> create(String workspaceId, ConnectorDraft draft);

  Future<AgentConnector> update(
    String workspaceId,
    String connectorId,
    ConnectorDraft draft,
  );

  Future<void> delete(String workspaceId, String connectorId);

  Future<ConnectorCheck> test(String workspaceId, String connectorId);
}
