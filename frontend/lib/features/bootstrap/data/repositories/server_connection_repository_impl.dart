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
  static const _legacyConnectionKeys = <String>[
    ServerConnectionKeys.serverOrigin,
    ServerConnectionKeys.apiBaseUrl,
    ServerConnectionKeys.wsBaseUrl,
    ServerConnectionKeys.instanceName,
    ServerConnectionKeys.pairedAt,
  ];

  @override
  Future<ServerConnection?> currentConnection() async {
    await _ensureMigrated();
    final currentId = await _localStore.readString(
      ServerConnectionKeys.currentConnectionId,
    );
    if (currentId == null || currentId.isEmpty) {
      return _readLegacyCurrentConnection();
    }
    final connections = await listConnections();
    for (final connection in connections) {
      if (connection.id == currentId) {
        return connection;
      }
    }
    return _readLegacyCurrentConnection();
  }

  @override
  Future<List<ServerConnection>> listConnections() async {
    await _ensureMigrated();
    final encoded = await _localStore.readString(
      ServerConnectionKeys.savedConnections,
    );
    if (encoded == null || encoded.isEmpty) {
      final current = await _readLegacyCurrentConnection();
      return current == null ? const [] : [current];
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .cast<Map>()
        .map((entry) => ServerConnection.fromJson(entry.cast<String, Object?>()))
        .toList(growable: false);
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

    final serverOrigin = payload['serverOrigin'] as String? ?? origin;
    final connection = ServerConnection(
      id: serverOrigin,
      serverOrigin: serverOrigin,
      apiBaseUrl: payload['apiBaseUrl'] as String? ?? '$origin/api/v1',
      wsBaseUrl: payload['wsBaseUrl'] as String? ?? _defaultWsBaseUrl(origin),
      instanceName: payload['instanceName'] as String? ?? 'MicroFlow',
      pairedAt: payload['pairedAt'] as String? ?? '',
    );
    final connections = await listConnections();
    final updatedConnections = <ServerConnection>[
      connection,
      ...connections.where((item) => item.id != connection.id),
    ];
    await _saveConnections(updatedConnections);
    await _persistActive(connection);
    return connection;
  }

  @override
  Future<ServerConnection?> activateConnection(String connectionId) async {
    final connections = await listConnections();
    for (final connection in connections) {
      if (connection.id == connectionId) {
        await _persistActive(connection);
        return connection;
      }
    }
    return null;
  }

  @override
  Future<void> clearCurrentConnection() async {
    for (final key in _legacyConnectionKeys) {
      await _localStore.remove(key);
    }
    await _localStore.remove(ServerConnectionKeys.currentConnectionId);
  }

  @override
  Future<void> removeConnection(String connectionId) async {
    final connections = await listConnections();
    final updatedConnections = connections
        .where((connection) => connection.id != connectionId)
        .toList(growable: false);
    await _saveConnections(updatedConnections);
    final currentId = await _localStore.readString(
      ServerConnectionKeys.currentConnectionId,
    );
    if (currentId != connectionId) {
      return;
    }
    if (updatedConnections.isEmpty) {
      await clearCurrentConnection();
      return;
    }
    await _persistActive(updatedConnections.first);
  }

  Future<void> _ensureMigrated() async {
    await _localStore.migrateFromPreferences(_legacyConnectionKeys);
    final encoded = await _localStore.readString(ServerConnectionKeys.savedConnections);
    if (encoded != null && encoded.isNotEmpty) {
      return;
    }
    final current = await _readLegacyCurrentConnection();
    if (current == null) {
      return;
    }
    await _saveConnections([current]);
    await _localStore.saveString(
      ServerConnectionKeys.currentConnectionId,
      current.id,
    );
  }

  Future<ServerConnection?> _readLegacyCurrentConnection() async {
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
    final pairedAt = await _localStore.readString(ServerConnectionKeys.pairedAt);
    if (serverOrigin == null ||
        apiBaseUrl == null ||
        wsBaseUrl == null ||
        instanceName == null ||
        pairedAt == null) {
      return null;
    }
    return ServerConnection(
      id: serverOrigin,
      serverOrigin: serverOrigin,
      apiBaseUrl: apiBaseUrl,
      wsBaseUrl: wsBaseUrl,
      instanceName: instanceName,
      pairedAt: pairedAt,
    );
  }

  Future<void> _saveConnections(List<ServerConnection> connections) async {
    final encoded = jsonEncode(
      connections.map((connection) => connection.toJson()).toList(growable: false),
    );
    await _localStore.saveString(ServerConnectionKeys.savedConnections, encoded);
  }

  Future<void> _persistActive(ServerConnection connection) async {
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
    await _localStore.saveString(
      ServerConnectionKeys.currentConnectionId,
      connection.id,
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
