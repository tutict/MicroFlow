enum RealtimeSocketEventType {
  messageCreated,
  agentRunCreated,
  agentRunUpdated,
  agentRunEvent,
  collaborationStarted,
  collaborationStep,
  collaborationCompleted,
  collaborationAborted,
  subscribed,
  error,
  unknown,
}

class RealtimeSocketEvent {
  const RealtimeSocketEvent({required this.type, this.payload});

  final RealtimeSocketEventType type;
  final Map<String, Object?>? payload;

  factory RealtimeSocketEvent.fromJson(Map<String, Object?> json) {
    final rawType = json['type'] as String? ?? '';
    final rawPayload = json['payload'];
    return RealtimeSocketEvent(
      type: switch (rawType) {
        'MESSAGE_CREATED' => RealtimeSocketEventType.messageCreated,
        'AGENT_RUN_CREATED' => RealtimeSocketEventType.agentRunCreated,
        'AGENT_RUN_UPDATED' => RealtimeSocketEventType.agentRunUpdated,
        'AGENT_RUN_EVENT' => RealtimeSocketEventType.agentRunEvent,
        'COLLABORATION_STARTED' => RealtimeSocketEventType.collaborationStarted,
        'COLLABORATION_STEP' => RealtimeSocketEventType.collaborationStep,
        'COLLABORATION_COMPLETED' =>
          RealtimeSocketEventType.collaborationCompleted,
        'COLLABORATION_ABORTED' => RealtimeSocketEventType.collaborationAborted,
        'SUBSCRIBED' => RealtimeSocketEventType.subscribed,
        'ERROR' => RealtimeSocketEventType.error,
        _ => RealtimeSocketEventType.unknown,
      },
      payload: rawType == 'ERROR' && rawPayload is String
          ? {'message': rawPayload}
          : (rawPayload as Map?)?.cast<String, Object?>(),
    );
  }
}
