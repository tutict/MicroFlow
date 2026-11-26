import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/core/network/realtime_socket_event.dart';

void main() {
  test('decodes the server string error without a payload cast failure', () {
    final event = RealtimeSocketEvent.fromJson(
      jsonDecode('{"type":"ERROR","payload":"Channel access denied"}')
          as Map<String, Object?>,
    );

    expect(event.type, RealtimeSocketEventType.error);
    expect(event.payload?['message'], 'Channel access denied');
  });

  test('keeps the structured disconnection event used by the client', () {
    final event = RealtimeSocketEvent.fromJson({
      'type': 'ERROR',
      'payload': {
        'message': 'WebSocket disconnected',
        'connectionState': 'DISCONNECTED',
      },
    });

    expect(event.type, RealtimeSocketEventType.error);
    expect(event.payload?['connectionState'], 'DISCONNECTED');
    expect(event.payload?['message'], 'WebSocket disconnected');
  });

  test('retains message content and identity in object payloads', () {
    final event = RealtimeSocketEvent.fromJson({
      'type': 'MESSAGE_CREATED',
      'payload': {
        'id': 'message_1',
        'channelId': 'channel_1',
        'senderUserId': 'user_1',
        'content': 'Hello',
        'createdAt': '2026-11-26T08:00:00Z',
      },
    });

    expect(event.type, RealtimeSocketEventType.messageCreated);
    expect(event.payload?['id'], 'message_1');
    expect(event.payload?['channelId'], 'channel_1');
    expect(event.payload?['content'], 'Hello');
  });

  test('does not treat a malformed message as a server error response', () {
    expect(
      () => RealtimeSocketEvent.fromJson({
        'type': 'MESSAGE_CREATED',
        'payload': 'malformed message',
      }),
      throwsA(isA<TypeError>()),
    );
  });
}
