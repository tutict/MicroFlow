import 'collaboration_event.dart';

class CollaborationRun {
  const CollaborationRun({
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
  final List<CollaborationEvent> events;

  CollaborationRun copyWith({
    String? collaborationId,
    String? workspaceId,
    String? channelId,
    String? status,
    int? round,
    int? maxRounds,
    String? startedAt,
    String? lastEventAt,
    String? triggerMessageId,
    String? stage,
    String? activeAgentKey,
    List<String>? agentKeys,
    String? trigger,
    String? reason,
    String? detail,
    List<CollaborationEvent>? events,
  }) {
    return CollaborationRun(
      collaborationId: collaborationId ?? this.collaborationId,
      workspaceId: workspaceId ?? this.workspaceId,
      channelId: channelId ?? this.channelId,
      status: status ?? this.status,
      round: round ?? this.round,
      maxRounds: maxRounds ?? this.maxRounds,
      startedAt: startedAt ?? this.startedAt,
      lastEventAt: lastEventAt ?? this.lastEventAt,
      triggerMessageId: triggerMessageId ?? this.triggerMessageId,
      stage: stage ?? this.stage,
      activeAgentKey: activeAgentKey ?? this.activeAgentKey,
      agentKeys: agentKeys ?? this.agentKeys,
      trigger: trigger ?? this.trigger,
      reason: reason ?? this.reason,
      detail: detail ?? this.detail,
      events: events ?? this.events,
    );
  }
}
