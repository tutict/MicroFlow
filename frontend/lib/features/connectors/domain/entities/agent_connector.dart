/// Connector families the first release supports.
enum ConnectorKind {
  imap('IMAP'),
  smtp('SMTP'),
  caldav('CALDAV'),
  webdav('WEBDAV');

  const ConnectorKind(this.storedValue);

  final String storedValue;

  bool get canRead => this != ConnectorKind.smtp;

  bool get canWrite => this != ConnectorKind.imap;

  static ConnectorKind parse(String? value) {
    final normalized = (value ?? '').toUpperCase();
    for (final kind in ConnectorKind.values) {
      if (kind.storedValue == normalized) {
        return kind;
      }
    }
    return ConnectorKind.imap;
  }
}

/// Who may use a connector's credentials. Private is the default; widening it
/// is an explicit act, not a side effect of workspace membership.
enum ConnectorSharingScope {
  ownerOnly('PRIVATE'),
  workspace('WORKSPACE'),
  selected('SELECTED');

  const ConnectorSharingScope(this.storedValue);

  final String storedValue;

  static ConnectorSharingScope parse(String? value) {
    final normalized = (value ?? '').toUpperCase();
    for (final scope in ConnectorSharingScope.values) {
      if (scope.storedValue == normalized) {
        return scope;
      }
    }
    return ConnectorSharingScope.ownerOnly;
  }
}

enum ConnectorStatus {
  unverified('UNVERIFIED'),
  active('ACTIVE'),
  failed('FAILED');

  const ConnectorStatus(this.storedValue);

  final String storedValue;

  static ConnectorStatus parse(String? value) {
    final normalized = (value ?? '').toUpperCase();
    for (final status in ConnectorStatus.values) {
      if (status.storedValue == normalized) {
        return status;
      }
    }
    return ConnectorStatus.unverified;
  }
}

/// A connector as the server is willing to describe it: configuration and the
/// names of stored secrets, never their values.
class AgentConnector {
  const AgentConnector({
    required this.id,
    required this.workspaceId,
    required this.ownerUserId,
    required this.ownedByMe,
    required this.kind,
    required this.name,
    required this.config,
    required this.secretFields,
    required this.sharingScope,
    required this.sharedUserIds,
    required this.sharedAgentKeys,
    required this.status,
    required this.readEnabled,
    required this.writeEnabled,
    this.lastError,
    this.lastCheckedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String ownerUserId;
  final bool ownedByMe;
  final ConnectorKind kind;
  final String name;
  final Map<String, Object?> config;
  final List<String> secretFields;
  final ConnectorSharingScope sharingScope;
  final List<String> sharedUserIds;
  final List<String> sharedAgentKeys;
  final ConnectorStatus status;
  final bool readEnabled;
  final bool writeEnabled;
  final String? lastError;
  final String? lastCheckedAt;
  final String? createdAt;
  final String? updatedAt;

  bool get hasCredentials => secretFields.isNotEmpty;

  /// A one-line, secret-free summary of where this connector points.
  String endpointLabel() {
    if (kind == ConnectorKind.imap || kind == ConnectorKind.smtp) {
      final host = config['host'] as String? ?? '';
      final port = config['port']?.toString() ?? '';
      return port.isEmpty ? host : '$host:$port';
    }
    return config['baseUrl'] as String? ?? '';
  }
}

/// Result of a connectivity check.
class ConnectorCheck {
  const ConnectorCheck({
    required this.connectorId,
    required this.status,
    this.detail,
    this.checkedAt,
  });

  final String connectorId;
  final ConnectorStatus status;
  final String? detail;
  final String? checkedAt;
}

/// Write payload. [secrets] is null when the caller only wants to rename or
/// reshape sharing, so a stored password never has to travel again.
class ConnectorDraft {
  const ConnectorDraft({
    required this.kind,
    required this.name,
    required this.config,
    required this.sharingScope,
    this.secrets,
    this.sharedUserIds = const [],
    this.readEnabled = true,
    this.writeEnabled = false,
  });

  final ConnectorKind kind;
  final String name;
  final Map<String, Object?> config;
  final ConnectorSharingScope sharingScope;
  final Map<String, String>? secrets;
  final List<String> sharedUserIds;
  final bool readEnabled;
  final bool writeEnabled;
}
