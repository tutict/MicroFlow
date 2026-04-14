import 'dart:async';
import 'dart:typed_data';

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
import 'package:microflow_frontend/features/chat/domain/entities/collaboration_event.dart';
import 'package:microflow_frontend/features/chat/domain/entities/collaboration_run.dart';
import 'package:microflow_frontend/features/chat/domain/repositories/chat_repository.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_conversation.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/knowledge_document.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_member.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_summary.dart';
import 'package:microflow_frontend/features/workspace/domain/repositories/workspace_repository.dart';
import 'package:microflow_frontend/features/workspace/presentation/providers/workspace_shell_controller.dart';
import 'package:microflow_frontend/features/workspace/presentation/state/workspace_selected_conversation.dart';

void main() {
  test(
    'uploadKnowledgeDocument forwards the selected conversation channel scope',
    () async {
      final workspaceRepository = _FakeWorkspaceRepository(
        workspaces: const [
          WorkspaceSummary(id: 'ws_1', name: 'Core', memberCount: 1),
        ],
        channels: const [
          ChannelSummary(id: 'chn_1', name: 'general', unreadCount: 0),
        ],
        conversations: const [
          WorkspaceConversation(
            id: 'chn_1',
            title: 'general',
            subtitle: 'Core thread',
            kind: 'CHANNEL',
            unreadCount: 0,
            available: true,
            lastActivityAt: null,
          ),
        ],
      );
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
          workspaceRepositoryProvider.overrideWithValue(workspaceRepository),
          chatRepositoryProvider.overrideWithValue(
            _FakeChatRepository(
              collaborationRunsByChannel: const {
                'chn_2': [
                  CollaborationRun(
                    collaborationId: 'col_ops',
                    workspaceId: 'ws_2',
                    channelId: 'chn_2',
                    status: 'RUNNING',
                    round: 0,
                    maxRounds: 2,
                    startedAt: '2026-04-13T00:00:00Z',
                    lastEventAt: '2026-04-13T00:00:00Z',
                    trigger: '@team',
                    events: [
                      CollaborationEvent(
                        id: 'evt_1',
                        workspaceId: 'ws_2',
                        channelId: 'chn_2',
                        collaborationId: 'col_ops',
                        eventType: 'COLLABORATION_STARTED',
                        status: 'RUNNING',
                        round: 0,
                        maxRounds: 2,
                        createdAt: '2026-04-13T00:00:00Z',
                        trigger: '@team',
                      ),
                    ],
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

      await container.read(workspaceShellControllerProvider.future);
      await container
          .read(workspaceShellControllerProvider.notifier)
          .uploadKnowledgeDocument(
            fileName: 'guide.md',
            bytes: Uint8List.fromList('hello'.codeUnits),
          );

      expect(workspaceRepository.lastUploadedWorkspaceId, 'ws_1');
      expect(workspaceRepository.lastUploadedChannelId, 'chn_1');
    },
  );

  test(
    'selectWorkspace restores cached knowledge documents when switching back',
    () async {
      final workspaceRepository = _FakeWorkspaceRepository(
        workspaces: const [
          WorkspaceSummary(id: 'ws_1', name: 'Core', memberCount: 1),
          WorkspaceSummary(id: 'ws_2', name: 'Ops', memberCount: 1),
        ],
        channelsByWorkspace: const {
          'ws_1': [
            ChannelSummary(id: 'chn_1', name: 'general', unreadCount: 0),
          ],
          'ws_2': [ChannelSummary(id: 'chn_2', name: 'ops', unreadCount: 0)],
        },
        conversationsByWorkspace: const {
          'ws_1': [
            WorkspaceConversation(
              id: 'chn_1',
              title: 'general',
              subtitle: 'Core thread',
              kind: 'CHANNEL',
              unreadCount: 0,
              available: true,
              lastActivityAt: null,
            ),
          ],
          'ws_2': [
            WorkspaceConversation(
              id: 'chn_2',
              title: 'ops',
              subtitle: 'Ops thread',
              kind: 'CHANNEL',
              unreadCount: 0,
              available: true,
              lastActivityAt: null,
            ),
          ],
        },
        knowledgeDocumentsByWorkspace: const {
          'ws_2': [
            KnowledgeDocument(
              id: 'doc_ops_1',
              workspaceId: 'ws_2',
              channelId: 'chn_2',
              fileName: 'ops-runbook.md',
              contentType: 'text/markdown',
              sizeBytes: 128,
              summary: 'Ops runbook',
              snippetCount: 2,
              status: 'READY',
              createdAt: '2026-04-13T00:00:00Z',
            ),
          ],
        },
      );
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
          workspaceRepositoryProvider.overrideWithValue(workspaceRepository),
          chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
          agentRepositoryProvider.overrideWithValue(_FakeAgentRepository()),
          realtimeSocketServiceProvider.overrideWithValue(
            _FakeRealtimeSocketService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(workspaceShellControllerProvider.future);
      await container
          .read(workspaceShellControllerProvider.notifier)
          .uploadKnowledgeDocument(
            fileName: 'architecture.md',
            bytes: Uint8List.fromList('doc'.codeUnits),
            inheritSelectedConversation: false,
          );
      await container
          .read(workspaceShellControllerProvider.notifier)
          .selectWorkspace('ws_2');
      await container
          .read(workspaceShellControllerProvider.notifier)
          .selectWorkspace('ws_1');

      final state = container
          .read(workspaceShellControllerProvider)
          .valueOrNull;
      expect(state, isNotNull);
      expect(state!.workspaceId, 'ws_1');
      expect(state.knowledgeDocuments, hasLength(1));
      expect(state.knowledgeDocuments.first.fileName, 'architecture.md');
    },
  );

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
          'maxRounds': 2,
          'agentKey': 'assistant',
          'status': 'RUNNING',
          'stage': 'analyze',
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
      expect(state.selectedCollaborationStatus!.stage, 'synthesize');
      expect(state.selectedCollaborationStatus!.activeAgentKey, 'assistant');
      expect(state.selectedCollaborationRuns, hasLength(1));
      expect(state.selectedCollaborationRuns.first.events, hasLength(3));
      expect(state.selectedCollaborationRuns.first.events[1].stage, 'analyze');
    },
  );

  test('selectWorkspace swaps the active workspace shell payload', () async {
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
              WorkspaceSummary(id: 'ws_1', name: 'Core', memberCount: 1),
              WorkspaceSummary(id: 'ws_2', name: 'Ops', memberCount: 1),
            ],
            channelsByWorkspace: const {
              'ws_1': [
                ChannelSummary(id: 'chn_1', name: 'general', unreadCount: 0),
              ],
              'ws_2': [
                ChannelSummary(id: 'chn_2', name: 'knowledge', unreadCount: 0),
              ],
            },
            conversationsByWorkspace: const {
              'ws_1': [
                WorkspaceConversation(
                  id: 'chn_1',
                  title: 'general',
                  subtitle: 'Core thread',
                  kind: 'CHANNEL',
                  unreadCount: 0,
                  available: true,
                  lastActivityAt: null,
                ),
              ],
              'ws_2': [
                WorkspaceConversation(
                  id: 'chn_2',
                  title: 'knowledge',
                  subtitle: 'Ops docs',
                  kind: 'CHANNEL',
                  unreadCount: 0,
                  available: true,
                  lastActivityAt: null,
                ),
              ],
            },
          ),
        ),
        chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
        agentRepositoryProvider.overrideWithValue(_FakeAgentRepository()),
        realtimeSocketServiceProvider.overrideWithValue(
          _FakeRealtimeSocketService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(workspaceShellControllerProvider.future);
    await container
        .read(workspaceShellControllerProvider.notifier)
        .selectWorkspace('ws_2');

    final state = container.read(workspaceShellControllerProvider).valueOrNull;
    expect(state, isNotNull);
    expect(state!.workspaceId, 'ws_2');
    expect(state.workspaceName, 'Ops');
    expect(state.selectedConversation.id, 'chn_2');
  });
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
    this.channelsByWorkspace = const {},
    this.conversationsByWorkspace = const {},
    this.knowledgeDocumentsByWorkspace = const {},
  });

  final List<WorkspaceSummary> workspaces;
  final List<ChannelSummary> channels;
  final List<WorkspaceConversation> conversations;
  final Map<String, List<ChannelSummary>> channelsByWorkspace;
  final Map<String, List<WorkspaceConversation>> conversationsByWorkspace;
  final Map<String, List<KnowledgeDocument>> knowledgeDocumentsByWorkspace;
  String? lastUploadedWorkspaceId;
  String? lastUploadedChannelId;

  @override
  Future<WorkspaceSummary> createWorkspace(String name) async =>
      WorkspaceSummary(id: 'ws_new', name: name, memberCount: 1);

  @override
  Future<List<ChannelSummary>> listChannels(String workspaceId) async =>
      channelsByWorkspace[workspaceId] ?? channels;

  @override
  Future<List<WorkspaceConversation>> listConversations(
    String workspaceId,
  ) async => conversationsByWorkspace[workspaceId] ?? conversations;

  @override
  Future<List<WorkspaceMember>> listMembers(String workspaceId) async => const [
    WorkspaceMember(
      userId: 'usr_1',
      email: 'demo@microflow.local',
      displayName: 'Demo User',
      role: 'OWNER',
      joinedAt: '2026-04-13T00:00:00Z',
    ),
  ];

  @override
  Future<List<WorkspaceMember>> addMemberByEmail({
    required String workspaceId,
    required String email,
  }) async => [
    const WorkspaceMember(
      userId: 'usr_1',
      email: 'demo@microflow.local',
      displayName: 'Demo User',
      role: 'OWNER',
      joinedAt: '2026-04-13T00:00:00Z',
    ),
    WorkspaceMember(
      userId: 'usr_2',
      email: email,
      displayName: 'Invited User',
      role: 'MEMBER',
      joinedAt: '2026-04-13T01:00:00Z',
    ),
  ];

  @override
  Future<List<KnowledgeDocument>> listKnowledgeDocuments(
    String workspaceId,
  ) async => knowledgeDocumentsByWorkspace[workspaceId] ?? const [];

  @override
  Future<List<WorkspaceSummary>> listWorkspaces() async => workspaces;

  @override
  Future<KnowledgeDocument> uploadKnowledgeDocument({
    required String workspaceId,
    required String fileName,
    required Uint8List bytes,
    String? channelId,
  }) async {
    lastUploadedWorkspaceId = workspaceId;
    lastUploadedChannelId = channelId;
    return KnowledgeDocument(
      id: 'doc_1',
      workspaceId: workspaceId,
      channelId: channelId,
      fileName: fileName,
      contentType: 'text/plain',
      sizeBytes: bytes.length,
      summary: 'Uploaded in test',
      snippetCount: 1,
      status: 'READY',
      createdAt: '2026-04-13T00:00:00Z',
    );
  }
}

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({
    this.messagesByChannel = const {},
    this.collaborationRunsByChannel = const {},
  });

  final Map<String, List<ChatMessage>> messagesByChannel;
  final Map<String, List<CollaborationRun>> collaborationRunsByChannel;

  @override
  Future<List<ChatMessage>> listMessages(String channelId) async {
    return messagesByChannel[channelId] ?? const [];
  }

  @override
  Future<List<CollaborationEvent>> listCollaborationHistory(
    String channelId,
  ) async {
    return const [];
  }

  @override
  Future<List<CollaborationRun>> listCollaborationRuns(String channelId) async {
    return collaborationRunsByChannel[channelId] ?? const [];
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
