import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../errors/app_exception.dart';
import 'rest_client.dart';
import 'realtime_socket_service.dart';
import 'ws_client.dart';
import 'ws_envelope.dart';

class WebSocketRealtimeService implements RealtimeSocketService {
  WebSocketRealtimeService(this._wsClient, this._restClient);

  final WsClient _wsClient;
  final RestClient _restClient;
  final StreamController<dynamic> _events =
      StreamController<dynamic>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  @override
  Stream<dynamic> get rawEvents => _events.stream;

  @override
  Future<void> connect({required String token}) async {
    await disconnect();
    final ticket = await _issueTicket(token);
    _channel = WebSocketChannel.connect(await _wsClient.endpoint(ticket: ticket));
    _subscription = _channel!.stream.listen(
      (event) {
        if (event is String) {
          _events.add(jsonDecode(event));
        }
      },
      onError: _events.addError,
      onDone: () => _events.add({
        'type': 'ERROR',
        'payload': {'message': 'WebSocket disconnected'},
      }),
    );
  }

  Future<String> _issueTicket(String token) async {
    final response = await http.post(
      await _restClient.buildUrl('/auth/ws-ticket'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final payload = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload is Map<String, Object?>
          ? payload['message'] as String?
          : null;
      throw AppException(
        message ?? 'WebSocket ticket request failed with status ${response.statusCode}',
      );
    }
    if (payload is! Map<String, Object?>) {
      throw const AppException('Invalid WebSocket ticket response');
    }
    final ticket = payload['ticket'] as String?;
    if (ticket == null || ticket.isEmpty) {
      throw const AppException('Missing WebSocket ticket');
    }
    return ticket;
  }

  @override
  Future<void> subscribe(String channelId) async {
    _channel?.sink.add(
      jsonEncode(
        const WsEnvelope(
          type: 'SUBSCRIBE',
          payload: {},
        ).copyWithPayload({'channelId': channelId}).toJson(),
      ),
    );
  }

  @override
  Future<void> sendMessage({
    required String workspaceId,
    required String channelId,
    required String content,
  }) async {
    _channel?.sink.add(
      jsonEncode(
        WsEnvelope(
          type: 'CHAT_SEND',
          channelId: channelId,
          payload: {'workspaceId': workspaceId, 'content': content},
        ).toJson(),
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;
  }
}
