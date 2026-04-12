import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/rest_client.dart';
import '../network/realtime_socket_service.dart';
import '../network/web_socket_realtime_service.dart';
import '../network/ws_client.dart';
import '../storage/local_store.dart';
import '../../features/agents/data/repositories/agent_repository_impl.dart';
import '../../features/agents/domain/repositories/agent_repository.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/bootstrap/data/repositories/server_connection_repository_impl.dart';
import '../../features/bootstrap/domain/repositories/server_connection_repository.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/workspace/data/repositories/workspace_repository_impl.dart';
import '../../features/workspace/domain/repositories/workspace_repository.dart';

final localStoreProvider = Provider<LocalStore>((ref) {
  return LocalStore();
});

final restClientProvider = Provider<RestClient>((ref) {
  return RestClient(ref.watch(localStoreProvider));
});

final wsClientProvider = Provider<WsClient>((ref) {
  return WsClient(ref.watch(localStoreProvider));
});

final realtimeSocketServiceProvider = Provider<RealtimeSocketService>((ref) {
  final service = WebSocketRealtimeService(
    ref.watch(wsClientProvider),
    ref.watch(restClientProvider),
  );
  ref.onDispose(() {
    service.disconnect();
  });
  return service;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(restClientProvider),
    ref.watch(localStoreProvider),
  );
});

final serverConnectionRepositoryProvider = Provider<ServerConnectionRepository>(
  (ref) {
    return ServerConnectionRepositoryImpl(ref.watch(localStoreProvider));
  },
);

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) {
  return WorkspaceRepositoryImpl(ref.watch(restClientProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(ref.watch(restClientProvider));
});

final agentRepositoryProvider = Provider<AgentRepository>((ref) {
  return AgentRepositoryImpl(ref.watch(restClientProvider));
});
