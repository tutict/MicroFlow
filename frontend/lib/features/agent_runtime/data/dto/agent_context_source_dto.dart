import '../../domain/entities/agent_context_source.dart';

class AgentContextSourceDto {
  const AgentContextSourceDto({
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

  factory AgentContextSourceDto.fromJson(Map<String, Object?> json) {
    return AgentContextSourceDto(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'UNKNOWN',
      label: json['label'] as String? ?? '',
      refId: json['refId'] as String?,
      excerpt: json['excerpt'] as String?,
    );
  }

  AgentContextSource toDomain() {
    return AgentContextSource(
      id: id,
      type: type,
      label: label,
      refId: refId,
      excerpt: excerpt,
    );
  }
}
