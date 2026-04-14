import '../../domain/entities/collaboration_run.dart';
import 'collaboration_event_dto.dart';

class CollaborationRunDto {
  const CollaborationRunDto({
    required this.collaborationId,
    required this.workspaceId,
    required this.channelId,
    required this.status,
    required this.round,
    required this.maxRounds,
    required this.startedAt,
    required this.lastEventAt,
    this.triggerMessageId,
    this.stage,
    this.activeAgentKey,
    this.agentKeys = const [],
    this.trigger,
    this.reason,
    this.detail,
    this.events = const [],
  });

  final String collaborationId;
  final String workspaceId;
  final String channelId;
  final String status;
  final int round;
  final int maxRounds;
  final String startedAt;
  final String lastEventAt;
  final String? triggerMessageId;
  final String? stage;
  final String? activeAgentKey;
  final List<String> agentKeys;
  final String? trigger;
  final String? reason;
  final String? detail;
  final List<CollaborationEventDto> events;

  factory CollaborationRunDto.fromJson(Map<String, Object?> json) {
    final rawEvents = json['events'] as List<Object?>? ?? const [];
    final rawAgentKeys = json['agentKeys'] as List<Object?>? ?? const [];
    return CollaborationRunDto(
      collaborationId: json['collaborationId'] as String,
      workspaceId: json['workspaceId'] as String,
      channelId: json['channelId'] as String,
      status: json['status'] as String? ?? 'RUNNING',
      round: (json['round'] as num?)?.toInt() ?? 0,
      maxRounds: (json['maxRounds'] as num?)?.toInt() ?? 0,
      startedAt: json['startedAt'] as String? ?? '',
      lastEventAt: json['lastEventAt'] as String? ?? '',
      triggerMessageId: json['triggerMessageId'] as String?,
      stage: json['stage'] as String?,
      activeAgentKey: json['activeAgentKey'] as String?,
      agentKeys: rawAgentKeys.whereType<String>().toList(growable: false),
      trigger: json['trigger'] as String?,
      reason: json['reason'] as String?,
      detail: json['detail'] as String?,
      events: rawEvents
          .whereType<Map<String, Object?>>()
          .map(CollaborationEventDto.fromJson)
          .toList(growable: false),
    );
  }

  CollaborationRun toDomain() {
    return CollaborationRun(
      collaborationId: collaborationId,
      workspaceId: workspaceId,
      channelId: channelId,
      status: status,
      round: round,
      maxRounds: maxRounds,
      startedAt: startedAt,
      lastEventAt: lastEventAt,
      triggerMessageId: triggerMessageId,
      stage: stage,
      activeAgentKey: activeAgentKey,
      agentKeys: agentKeys,
      trigger: trigger,
      reason: reason,
      detail: detail,
      events: events.map((event) => event.toDomain()).toList(growable: false),
    );
  }
}
