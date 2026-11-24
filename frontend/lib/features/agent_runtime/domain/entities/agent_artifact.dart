class AgentArtifact {
  const AgentArtifact({
    required this.id,
    required this.runId,
    required this.kind,
    required this.title,
    this.summary,
    this.content,
    this.createdAt,
  });

  final String id;
  final String runId;
  final String kind;
  final String title;
  final String? summary;
  final String? content;
  final String? createdAt;
}
