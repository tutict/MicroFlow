import '../../domain/entities/agent_connector.dart';

class AgentConnectorDto {
  const AgentConnectorDto(this._json);

  final Map<String, Object?> _json;

  factory AgentConnectorDto.fromJson(Map<String, Object?> json) {
    return AgentConnectorDto(json);
  }

  AgentConnector toDomain() {
    return AgentConnector(
      id: _json['id'] as String? ?? '',
      workspaceId: _json['workspaceId'] as String? ?? '',
      ownerUserId: _json['ownerUserId'] as String? ?? '',
      ownedByMe: _json['ownedByMe'] as bool? ?? false,
      kind: ConnectorKind.parse(_json['kind'] as String?),
      name: _json['name'] as String? ?? '',
      config: (_json['config'] as Map?)?.cast<String, Object?>() ?? const {},
      secretFields: _strings(_json['secretFields']),
      sharingScope: ConnectorSharingScope.parse(
        _json['sharingScope'] as String?,
      ),
      sharedUserIds: _strings(_json['sharedUserIds']),
      sharedAgentKeys: _strings(_json['sharedAgentKeys']),
      status: ConnectorStatus.parse(_json['status'] as String?),
      readEnabled: _json['readEnabled'] as bool? ?? false,
      writeEnabled: _json['writeEnabled'] as bool? ?? false,
      lastError: _json['lastError'] as String?,
      lastCheckedAt: _json['lastCheckedAt'] as String?,
      createdAt: _json['createdAt'] as String?,
      updatedAt: _json['updatedAt'] as String?,
    );
  }

  static List<String> _strings(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value.whereType<String>().toList();
  }
}

class ConnectorCheckDto {
  const ConnectorCheckDto(this._json);

  final Map<String, Object?> _json;

  factory ConnectorCheckDto.fromJson(Map<String, Object?> json) {
    return ConnectorCheckDto(json);
  }

  ConnectorCheck toDomain() {
    return ConnectorCheck(
      connectorId: _json['connectorId'] as String? ?? '',
      status: ConnectorStatus.parse(_json['status'] as String?),
      detail: _json['detail'] as String?,
      checkedAt: _json['checkedAt'] as String?,
    );
  }
}
