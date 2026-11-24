import '../../domain/entities/agent_artifact.dart';

class AgentArtifactDto {
  const AgentArtifactDto({
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

  factory AgentArtifactDto.fromJson(Map<String, Object?> json) {
    return AgentArtifactDto(
      id: json['id'] as String? ?? '',
      runId: json['runId'] as String? ?? '',
      kind: json['kind'] as String? ?? 'RUN_SUMMARY',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String?,
      content: json['content'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }

  AgentArtifact toDomain() {
    return AgentArtifact(
      id: id,
      runId: runId,
      kind: kind,
      title: title,
      summary: summary,
      content: content,
      createdAt: createdAt,
    );
  }
}
