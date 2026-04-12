import '../../domain/entities/agent_descriptor.dart';

class AgentDescriptorDto {
  const AgentDescriptorDto({
    required this.agentKey,
    required this.provider,
    required this.enabled,
  });

  final String agentKey;
  final String provider;
  final bool enabled;

  factory AgentDescriptorDto.fromJson(Map<String, Object?> json) {
    return AgentDescriptorDto(
      agentKey: json['agentKey'] as String,
      provider: json['provider'] as String,
      enabled: json['enabled'] as bool,
    );
  }

  AgentDescriptor toDomain() {
    return AgentDescriptor(
      agentKey: agentKey,
      provider: provider,
      enabled: enabled,
    );
  }
}

