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
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_run.dart'
    as runtime;
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_run_event.dart';
import 'package:microflow_frontend/features/agent_runtime/presentation/providers/agent_runtime_providers.dart';
import 'package:microflow_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:microflow_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:microflow_frontend/features/chat/domain/entities/channel_summary.dart';
import 'package:microflow_frontend/features/chat/domain/entities/chat_message.dart';
import 'package:microflow_frontend/features/chat/domain/entities/collaboration_event.dart';
import 'package:microflow_frontend/features/chat/domain/entities/collaboration_run.dart';
import 'package:microflow_frontend/features/chat/domain/repositories/chat_repository.dart';
import 'package:microflow_frontend/features/chat/presentation/state/chat_connection_status.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_conversation.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/knowledge_document.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_member.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_member_role.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_summary.dart';
import 'package:microflow_frontend/features/workspace/domain/repositories/workspace_repository.dart';
import 'package:microflow_frontend/features/workspace/presentation/providers/workspace_shell_controller.dart';
import 'package:microflow_frontend/features/workspace/presentation/state/workspace_selected_conversation.dart';

import 'support/recording_runtime_repository.dart';

void main() {
  test(
    'returning through cached workspaces clears a cancelled switch indicator',
    () async {
      final workspaces = _DeferredWorkspaceRepository();
      final container = _messageContainer(
        _FakeChatRepository(),
        workspaceRepository: workspaces,
      );
      addTearDown(container.dispose);
      await container.read(workspaceShellControllerProvider.future);
      final controller = container.read(
        workspaceShellControllerProvider.notifier,
      );
      await controller.selectWorkspace('ws_2');
      await controller.selectWorkspace('ws_1');
      final pending = controller.selectWorkspace('ws_3');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        container
            .read(workspaceShellControllerProvider)
            .requireValue
            .isSwitchingWorkspace,
        isTrue,
      );
      await controller.selectWorkspace('ws_2');
      await controller.selectWorkspace('ws_1');
      workspaces.pending.complete(const []);
      await pending;
      final current = container
          .read(workspaceShellControllerProvider)
          .requireValue;
      expect(current.workspaceId, 'ws_1');
      expect(current.isSwitchingWorkspace, isFalse);
    },
  );

  test(
    'a conversation load cannot restore a completed send busy flag',
    () async {
      final chat = _DeferredSelectionRepository();
      final container = _messageContainer(chat);
      addTearDown(container.dispose);
      await container.read(workspaceShellControllerProvider.future);
      final controller = container.read(
        workspaceShellControllerProvider.notifier,
      );
      final sending = controller.sendMessage('Sent while opening');
      chat.deferChannel = 'chn_2';
      final selecting = controller.selectConversation(
        conversationId: 'chn_2',
        title: 'other',
        kind: WorkspaceSelectedConversationKind.channel,
        isAvailable: true,
      );
      chat.response.complete(
        const ChatMessage(
          id: 'sent',
          author: 'usr_1',
          text: 'Sent while opening',
          createdAt: '2026-11-26T00:00:00Z',
          isAgent: false,
        ),
      );
      await sending;
      chat.history.complete(const []);
      await selecting;
      final current = container
          .read(workspaceShellControllerProvider)
          .requireValue;
      expect(current.selectedConversationId, 'chn_2');
      expect(current.isSendingMessage, isFalse);
    },
  );

  test(
    'an old conversation load cannot restore a previous workspace',
    () async {
      final chat = _DeferredSelectionRepository();
      final container = _messageContainer(chat);
      addTearDown(container.dispose);
      await container.read(workspaceShellControllerProvider.future);
      final controller = container.read(
        workspaceShellControllerProvider.notifier,
      );
      chat.deferChannel = 'chn_2';
      final selecting = controller.selectConversation(
        conversationId: 'chn_2',
        title: 'other',
        kind: WorkspaceSelectedConversationKind.channel,
        isAvailable: true,
      );
      await controller.selectWorkspace('ws_2');
      chat.history.complete(const []);
      await selecting;
      expect(
        container
            .read(workspaceShellControllerProvider)
            .requireValue
            .workspaceId,
        'ws_2',
      );
    },
  );

  test(
    'returning to the current conversation cancels an older selection intent',
    () async {
      final chat = _DeferredSelectionRepository();
      final container = _messageContainer(chat);
      addTearDown(container.dispose);
      await container.read(workspaceShellControllerProvider.future);
      final controller = container.read(
        workspaceShellControllerProvider.notifier,
      );
      chat.deferChannel = 'chn_2';
      final selecting = controller.selectConversation(
        conversationId: 'chn_2',
        title: 'other',
        kind: WorkspaceSelectedConversationKind.channel,
        isAvailable: true,
      );
      await controller.selectConversation(
        conversationId: 'chn_1',
        title: 'general',
        kind: WorkspaceSelectedConversationKind.channel,
        isAvailable: true,
      );
      chat.history.complete(const []);
      await selecting;
      expect(
        container
            .read(workspaceShellControllerProvider)
            .requireValue
            .selectedConversationId,
        'chn_1',
      );
    },
  );

  test('a failed message send reaches the composer as an error', () async {
    final chat = _PendingMessageRepository();
    final container = _messageContainer(chat);
    addTearDown(container.dispose);
    await container.read(workspaceShellControllerProvider.future);
    final controller = container.read(
      workspaceShellControllerProvider.notifier,
    );
    final sending = controller.sendMessage('Keep this draft');
    final result = expectLater(sending, throwsA(isA<StateError>()));
    chat.response.completeError(StateError('connection lost'));
    await result;
    final state = container.read(workspaceShellControllerProvider).requireValue;
    expect(state.isSendingMessage, isFalse);
    expect(state.messageError, contains('connection lost'));
  });

  test(
    'a late message response stays out of a different conversation',
    () async {
      final chat = _PendingMessageRepository();
      final container = _messageContainer(chat);
      addTearDown(container.dispose);
      await container.read(workspaceShellControllerProvider.future);
      final controller = container.read(
        workspaceShellControllerProvider.notifier,
      );
      final sending = controller.sendMessage('Channel one message');
      await controller.selectConversation(
        conversationId: 'chn_2',
        title: 'other',
        kind: WorkspaceSelectedConversationKind.channel,
        isAvailable: true,
      );
      chat.response.complete(
        const ChatMessage(
          id: 'late',
          author: 'usr_1',
          text: 'Channel one message',
          createdAt: '2026-11-25T10:00:00Z',
          isAgent: false,
        ),
      );
      await sending;
      final state = container
          .read(workspaceShellControllerProvider)
          .requireValue;
      expect(state.selectedConversationId, 'chn_2');
      expect(state.messages, isEmpty);
      expect(state.isSendingMessage, isFalse);
      expect(
        state.conversations
            .firstWhere((conversation) => conversation.id == 'chn_1')
            .subtitle,
        contains('Channel one message'),
      );
    },
  );

  test('a late send failure belongs to its original workspace', () async {
    final chat = _PendingMessageRepository();
    final container = _messageContainer(chat);
    addTearDown(container.dispose);
    await container.read(workspaceShellControllerProvider.future);
    final controller = container.read(
      workspaceShellControllerProvider.notifier,
    );
    final sending = controller.sendMessage('Workspace one message');
    final result = expectLater(sending, throwsA(isA<StateError>()));
    await controller.selectWorkspace('ws_2');
    chat.response.completeError(StateError('original send failed'));
    await result;
    expect(
      container
          .read(workspaceShellControllerProvider)
          .requireValue
          .messageError,
      isNull,
    );
    await controller.selectWorkspace('ws_1');
    final restored = container
        .read(workspaceShellControllerProvider)
        .requireValue;
    expect(restored.isSendingMessage, isFalse);
    expect(restored.messageError, contains('original send failed'));
  });

  test('history catch-up applies a newer snapshot before suppressing its socket event', () async {
    final repository = RecordingRuntimeRepository(
      runs: [testRun(status: runtime.AgentRunStatus.running)],
    );
    repository.events['run_1'] = [_historyEvent(1)];
    final socket = _FakeRealtimeSocketService();
    final container = _runtimeContainer(repository, socket);
    const query = (workspaceId: 'ws_1', taskId: null);
    container.listen(agentRunsProvider(query), (_, _) {});
    container.listen(agentRunEventsProvider('run_1'), (_, _) {});
    await container.read(agentRunsProvider(query).future);
    await container.read(agentRunEventsProvider('run_1').future);
    await _connectRuntime(container);
    final completed = testRun(
      status: runtime.AgentRunStatus.succeeded,
      updatedAt: '2026-11-23T10:00:05Z',
    );
    final latestPayload =
        _runtimeEvent(5, 'RUN_SUCCEEDED', completed)['payload']
            as Map<String, Object?>;
    repository.events['run_1'] = [
      _historyEvent(1),
      _historyEvent(2),
      _historyEvent(3),
      _historyEvent(4),
      AgentRunEvent(
        id: 'event_5',
        seq: 5,
        type: 'RUN_SUCCEEDED',
        payload: latestPayload,
      ),
    ];
    socket.emit(
      _runtimeEvent(
        3,
        'RUN_WAITING_APPROVAL',
        testRun(
          status: runtime.AgentRunStatus.waitingApproval,
          updatedAt: '2026-11-23T10:00:03Z',
        ),
      ),
    );
    await _flushRuntime();
    expect(
      container.read(agentRunsProvider(query)).value?.single.status,
      runtime.AgentRunStatus.succeeded,
    );
    socket.emit(_runtimeEvent(5, 'RUN_SUCCEEDED', completed));
    await _flushRuntime();
    expect(
      container.read(agentRunsProvider(query)).value?.single.status,
      runtime.AgentRunStatus.succeeded,
    );
  });

  test(
    'runtime socket snapshots update one cached run without list requests',
    () async {
      final repository = RecordingRuntimeRepository(
        runs: [
          testRun(),
          testRun(id: 'run_2', workspaceId: 'ws_2'),
        ],
      );
      final socket = _FakeRealtimeSocketService();
      final container = _runtimeContainer(repository, socket);
      const first = (workspaceId: 'ws_1', taskId: null);
      const other = (workspaceId: 'ws_2', taskId: null);
      container.listen(agentRunsProvider(first), (_, _) {});
      container.listen(agentRunsProvider(other), (_, _) {});
      await container.read(agentRunsProvider(first).future);
      await container.read(agentRunsProvider(other).future);
      await _connectRuntime(container);
      final requests = repository.listQueries.length;
      socket.emit(
        _runtimeEvent(
          1,
          'RUN_STARTED',
          testRun(status: runtime.AgentRunStatus.running),
        ),
      );
      await _flushRuntime();
      expect(
        container.read(agentRunsProvider(first)).value?.single.status,
        runtime.AgentRunStatus.running,
      );
      expect(repository.listQueries, hasLength(requests));
      expect(
        container.read(agentRunsProvider(other)).value?.single.id,
        'run_2',
      );
    },
  );

  test('duplicate and late runtime events do not regress the run or reload resources', () async {
    final repository = RecordingRuntimeRepository(runs: [testRun()]);
    final socket = _FakeRealtimeSocketService();
    final container = _runtimeContainer(repository, socket);
    const query = (workspaceId: 'ws_1', taskId: null);
    container.listen(agentRunsProvider(query), (_, _) {});
    await container.read(agentRunsProvider(query).future);
    await _connectRuntime(container);
    socket.emit(
      _runtimeEvent(
        2,
        'RUN_SUCCEEDED',
        testRun(status: runtime.AgentRunStatus.succeeded),
      ),
    );
    await _flushRuntime();
    final requests = repository.getQueries.length;
    socket.emit(
      _runtimeEvent(
        1,
        'RUN_STARTED',
        testRun(status: runtime.AgentRunStatus.running),
      ),
    );
    socket.emit(
      _runtimeEvent(
        2,
        'RUN_SUCCEEDED',
        testRun(status: runtime.AgentRunStatus.succeeded),
      ),
    );
    await _flushRuntime();
    expect(
      container.read(agentRunsProvider(query)).value?.single.status,
      runtime.AgentRunStatus.succeeded,
    );
    expect(repository.getQueries, hasLength(requests));
  });

  test(
    'a socket gap fetches missing event pages from the current cursor',
    () async {
      final repository = RecordingRuntimeRepository(runs: [testRun()]);
      repository.events['run_1'] = [_historyEvent(1)];
      final socket = _FakeRealtimeSocketService();
      final container = _runtimeContainer(repository, socket);
      container.listen(agentRunEventsProvider('run_1'), (_, _) {});
      await container.read(agentRunEventsProvider('run_1').future);
      await _connectRuntime(container);
      socket.emit(
        _runtimeEvent(
          1,
          'RUN_STARTED',
          testRun(status: runtime.AgentRunStatus.running),
        ),
      );
      await _flushRuntime();
      repository.eventQueries.clear();
      repository.events['run_1'] = [
        for (var seq = 1; seq <= 405; seq++) _historyEvent(seq),
      ];
      socket.emit(
        _runtimeEvent(
          405,
          'RUN_SUCCEEDED',
          testRun(status: runtime.AgentRunStatus.succeeded),
        ),
      );
      await _flushRuntime();
      final trail = container.read(agentRunEventsProvider('run_1')).value!;
      expect(trail.last.seq, 405);
      expect(trail.map((event) => event.seq).toSet(), hasLength(trail.length));
      expect(repository.eventQueries.map((query) => query.afterSeq), [
        1,
        201,
        401,
      ]);
    },
  );

  test(
    'failed gap recovery preserves progress and catches up on the next event',
    () async {
      final repository = RecordingRuntimeRepository(runs: [testRun()]);
      repository.events['run_1'] = [_historyEvent(1)];
      final socket = _FakeRealtimeSocketService();
      final container = _runtimeContainer(repository, socket);
      const query = (workspaceId: 'ws_1', taskId: null);
      container.listen(agentRunsProvider(query), (_, _) {});
      container.listen(agentRunEventsProvider('run_1'), (_, _) {});
      await container.read(agentRunsProvider(query).future);
      await container.read(agentRunEventsProvider('run_1').future);
      await _connectRuntime(container);
      socket.emit(
        _runtimeEvent(
          1,
          'RUN_STARTED',
          testRun(status: runtime.AgentRunStatus.running),
        ),
      );
      await _flushRuntime();
      repository.failEventsAfter = 1;
      socket.emit(
        _runtimeEvent(
          3,
          'RUN_WAITING_APPROVAL',
          testRun(status: runtime.AgentRunStatus.waitingApproval),
        ),
      );
      await _flushRuntime();
      expect(
        container.read(agentRunsProvider(query)).value?.single.status,
        runtime.AgentRunStatus.waitingApproval,
      );
      expect(
        container.read(
          agentReadErrorProvider((
            resource: AgentReadResource.events,
            id: 'run_1',
          )),
        ),
        isNotNull,
      );
      expect(
        container.read(agentRunEventsProvider('run_1')).value?.last.seq,
        1,
      );
      repository.failEventsAfter = null;
      repository.events['run_1'] = [
        for (var seq = 1; seq <= 4; seq++) _historyEvent(seq),
      ];
      socket.emit(
        _runtimeEvent(
          4,
          'RUN_SUCCEEDED',
          testRun(status: runtime.AgentRunStatus.succeeded),
        ),
      );
      await _flushRuntime();
      expect(
        container.read(
          agentReadErrorProvider((
            resource: AgentReadResource.events,
            id: 'run_1',
          )),
        ),
        isNull,
      );
      expect(
        container.read(agentRunEventsProvider('run_1')).value?.last.seq,
        4,
      );
    },
  );

  test(
    'reconnection refreshes the active workspace and resumes the event cursor',
    () async {
      final repository = RecordingRuntimeRepository(
        runs: [
          testRun(),
          testRun(id: 'run_2', workspaceId: 'ws_2'),
        ],
      );
      repository.events['run_1'] = [_historyEvent(1)];
      final socket = _FakeRealtimeSocketService();
      final container = _runtimeContainer(repository, socket);
      const query = (workspaceId: 'ws_1', taskId: null);
      const other = (workspaceId: 'ws_2', taskId: null);
      container.listen(agentRunsProvider(query), (_, _) {});
      container.listen(agentRunsProvider(other), (_, _) {});
      container.listen(agentRunEventsProvider('run_1'), (_, _) {});
      await container.read(agentRunsProvider(query).future);
      await container.read(agentRunsProvider(other).future);
      await container.read(agentRunEventsProvider('run_1').future);
      await _connectRuntime(container);
      repository.listQueries.clear();
      repository.eventQueries.clear();
      repository.runs = [
        testRun(status: runtime.AgentRunStatus.succeeded),
        testRun(id: 'run_2', workspaceId: 'ws_2'),
      ];
      repository.events['run_1'] = [_historyEvent(1), _historyEvent(2)];
      await container
          .read(workspaceShellControllerProvider.notifier)
          .connectRealtime('token');
      await _flushRuntime();
      expect(
        container.read(agentRunsProvider(query)).value?.single.status,
        runtime.AgentRunStatus.succeeded,
      );
      expect(repository.listQueries, [(workspaceId: 'ws_1', taskId: null)]);
      expect(repository.eventQueries.map((query) => query.afterSeq), [1]);
    },
  );

  test('transport closure updates the connection state instead of leaving it connected', () async {
    final socket = _FakeRealtimeSocketService();
    final container = _runtimeContainer(RecordingRuntimeRepository(), socket);
    await _connectRuntime(container);
    socket.emit({
      'type': 'ERROR',
      'payload': {
        'connectionState': 'DISCONNECTED',
        'message': 'WebSocket disconnected',
      },
    });
    await _flushRuntime();
    expect(
      container.read(workspaceShellControllerProvider).value?.connectionStatus,
      ChatConnectionStatus.disconnected,
    );
  });

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

      final state = container.read(workspaceShellControllerProvider).value;
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

  test('build falls back to the first available conversation when channels are empty', () async {
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

    final state = await container.read(workspaceShellControllerProvider.future);

    expect(state.selectedConversation.id, 'dm_1');
    expect(
      state.selectedConversation.kind,
      WorkspaceSelectedConversationKind.directMessage,
    );
    expect(state.messages, hasLength(1));
  });

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

      final state = container.read(workspaceShellControllerProvider).value;
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

    final state = container.read(workspaceShellControllerProvider).value;
    expect(state, isNotNull);
    expect(state!.workspaceId, 'ws_2');
    expect(state.workspaceName, 'Ops');
    expect(state.selectedConversation.id, 'chn_2');
  });
}

