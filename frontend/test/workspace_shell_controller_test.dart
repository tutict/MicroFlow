import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/core/network/realtime_socket_service.dart';
import 'package:microflow_frontend/core/providers/app_providers.dart';
import 'package:microflow_frontend/features/agents/domain/entities/agent_diagnostic.dart';
import 'package:microflow_frontend/features/agents/domain/entities/agent_descriptor.dart';
import 'package:microflow_frontend/features/agents/domain/entities/agent_run.dart';
import 'package:microflow_frontend/features/agents/domain/repositories/agent_repository.dart';
import 'package:microflow_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:microflow_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:microflow_frontend/features/chat/domain/entities/channel_summary.dart';
import 'package:microflow_frontend/features/chat/domain/entities/chat_message.dart';
import 'package:microflow_frontend/features/chat/domain/repositories/chat_repository.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_conversation.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_summary.dart';
import 'package:microflow_frontend/features/workspace/domain/repositories/workspace_repository.dart';
import 'package:microflow_frontend/features/workspace/presentation/providers/workspace_shell_controller.dart';
import 'package:microflow_frontend/features/workspace/presentation/state/workspace_selected_conversation.dart';

void main() {
  test(
    'build returns a safe placeholder state when no workspace exists',
    () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(
              currentSessionValue: const AuthSession(
                userId: 'usr_1',
                email: 'demo@microflow.local',
                displayName: 'Demo User',
                accessToken: 'token',
                refreshToken: 'refresh',
              ),
            ),
          ),
          workspaceRepositoryProvider.overrideWithValue(
            _FakeWorkspaceRepository(),
          ),
          chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
          agentRepositoryProvider.overrideWithValue(_FakeAgentRepository()),
          realtimeSocketServiceProvider.overrideWithValue(
            _FakeRealtimeSocketService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(
        workspaceShellControllerProvider.future,
      );

      expect(state.workspaceId, isEmpty);
      expect(state.channels, isEmpty);
      expect(state.conversations, isEmpty);
      expect(state.messages, isEmpty);
      expect(state.selectedConversation.id, isEmpty);
      expect(state.selectedConversation.isAvailable, isFalse);
    },
  );

  test(
    'build falls back to the first available conversation when channels are empty',
    () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(
              currentSessionValue: const AuthSession(
                userId: 'usr_1',
                email: 'demo@microflow.local',
                displayName: 'Demo User',
                accessToken: 'token',
                refreshToken: 'refresh',
              ),
            ),
          ),
          workspaceRepositoryProvider.overrideWithValue(
            _FakeWorkspaceRepository(
              workspaces: const [
                WorkspaceSummary(id: 'ws_1', name: 'MicroFlow', memberCount: 1),
              ],
              conversations: const [
                WorkspaceConversation(
                  id: 'dm_1',
                  title: 'Alex',
                  subtitle: 'Direct thread',
                  kind: 'DIRECT_MESSAGE',
                  unreadCount: 0,
                  available: true,
                  lastActivityAt: null,
                ),
              ],
            ),
          ),
          chatRepositoryProvider.overrideWithValue(
            _FakeChatRepository(
              messagesByChannel: const {
                'dm_1': [
                  ChatMessage(
                    id: 'msg_1',
                    author: 'usr_1',
                    text: 'hello',
                    createdAt: '2026-03-28T00:00:00Z',
                    isAgent: false,
                  ),
                ],
              },
            ),
          ),
          agentRepositoryProvider.overrideWithValue(_FakeAgentRepository()),
          realtimeSocketServiceProvider.overrideWithValue(
            _FakeRealtimeSocketService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(
        workspaceShellControllerProvider.future,
      );

      expect(state.selectedConversation.id, 'dm_1');
      expect(
        state.selectedConversation.kind,
        WorkspaceSelectedConversationKind.directMessage,
      );
      expect(state.messages, hasLength(1));
    },
  );

  test(
    'sendMessage prefixes @team when collaboration mode is enabled',
    () async {
      final socketService = _FakeRealtimeSocketService();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(
              currentSessionValue: const AuthSession(
                userId: 'usr_1',
                email: 'demo@microflow.local',
                displayName: 'Demo User',
                accessToken: 'token',
                refreshToken: 'refresh',
              ),
            ),
          ),
          workspaceRepositoryProvider.overrideWithValue(
            _FakeWorkspaceRepository(
              workspaces: const [
                WorkspaceSummary(id: 'ws_1', name: 'MicroFlow', memberCount: 1),
              ],
              channels: const [
                ChannelSummary(id: 'chn_1', name: 'general', unreadCount: 0),
              ],
              conversations: const [
                WorkspaceConversation(
                  id: 'chn_1',
                  title: 'general',
                  subtitle: 'Team updates',
                  kind: 'CHANNEL',
                  unreadCount: 0,
                  available: true,
                  lastActivityAt: null,
                ),
              ],
            ),
          ),
          chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
          agentRepositoryProvider.overrideWithValue(
            _FakeAgentRepository(
              agents: const [
                AgentDescriptor(
                  agentKey: 'assistant',
                  provider: 'openai',
                  enabled: true,
                ),
              ],
            ),
          ),
          realtimeSocketServiceProvider.overrideWithValue(socketService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(workspaceShellControllerProvider.future);
      final controller = container.read(
        workspaceShellControllerProvider.notifier,
      );
      await controller.connectRealtime('token');
      controller.setCollaborationModeForSelectedConversation(true);
      await controller.sendMessage('Need a shared plan');

      expect(socketService.lastSentContent, '@team Need a shared plan');
    },
  );

  test(
    'collaboration realtime events update the selected conversation status',
    () async {
      final socketService = _FakeRealtimeSocketService();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(
              currentSessionValue: const AuthSession(
                userId: 'usr_1',
                email: 'demo@microflow.local',
                displayName: 'Demo User',
                accessToken: 'token',
                refreshToken: 'refresh',
              ),
            ),
          ),
          workspaceRepositoryProvider.overrideWithValue(
            _FakeWorkspaceRepository(
              workspaces: const [
                WorkspaceSummary(id: 'ws_1', name: 'MicroFlow', memberCount: 1),
              ],
              channels: const [
                ChannelSummary(id: 'chn_1', name: 'general', unreadCount: 0),
              ],
              conversations: const [
                WorkspaceConversation(
                  id: 'chn_1',
                  title: 'general',
                  subtitle: 'Team updates',
                  kind: 'CHANNEL',
                  unreadCount: 0,
                  available: true,
                  lastActivityAt: null,
                ),
              ],
            ),
          ),
          chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
          agentRepositoryProvider.overrideWithValue(_FakeAgentRepository()),
          realtimeSocketServiceProvider.overrideWithValue(socketService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(workspaceShellControllerProvider.future);
      await container
          .read(workspaceShellControllerProvider.notifier)
          .connectRealtime('token');
      await Future<void>.delayed(Duration.zero);
      socketService.emit({
        'type': 'COLLABORATION_STARTED',
        'payload': {
          'channelId': 'chn_1',
          'collaborationId': 'col_1',
          'trigger': '@team',
          'round': 1,
          'maxRounds': 2,
        },
      });
      socketService.emit({
        'type': 'COLLABORATION_STEP',
        'payload': {
          'channelId': 'chn_1',
          'collaborationId': 'col_1',
          'round': 1,
          'agentKey': 'assistant',
          'status': 'RUNNING',
        },
      });
      socketService.emit({
        'type': 'COLLABORATION_COMPLETED',
        'payload': {
          'channelId': 'chn_1',
          'collaborationId': 'col_1',
          'trigger': '@team',
          'round': 2,
        },
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container
          .read(workspaceShellControllerProvider)
          .valueOrNull;
      expect(state, isNotNull);
      expect(state!.selectedCollaborationStatus, isNotNull);
      expect(state.selectedCollaborationStatus!.status, 'COMPLETED');
      expect(state.selectedCollaborationStatus!.maxRounds, 2);
      expect(state.selectedCollaborationStatus!.activeAgentKey, 'assistant');
    },
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.currentSessionValue});

  final AuthSession? currentSessionValue;

  @override
  Future<AuthSession?> currentSession() async => currentSessionValue;

  @override
  Future<AuthSession> login({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}

class _FakeWorkspaceRepository implements WorkspaceRepository {
  _FakeWorkspaceRepository({
    this.workspaces = const [],
    this.channels = const [],
    this.conversations = const [],
  });

  final List<WorkspaceSummary> workspaces;
  final List<ChannelSummary> channels;
  final List<WorkspaceConversation> conversations;

  @override
  Future<List<ChannelSummary>> listChannels(String workspaceId) async =>
      channels;

  @override
  Future<List<WorkspaceConversation>> listConversations(
    String workspaceId,
  ) async => conversations;

  @override
  Future<List<WorkspaceSummary>> listWorkspaces() async => workspaces;
}

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({this.messagesByChannel = const {}});

  final Map<String, List<ChatMessage>> messagesByChannel;

  @override
  Future<List<ChatMessage>> listMessages(String channelId) async {
    return messagesByChannel[channelId] ?? const [];
  }

  @override
  Future<ChatMessage> sendMessage({
    required String workspaceId,
    required String channelId,
    required String senderUserId,
    required String content,
  }) {
    throw UnimplementedError();
  }
}

class _FakeAgentRepository implements AgentRepository {
  _FakeAgentRepository({this.agents = const []});

  final List<AgentDescriptor> agents;

  @override
  Future<List<AgentDescriptor>> listAgents(String workspaceId) async => agents;

  @override
  Future<List<AgentDiagnostic>> listDiagnostics(String workspaceId) async =>
      const [];

  @override
  Future<void> updateRoleStrategy({
    required String workspaceId,
    required String agentKey,
    required String roleStrategy,
  }) async {}

  @override
  Future<List<AgentRun>> listRuns(String workspaceId) async => const [];
}

class _FakeRealtimeSocketService implements RealtimeSocketService {
  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();
  String? lastSentContent;

  @override
  Stream<dynamic> get rawEvents => _controller.stream;

  @override
  Future<void> connect({required String token}) async {}

  @override
  Future<void> disconnect() async {
    await _controller.close();
  }

  @override
  Future<void> sendMessage({
    required String workspaceId,
    required String channelId,
    required String content,
  }) async {
    lastSentContent = content;
  }

  @override
  Future<void> subscribe(String channelId) async {}

  void emit(Map<String, Object?> event) {
    _controller.add(event);
  }
}
