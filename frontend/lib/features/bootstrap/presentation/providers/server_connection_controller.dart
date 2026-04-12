import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_providers.dart';
import '../../domain/entities/server_connection.dart';

final serverConnectionControllerProvider =
    AsyncNotifierProvider<ServerConnectionController, ServerConnection?>(
      ServerConnectionController.new,
    );

class ServerConnectionController extends AsyncNotifier<ServerConnection?> {
  @override
  Future<ServerConnection?> build() async {
    return ref.read(serverConnectionRepositoryProvider).currentConnection();
  }

  Future<ServerConnection> pair({
    required String serverUrl,
    required String pairingCode,
  }) async {
    state = const AsyncLoading();
    final connection = await ref
        .read(serverConnectionRepositoryProvider)
        .pair(serverUrl: serverUrl, pairingCode: pairingCode);
    state = AsyncData(connection);
    return connection;
  }

  Future<void> clearConnection() async {
    await ref.read(serverConnectionRepositoryProvider).clearConnection();
    state = const AsyncData(null);
  }
}