ProviderContainer _runtimeContainer(
  RecordingRuntimeRepository runtime,
  _FakeRealtimeSocketService socket,
) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        _FakeAuthRepository(
          currentSessionValue: const AuthSession(
            userId: 'usr_1',
            email: 'demo@microflow.local',
            displayName: 'Demo',
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
        ),
      ),
      chatRepositoryProvider.overrideWithValue(_FakeChatRepository()),
      agentRepositoryProvider.overrideWithValue(_FakeAgentRepository()),
      agentRuntimeRepositoryProvider.overrideWithValue(runtime),
      realtimeSocketServiceProvider.overrideWithValue(socket),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _connectRuntime(ProviderContainer container) async {
  await container.read(workspaceShellControllerProvider.future);
  await _flushRuntime();
  await container
      .read(workspaceShellControllerProvider.notifier)
      .connectRealtime('token');
  await _flushRuntime();
}

Future<void> _flushRuntime() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

AgentRunEvent _historyEvent(int seq) => AgentRunEvent(
  id: 'event_$seq',
  seq: seq,
  type: 'MODEL_TURN_COMPLETED',
  payload: const {},
);

Map<String, Object?> _runtimeEvent(
  int seq,
  String type,
  runtime.AgentRunSummary run,
) => {
  'type': 'AGENT_RUN_EVENT',
  'payload': {
    'seq': seq,
    'runId': run.id,
    'workspaceId': run.workspaceId,
    'taskId': run.taskId,
    'type': type,
    'run': {
      'id': run.id,
      'workspaceId': run.workspaceId,
      'taskId': run.taskId,
      'agentKey': run.agentKey,
      'kind': run.kind,
      'goal': run.goal,
      'createdAt': run.createdAt,
      'updatedAt': run.updatedAt,
      'pendingApprovalId': run.pendingApprovalId,
      'status': run.status == runtime.AgentRunStatus.waitingApproval
          ? 'WAITING_APPROVAL'
          : run.status.name.toUpperCase(),
    },
  },
};

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
  Future<WorkspaceMember> changeMemberRole({
    required String workspaceId,
    required String userId,
    required WorkspaceMemberRole role,
  }) async => WorkspaceMember(
    userId: userId,
    email: 'member@microflow.local',
    displayName: 'Member',
    role: role.storedValue,
    joinedAt: '2026-04-13T00:00:00Z',
  );

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

