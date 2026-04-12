import '../entities/server_connection.dart';

abstract interface class ServerConnectionRepository {
  Future<ServerConnection?> currentConnection();

  Future<ServerConnection> pair({
    required String serverUrl,
    required String pairingCode,
  });

  Future<void> clearConnection();
}
