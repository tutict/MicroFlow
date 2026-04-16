class ServerConnection {
  const ServerConnection({
    required this.id,
    required this.serverOrigin,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    required this.instanceName,
    required this.pairedAt,
  });

  final String id;
  final String serverOrigin;
  final String apiBaseUrl;
  final String wsBaseUrl;
  final String instanceName;
  final String pairedAt;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'serverOrigin': serverOrigin,
      'apiBaseUrl': apiBaseUrl,
      'wsBaseUrl': wsBaseUrl,
      'instanceName': instanceName,
      'pairedAt': pairedAt,
    };
  }

  factory ServerConnection.fromJson(Map<String, Object?> json) {
    return ServerConnection(
      id: json['id'] as String,
      serverOrigin: json['serverOrigin'] as String,
      apiBaseUrl: json['apiBaseUrl'] as String,
      wsBaseUrl: json['wsBaseUrl'] as String,
      instanceName: json['instanceName'] as String,
      pairedAt: json['pairedAt'] as String? ?? '',
    );
  }
}
