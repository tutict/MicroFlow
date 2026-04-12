import '../../domain/entities/agent_diagnostic.dart';

class AgentDiagnosticDto {
  const AgentDiagnosticDto({
    required this.agentKey,
    required this.provider,
    required this.endpointUrl,
    required this.enabled,
    required this.credentialConfigured,
    required this.roleStrategy,
    required this.status,
    required this.detail,
    required this.latencyMillis,
    required this.checkedAt,
  });

  final String agentKey;
  final String provider;
  final String endpointUrl;
  final bool enabled;
  final bool credentialConfigured;
  final String roleStrategy;
  final String status;
  final String detail;
  final int latencyMillis;
  final String checkedAt;

  factory AgentDiagnosticDto.fromJson(Map<String, Object?> json) {
    return AgentDiagnosticDto(
      agentKey: json['agentKey'] as String,
      provider: json['provider'] as String? ?? '',
      endpointUrl: json['endpointUrl'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      credentialConfigured: json['credentialConfigured'] as bool? ?? false,
      roleStrategy: json['roleStrategy'] as String? ?? '',
      status: json['status'] as String? ?? 'UNKNOWN',
      detail: json['detail'] as String? ?? '',
      latencyMillis: (json['latencyMillis'] as num?)?.toInt() ?? 0,
      checkedAt: json['checkedAt'] as String? ?? '',
    );
  }

  AgentDiagnostic toDomain() {
    return AgentDiagnostic(
      agentKey: agentKey,
      provider: provider,
      endpointUrl: endpointUrl,
      enabled: enabled,
      credentialConfigured: credentialConfigured,
      roleStrategy: roleStrategy,
      status: status,
      detail: detail,
      latencyMillis: latencyMillis,
      checkedAt: checkedAt,
    );
  }
}
