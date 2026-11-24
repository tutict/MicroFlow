class AgentRunStep {
  const AgentRunStep({
    required this.id,
    required this.seq,
    required this.kind,
    required this.status,
    required this.title,
    this.agentKey,
    this.detail,
  });
  final String id;
  final int seq;
  final String kind;
  final String status;
  final String title;
  final String? agentKey;
  final String? detail;

  factory AgentRunStep.fromJson(Map<String, Object?> json) => AgentRunStep(
    id: json['id'] as String? ?? '',
    seq: (json['seq'] as num?)?.toInt() ?? 0,
    kind: json['kind'] as String? ?? '',
    status: json['status'] as String? ?? '',
    title: json['title'] as String? ?? '',
    agentKey: json['agentKey'] as String?,
    detail: json['detail'] as String?,
  );
}
