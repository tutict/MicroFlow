import '../../domain/entities/agent_run.dart';

class AgentRunDto {
  const AgentRunDto({
    required this.id,
    required this.agentKey,
    required this.status,
  });

  final String id;
  final String agentKey;
  final String status;

  factory AgentRunDto.fromJson(Map<String, Object?> json) {
    return AgentRunDto(
      id: json['id'] as String,
      agentKey: json['agentKey'] as String,
      status: json['status'] as String,
    );
  }

  AgentRun toDomain() {
    return AgentRun(
      id: id,
      agentKey: agentKey,
      status: status,
    );
  }
}

