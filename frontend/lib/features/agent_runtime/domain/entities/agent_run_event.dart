/// One append-only entry of a run's event log.
///
/// [seq] is monotonic per run, which is what makes gap detection possible after
/// a dropped WebSocket connection.
class AgentRunEvent {
  const AgentRunEvent({
    required this.id,
    required this.seq,
    required this.type,
    required this.payload,
    this.createdAt,
  });

  final String id;
  final int seq;
  final String type;
  final Map<String, Object?> payload;
  final String? createdAt;

  factory AgentRunEvent.fromJson(Map<String, Object?> json) {
    return AgentRunEvent(
      id: json['id'] as String? ?? '',
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? 'UNKNOWN',
      payload: (json['payload'] as Map?)?.cast<String, Object?>() ?? const {},
      createdAt: json['createdAt'] as String?,
    );
  }

  /// Builds an event from a WebSocket payload, which carries the same fields
  /// but no message id of its own.
  factory AgentRunEvent.fromSocket(Map<String, Object?> payload) {
    return AgentRunEvent(
      id: 'ws-${payload['seq'] ?? 0}',
      seq: (payload['seq'] as num?)?.toInt() ?? 0,
      type: payload['type'] as String? ?? 'UNKNOWN',
      payload: payload,
      createdAt: payload['at'] as String?,
    );
  }
}
