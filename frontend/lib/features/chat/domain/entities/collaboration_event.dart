class CollaborationEvent {
  const CollaborationEvent({
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
}
