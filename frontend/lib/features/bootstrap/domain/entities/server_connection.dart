class ServerConnection {
  const ServerConnection({
    required this.serverOrigin,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    required this.instanceName,
    required this.pairedAt,
  });

  final String serverOrigin;
  final String apiBaseUrl;
  final String wsBaseUrl;
  final String instanceName;
  final String pairedAt;
}
