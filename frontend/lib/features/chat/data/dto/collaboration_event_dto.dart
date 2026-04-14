import '../../domain/entities/collaboration_event.dart';

class CollaborationEventDto {
  const CollaborationEventDto({
    required this.id,
    required this.workspaceId,
    required this.channelId,
    required this.collaborationId,
    required this.eventType,
    required this.status,
    required this.round,
    required this.maxRounds,
    required this.createdAt,
    this.stage,
    this.agentKey,
    this.trigger,
    this.detail,
  });

  final String id;
  final String workspaceId;
  final String channelId;
  final String collaborationId;
  final String eventType;
  final String status;
  final int round;
  final int maxRounds;
  final String createdAt;
  final String? stage;
  final String? agentKey;
  final String? trigger;
  final String? detail;

  factory CollaborationEventDto.fromJson(Map<String, Object?> json) {
    return CollaborationEventDto(
      id: json['id'] as String,
      workspaceId: json['workspaceId'] as String,
      channelId: json['channelId'] as String,
      collaborationId: json['collaborationId'] as String,
      eventType: json['eventType'] as String? ?? 'COLLABORATION_STEP',
      status: json['status'] as String? ?? 'RUNNING',
      round: (json['round'] as num?)?.toInt() ?? 0,
      maxRounds: (json['maxRounds'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] as String? ?? '',
      stage: json['stage'] as String?,
      agentKey: json['agentKey'] as String?,
      trigger: json['trigger'] as String?,
      detail: json['detail'] as String?,
    );
  }

  CollaborationEvent toDomain() {
    return CollaborationEvent(
      id: id,
      workspaceId: workspaceId,
      channelId: channelId,
      collaborationId: collaborationId,
      eventType: eventType,
      status: status,
      round: round,
      maxRounds: maxRounds,
      createdAt: createdAt,
      stage: stage,
      agentKey: agentKey,
      trigger: trigger,
      detail: detail,
    );
  }
}
