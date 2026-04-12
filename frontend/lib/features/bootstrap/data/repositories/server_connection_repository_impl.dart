import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/server_connection_keys.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/storage/local_store.dart';
import '../../domain/entities/server_connection.dart';
import '../../domain/repositories/server_connection_repository.dart';

class ServerConnectionRepositoryImpl implements ServerConnectionRepository {
  const ServerConnectionRepositoryImpl(this._localStore);

  final LocalStore _localStore;
  static const _connectionKeys = <String>[
    ServerConnectionKeys.serverOrigin,
    ServerConnectionKeys.apiBaseUrl,
    ServerConnectionKeys.wsBaseUrl,
    ServerConnectionKeys.instanceName,
    ServerConnectionKeys.pairedAt,
  ];

  @override
  Future<ServerConnection?> currentConnection() async {
    await _localStore.migrateFromPreferences(_connectionKeys);
    final serverOrigin = await _localStore.readString(
      ServerConnectionKeys.serverOrigin,
    );
    final apiBaseUrl = await _localStore.readString(
      ServerConnectionKeys.apiBaseUrl,
    );
    final wsBaseUrl = await _localStore.readString(
      ServerConnectionKeys.wsBaseUrl,
    );
    final instanceName = await _localStore.readString(
      ServerConnectionKeys.instanceName,
    );
    final pairedAt = await _localStore.readString(
      ServerConnectionKeys.pairedAt,
    );
    if (serverOrigin == null ||
        apiBaseUrl == null ||
        wsBaseUrl == null ||
        instanceName == null ||
        pairedAt == null) {
      return null;
    }
    return ServerConnection(
      serverOrigin: serverOrigin,
      apiBaseUrl: apiBaseUrl,
      wsBaseUrl: wsBaseUrl,
      instanceName: instanceName,
      pairedAt: pairedAt,
    );
  }

  @override
  Future<ServerConnection> pair({
    required String serverUrl,
    required String pairingCode,
  }) async {
    final origin = _normalizeServerOrigin(serverUrl);
    final response = await http.post(
      Uri.parse('$origin/api/v1/bootstrap/pair'),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'pairingCode': pairingCode.trim()}),
    );
    final payload = response.body.isEmpty
        ? const <String, Object?>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload is Map<String, Object?>
          ? payload['message'] as String?
          : null;
      throw AppException(
        message ?? 'Pairing failed with status ${response.statusCode}',
      );
    }
    if (payload is! Map<String, Object?>) {
      throw const AppException('Invalid pairing response');
    }

    final connection = ServerConnection(
      serverOrigin: payload['serverOrigin'] as String? ?? origin,
      apiBaseUrl: payload['apiBaseUrl'] as String? ?? '$origin/api/v1',
      wsBaseUrl: payload['wsBaseUrl'] as String? ?? _defaultWsBaseUrl(origin),
      instanceName: payload['instanceName'] as String? ?? 'MicroFlow',
      pairedAt: payload['pairedAt'] as String? ?? '',
    );
    await _persist(connection);
    return connection;
  }

  @override
  Future<void> clearConnection() async {
    await _localStore.remove(ServerConnectionKeys.serverOrigin);
    await _localStore.remove(ServerConnectionKeys.apiBaseUrl);
    await _localStore.remove(ServerConnectionKeys.wsBaseUrl);
    await _localStore.remove(ServerConnectionKeys.instanceName);
    await _localStore.remove(ServerConnectionKeys.pairedAt);
  }

  Future<void> _persist(ServerConnection connection) async {
    await _localStore.saveString(
      ServerConnectionKeys.serverOrigin,
      connection.serverOrigin,
    );
    await _localStore.saveString(
      ServerConnectionKeys.apiBaseUrl,
      connection.apiBaseUrl,
    );
    await _localStore.saveString(
      ServerConnectionKeys.wsBaseUrl,
      connection.wsBaseUrl,
    );
    await _localStore.saveString(
      ServerConnectionKeys.instanceName,
      connection.instanceName,
    );
    await _localStore.saveString(
      ServerConnectionKeys.pairedAt,
      connection.pairedAt,
    );
  }

  String _normalizeServerOrigin(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) {
      throw const AppException('Server URL is required');
    }
    if (normalized.startsWith('ws://')) {
      normalized = 'http://${normalized.substring(5)}';
    } else if (normalized.startsWith('wss://')) {
      normalized = 'https://${normalized.substring(6)}';
    } else if (!normalized.contains('://')) {
      normalized = 'http://$normalized';
    }

    var uri = Uri.parse(normalized);
    var path = uri.path;
    if (path.endsWith('/api/v1')) {
      path = path.substring(0, path.length - '/api/v1'.length);
    } else if (path.endsWith('/api')) {
      path = path.substring(0, path.length - '/api'.length);
    }
    uri = uri.replace(path: path, query: null, fragment: null);
    final origin = uri.toString();
    return origin.endsWith('/')
        ? origin.substring(0, origin.length - 1)
        : origin;
  }

  String _defaultWsBaseUrl(String origin) {
    if (origin.startsWith('https://')) {
      return 'wss://${origin.substring('https://'.length)}/ws';
    }
    if (origin.startsWith('http://')) {
      return 'ws://${origin.substring('http://'.length)}/ws';
    }
    return '$origin/ws';
  }
}
