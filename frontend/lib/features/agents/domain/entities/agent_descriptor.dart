class AgentDescriptor {
  const AgentDescriptor({
    required this.agentKey,
    required this.provider,
    required this.enabled,
  });

  final String agentKey;
  final String provider;
  final bool enabled;
}
