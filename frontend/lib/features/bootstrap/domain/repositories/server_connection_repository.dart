import '../entities/server_connection.dart';

abstract interface class ServerConnectionRepository {
  Future<ServerConnection?> currentConnection();
  Future<List<ServerConnection>> listConnections();

  Future<ServerConnection> pair({
    required String serverUrl,
    required String pairingCode,
  });

  Future<ServerConnection?> activateConnection(String connectionId);
  Future<void> clearCurrentConnection();
  Future<void> removeConnection(String connectionId);
}
