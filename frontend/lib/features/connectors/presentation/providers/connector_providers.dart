import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../data/repositories/connector_repository_impl.dart';
import '../../domain/entities/agent_connector.dart';
import '../../domain/repositories/connector_repository.dart';

final connectorRepositoryProvider = Provider<ConnectorRepository>((ref) {
  return ConnectorRepositoryImpl(ref.watch(restClientProvider));
});

/// One key per workspace: the settings screen is the only consumer, so a plain
/// family keeps refresh semantics obvious.
final connectorsProvider =
    FutureProvider.autoDispose.family<List<AgentConnector>, String>((
      ref,
      workspaceId,
    ) {
      return ref.watch(connectorRepositoryProvider).list(workspaceId);
    });

/// Mutations funnel through one object so every caller refreshes the same key
/// and a stale list can never be shown after a create or delete.
class ConnectorActions {
  const ConnectorActions(this._ref);

  final Ref _ref;

  Future<AgentConnector> create(
    String workspaceId,
    ConnectorDraft draft,
  ) async {
    final created = await _ref
        .read(connectorRepositoryProvider)
        .create(workspaceId, draft);
    _ref.invalidate(connectorsProvider(workspaceId));
    return created;
  }

  Future<AgentConnector> update(
    String workspaceId,
    String connectorId,
    ConnectorDraft draft,
  ) async {
    final updated = await _ref
        .read(connectorRepositoryProvider)
        .update(workspaceId, connectorId, draft);
    _ref.invalidate(connectorsProvider(workspaceId));
    return updated;
  }

  Future<void> delete(String workspaceId, String connectorId) async {
    await _ref.read(connectorRepositoryProvider).delete(workspaceId, connectorId);
    _ref.invalidate(connectorsProvider(workspaceId));
  }

  Future<ConnectorCheck> test(String workspaceId, String connectorId) async {
    final check = await _ref
        .read(connectorRepositoryProvider)
        .test(workspaceId, connectorId);
    _ref.invalidate(connectorsProvider(workspaceId));
    return check;
  }
}

final connectorActionsProvider = Provider<ConnectorActions>((ref) {
  return ConnectorActions(ref);
});
