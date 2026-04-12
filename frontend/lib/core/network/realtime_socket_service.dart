import 'dart:async';

abstract interface class RealtimeSocketService {
  Stream<dynamic> get rawEvents;

  Future<void> connect({required String token});

  Future<void> subscribe(String channelId);

  Future<void> sendMessage({
    required String workspaceId,
    required String channelId,
    required String content,
  });

  Future<void> disconnect();
}

