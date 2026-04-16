import 'server_connection.dart';

class ServerConnectionCatalog {
  const ServerConnectionCatalog({
    this.currentConnection,
    this.savedConnections = const [],
  });

  final ServerConnection? currentConnection;
  final List<ServerConnection> savedConnections;
}
