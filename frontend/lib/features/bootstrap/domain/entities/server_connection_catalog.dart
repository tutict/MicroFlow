import 'server_connection.dart';

class ServerConnectionCatalog {
  const ServerConnectionCatalog({
    this.currentConnection,
    this.savedConnections = const [],
    this.isUpdating = false,
  });

  final ServerConnection? currentConnection;
  final List<ServerConnection> savedConnections;
  final bool isUpdating;

  ServerConnectionCatalog updating() => ServerConnectionCatalog(
    currentConnection: currentConnection,
    savedConnections: savedConnections,
    isUpdating: true,
  );
}
