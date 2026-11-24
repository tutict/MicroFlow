class AgentContextSource {
  const AgentContextSource({
    required this.id,
    required this.type,
    required this.label,
    this.refId,
    this.excerpt,
  });

  final String id;
  final String type;
  final String label;
  final String? refId;
  final String? excerpt;
}
