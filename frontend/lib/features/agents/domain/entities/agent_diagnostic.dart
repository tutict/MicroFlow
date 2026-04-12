class AgentDiagnostic {
  const AgentDiagnostic({
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
}