ProviderContainer _messageContainer(
  ChatRepository chat, {
  WorkspaceRepository? workspaceRepository,
}) => ProviderContainer(
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
      workspaceRepository ??
          _FakeWorkspaceRepository(
            workspaces: const [
              WorkspaceSummary(id: 'ws_1', name: 'First', memberCount: 1),
              WorkspaceSummary(id: 'ws_2', name: 'Second', memberCount: 1),
            ],
            channels: const [
              ChannelSummary(id: 'chn_1', name: 'general', unreadCount: 0),
              ChannelSummary(id: 'chn_2', name: 'other', unreadCount: 0),
            ],
            conversations: const [
              WorkspaceConversation(
                id: 'chn_1',
                title: 'general',
                subtitle: '',
                kind: 'CHANNEL',
                unreadCount: 0,
                available: true,
                lastActivityAt: null,
              ),
              WorkspaceConversation(
                id: 'chn_2',
                title: 'other',
                subtitle: '',
                kind: 'CHANNEL',
                unreadCount: 0,
                available: true,
                lastActivityAt: null,
              ),
            ],
          ),
    ),
    chatRepositoryProvider.overrideWithValue(chat),
    agentRepositoryProvider.overrideWithValue(_FakeAgentRepository()),
    realtimeSocketServiceProvider.overrideWithValue(
      _FakeRealtimeSocketService(),
    ),
  ],
);

