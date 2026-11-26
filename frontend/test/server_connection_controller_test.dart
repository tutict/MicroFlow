import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/core/errors/app_exception.dart';
import 'package:microflow_frontend/core/providers/app_providers.dart';
import 'package:microflow_frontend/features/bootstrap/domain/entities/server_connection.dart';
import 'package:microflow_frontend/features/bootstrap/domain/repositories/server_connection_repository.dart';
import 'package:microflow_frontend/features/bootstrap/presentation/providers/server_connection_controller.dart';

void main() {
  test('pairing rejects another device mutation until it settles', () async {
    final repository = _PendingConnectionRepository();
    final container = ProviderContainer(
      overrides: [
        serverConnectionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() {
      for (final response in repository.responses) {
        if (!response.isCompleted) {
          response.completeError(StateError('pairing failed'));
        }
      }
    });
    await container.read(serverConnectionControllerProvider.future);
    final controller = container.read(
      serverConnectionControllerProvider.notifier,
    );
    final first = expectLater(
      controller.pair(
        serverUrl: _connection.serverOrigin,
        pairingCode: 'first',
      ),
      throwsStateError,
    );
    final second = controller
        .pair(serverUrl: _connection.serverOrigin, pairingCode: 'second')
        .then<Object?>(
          (_) => null,
          onError: (Object error, StackTrace _) => error,
        );
    final requestCount = repository.responses.length;
    for (final response in repository.responses) {
      response.completeError(StateError('pairing failed'));
    }
    await first;
    final overlapError = await second;

    expect(requestCount, 1);
    expect(overlapError, isA<AppException>());

    expect(
      container.read(serverConnectionControllerProvider).value?.isUpdating,
      isFalse,
    );
  });

  test('failed pairing ends loading and permits another attempt', () async {
    final repository = _ConnectionRepository()
      ..pairingError = StateError('pairing failed');
    final container = ProviderContainer(
      overrides: [
        serverConnectionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(serverConnectionControllerProvider.future);
    final controller = container.read(
      serverConnectionControllerProvider.notifier,
    );

    await expectLater(
      controller.pair(serverUrl: _connection.serverOrigin, pairingCode: 'bad'),
      throwsStateError,
    );

    final failedState = container.read(serverConnectionControllerProvider);
    expect(failedState.isLoading, isFalse);
    expect(failedState.value?.isUpdating, isFalse);
    expect(failedState.value?.currentConnection, isNull);
    expect(failedState.value?.savedConnections, isEmpty);

    repository.pairingError = null;
    await controller.pair(
      serverUrl: _connection.serverOrigin,
      pairingCode: 'valid',
    );
    expect(
      container
          .read(serverConnectionControllerProvider)
          .value
          ?.currentConnection
          ?.id,
      'http://127.0.0.1:18080',
    );
  });

  test('failed device activation retains the current device', () async {
    final repository = _ConnectionRepository(current: _connection)
      ..activationError = StateError('activation failed');
    final container = ProviderContainer(
      overrides: [
        serverConnectionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(serverConnectionControllerProvider.future);

    await expectLater(
      container
          .read(serverConnectionControllerProvider.notifier)
          .activateConnection('another-device'),
      throwsStateError,
    );

    final state = container.read(serverConnectionControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.value?.isUpdating, isFalse);
    expect(state.value?.currentConnection?.id, 'http://127.0.0.1:18080');
    expect(state.value?.savedConnections, hasLength(1));
  });

  test('failed device removal retains the saved device list', () async {
    final repository = _ConnectionRepository(current: _connection)
      ..removalError = StateError('removal failed');
    final container = ProviderContainer(
      overrides: [
        serverConnectionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(serverConnectionControllerProvider.future);

    await expectLater(
      container
          .read(serverConnectionControllerProvider.notifier)
          .removeConnection(_connection.id),
      throwsStateError,
    );

    final state = container.read(serverConnectionControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.value?.isUpdating, isFalse);
    expect(state.value?.currentConnection?.id, 'http://127.0.0.1:18080');
    expect(state.value?.savedConnections, hasLength(1));
  });
}

const _connection = ServerConnection(
  id: 'http://127.0.0.1:18080',
  serverOrigin: 'http://127.0.0.1:18080',
  apiBaseUrl: 'http://127.0.0.1:18080/api/v1',
  wsBaseUrl: 'ws://127.0.0.1:18080/ws',
  instanceName: 'Demo device',
  pairedAt: '2026-11-26T06:00:00Z',
);

class _ConnectionRepository implements ServerConnectionRepository {
  _ConnectionRepository({this.current});

  ServerConnection? current;
  Object? pairingError;
  Object? activationError;
  Object? removalError;

  @override
  Future<ServerConnection?> currentConnection() async => current;

  @override
  Future<List<ServerConnection>> listConnections() async =>
      current == null ? const [] : [current!];

  @override
  Future<ServerConnection> pair({
    required String serverUrl,
    required String pairingCode,
  }) async {
    if (pairingError != null) throw pairingError!;
    return current = _connection;
  }

  @override
  Future<ServerConnection?> activateConnection(String connectionId) async {
    if (activationError != null) throw activationError!;
    return null;
  }

  @override
  Future<void> clearCurrentConnection() async => current = null;

  @override
  Future<void> removeConnection(String connectionId) async {
    if (removalError != null) throw removalError!;
    current = null;
  }
}

class _PendingConnectionRepository extends _ConnectionRepository {
  final responses = <Completer<ServerConnection>>[];

  @override
  Future<ServerConnection> pair({
    required String serverUrl,
    required String pairingCode,
  }) {
    final response = Completer<ServerConnection>();
    responses.add(response);
    return response.future;
  }
}
