class WsEnvelope {
  const WsEnvelope({
    required this.type,
    this.requestId,
    this.channelId,
    this.payload,
  });

  final String type;
  final String? requestId;
  final String? channelId;
  final Map<String, Object?>? payload;

  WsEnvelope copyWithPayload(Map<String, Object?> payload) {
    return WsEnvelope(
      type: type,
      requestId: requestId,
      channelId: channelId,
      payload: payload,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'type': type,
      'requestId': requestId,
      'channelId': channelId,
      'payload': payload,
    };
  }
}