class _DeferredWorkspaceRepository extends _FakeWorkspaceRepository {
  _DeferredWorkspaceRepository()
    : super(
        workspaces: const [
          WorkspaceSummary(id: 'ws_1', name: 'First', memberCount: 1),
          WorkspaceSummary(id: 'ws_2', name: 'Second', memberCount: 1),
          WorkspaceSummary(id: 'ws_3', name: 'Third', memberCount: 1),
        ],
      );
  final pending = Completer<List<KnowledgeDocument>>();

  @override
  Future<List<KnowledgeDocument>> listKnowledgeDocuments(String workspaceId) =>
      workspaceId == 'ws_3'
      ? pending.future
      : super.listKnowledgeDocuments(workspaceId);
}

class _DeferredSelectionRepository extends _PendingMessageRepository {
  String? deferChannel;
  final history = Completer<List<ChatMessage>>();

  @override
  Future<List<ChatMessage>> listMessages(String channelId) {
    if (deferChannel == channelId) {
      deferChannel = null;
      return history.future;
    }
    return super.listMessages(channelId);
  }
}

class _PendingMessageRepository extends _FakeChatRepository {
  final response = Completer<ChatMessage>();

  @override
  Future<ChatMessage> sendMessage({
    required String workspaceId,
    required String channelId,
    required String senderUserId,
    required String content,
  }) => response.future;
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
