import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/server_connection.dart';
import '../../domain/entities/server_connection_catalog.dart';
import '../../../../core/providers/app_providers.dart';

final serverConnectionControllerProvider = AsyncNotifierProvider<
  ServerConnectionController,
  ServerConnectionCatalog
>(ServerConnectionController.new);

class ServerConnectionController extends AsyncNotifier<ServerConnectionCatalog> {
  @override
  Future<ServerConnectionCatalog> build() async {
    final repository = ref.read(serverConnectionRepositoryProvider);
    final currentConnection = await repository.currentConnection();
    final savedConnections = await repository.listConnections();
    return ServerConnectionCatalog(
      currentConnection: currentConnection,
      savedConnections: savedConnections,
    );
  }

  Future<ServerConnection> pair({
    required String serverUrl,
    required String pairingCode,
  }) async {
    state = const AsyncLoading();
    final repository = ref.read(serverConnectionRepositoryProvider);
    final connection = await repository.pair(
      serverUrl: serverUrl,
      pairingCode: pairingCode,
    );
    final savedConnections = await repository.listConnections();
    state = AsyncData(
      ServerConnectionCatalog(
        currentConnection: connection,
        savedConnections: savedConnections,
      ),
    );
    return connection;
  }

  Future<ServerConnection?> activateConnection(String connectionId) async {
    state = const AsyncLoading();
    final repository = ref.read(serverConnectionRepositoryProvider);
    final currentConnection = await repository.activateConnection(connectionId);
    final savedConnections = await repository.listConnections();
    final catalog = ServerConnectionCatalog(
      currentConnection: currentConnection,
      savedConnections: savedConnections,
    );
    state = AsyncData(catalog);
    return currentConnection;
  }

  Future<void> clearCurrentConnection() async {
    final repository = ref.read(serverConnectionRepositoryProvider);
    await repository.clearCurrentConnection();
    final savedConnections = await repository.listConnections();
    state = AsyncData(
      ServerConnectionCatalog(
        currentConnection: null,
        savedConnections: savedConnections,
      ),
    );
  }

  Future<void> removeConnection(String connectionId) async {
    state = const AsyncLoading();
    final repository = ref.read(serverConnectionRepositoryProvider);
    await repository.removeConnection(connectionId);
    final currentConnection = await repository.currentConnection();
    final savedConnections = await repository.listConnections();
    state = AsyncData(
      ServerConnectionCatalog(
        currentConnection: currentConnection,
        savedConnections: savedConnections,
      ),
    );
  }
}
