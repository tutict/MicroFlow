import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/features/agents/domain/entities/agent_descriptor.dart';
import 'package:microflow_frontend/features/agents/domain/entities/agent_run.dart';
import 'package:microflow_frontend/features/agents/presentation/widgets/agent_panel.dart';
import 'package:microflow_frontend/features/chat/domain/entities/channel_summary.dart';
import 'package:microflow_frontend/features/chat/domain/entities/chat_message.dart';
import 'package:microflow_frontend/features/chat/domain/entities/collaboration_event.dart';
import 'package:microflow_frontend/features/chat/domain/entities/collaboration_run.dart';
import 'package:microflow_frontend/features/chat/presentation/state/chat_connection_status.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_conversation.dart';
import 'package:microflow_frontend/features/workspace/presentation/pages/workspace_home_page.dart';
import 'package:microflow_frontend/features/workspace/presentation/providers/workspace_shell_controller.dart';
import 'package:microflow_frontend/features/workspace/presentation/state/workspace_selected_conversation.dart';
import 'package:microflow_frontend/features/workspace/presentation/state/workspace_shell_state.dart';
import 'package:microflow_frontend/features/workspace/presentation/widgets/workspace_panel.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

void main() {
  testWidgets('shows a bootstrap setup panel when no workspace is available', (
    tester,
  ) async {
    await _pumpWorkspaceHomePage(
      tester,
      state: _buildState(
        workspaceId: '',
        workspaceName: 'MicroFlow',
        selectedConversation: const WorkspaceSelectedConversation(
          id: '',
          title: 'MicroFlow',
          kind: WorkspaceSelectedConversationKind.channel,
          isAvailable: false,
        ),
        agents: const [
          AgentDescriptor(
            agentKey: 'assistant',
            provider: 'openai',
            enabled: true,
          ),
        ],
      ),
      size: const Size(1280, 900),
    );

    expect(find.text('Workspace hub'), findsWidgets);
    expect(find.text('MicroFlow'), findsWidgets);
    expect(
      find.text(
        'Focused collaboration workspace for local AI execution, encrypted storage, and lightweight delivery.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Private conversation entry is ready in the UI. Backend conversation APIs are the next step.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Sign out'), findsOneWidget);
  });

  testWidgets(
    'mobile setup panel can route to collaboration when there are no conversations',
    (tester) async {
      await _pumpWorkspaceHomePage(
        tester,
        state: _buildState(
          workspaceId: 'ws_1',
          workspaceName: 'MicroFlow',
          selectedConversation: const WorkspaceSelectedConversation(
            id: '',
            title: 'MicroFlow',
            kind: WorkspaceSelectedConversationKind.channel,
            isAvailable: false,
          ),
          agents: const [
            AgentDescriptor(
              agentKey: 'assistant',
              provider: 'openai',
              enabled: true,
            ),
          ],
        ),
        size: const Size(390, 844),
      );

      expect(find.text('No messages yet'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Collaboration'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Collaboration'));
      await tester.pumpAndSettle();

      expect(find.byType(WorkspacePanel), findsOneWidget);
      expect(find.text('Conversations'), findsWidgets);
    },
  );

  testWidgets(
    'mobile setup panel can route to agents when there are no conversations',
    (tester) async {
      await _pumpWorkspaceHomePage(
        tester,
        state: _buildState(
          workspaceId: 'ws_1',
          workspaceName: 'MicroFlow',
          selectedConversation: const WorkspaceSelectedConversation(
            id: '',
            title: 'MicroFlow',
            kind: WorkspaceSelectedConversationKind.channel,
            isAvailable: false,
          ),
          agents: const [
            AgentDescriptor(
              agentKey: 'assistant',
              provider: 'openai',
              enabled: true,
            ),
            AgentDescriptor(
              agentKey: 'reviewer',
              provider: 'openai',
              enabled: true,
            ),
          ],
        ),
        size: const Size(390, 844),
      );

      expect(find.widgetWithText(OutlinedButton, 'Agents'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Agents'));
      await tester.pumpAndSettle();

      expect(find.byType(AgentPanel), findsOneWidget);
      expect(find.text('Available agents'), findsWidgets);
    },
  );

  testWidgets(
    'mobile conversation selection returns to chat for direct messages',
    (tester) async {
      await _pumpWorkspaceHomePage(
        tester,
        state: _buildState(
          workspaceId: 'ws_1',
          workspaceName: 'MicroFlow',
          selectedConversation: const WorkspaceSelectedConversation(
            id: 'chn_1',
            title: 'general',
            kind: WorkspaceSelectedConversationKind.channel,
            isAvailable: true,
          ),
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
            WorkspaceConversation(
              id: 'dm_1',
              title: 'Alex Chen',
              subtitle: 'Product design',
              kind: 'DIRECT_MESSAGE',
              unreadCount: 1,
              available: true,
              lastActivityAt: null,
            ),
          ],
        ),
        size: const Size(390, 844),
      );

      await tester.tap(find.text('Collaboration'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alex Chen'));
      await tester.pumpAndSettle();

      expect(find.text('1:1 team conversation'), findsOneWidget);
    },
  );

  testWidgets(
    'desktop no-conversation state keeps side panels visible while showing setup in the main area',
    (tester) async {
      await _pumpWorkspaceHomePage(
        tester,
        state: _buildState(
          workspaceId: 'ws_1',
          workspaceName: 'MicroFlow',
          selectedConversation: const WorkspaceSelectedConversation(
            id: '',
            title: 'MicroFlow',
            kind: WorkspaceSelectedConversationKind.channel,
            isAvailable: false,
          ),
          agents: const [
            AgentDescriptor(
              agentKey: 'assistant',
              provider: 'openai',
              enabled: true,
            ),
          ],
        ),
        size: const Size(1366, 900),
      );

      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.byType(WorkspacePanel), findsOneWidget);
      expect(find.byType(AgentPanel), findsOneWidget);
      expect(find.text('Run Activity'), findsOneWidget);
      expect(find.text('Private thread with AI coworker'), findsOneWidget);
    },
  );

  testWidgets(
    'tablet layout keeps workspace visible without rendering the agent side panel',
    (tester) async {
      await _pumpWorkspaceHomePage(
        tester,
        state: _buildState(
          workspaceId: 'ws_1',
          workspaceName: 'MicroFlow',
          selectedConversation: const WorkspaceSelectedConversation(
            id: '',
            title: 'MicroFlow',
            kind: WorkspaceSelectedConversationKind.channel,
            isAvailable: false,
          ),
          agents: const [
            AgentDescriptor(
              agentKey: 'assistant',
              provider: 'openai',
              enabled: true,
            ),
          ],
        ),
        size: const Size(1024, 820),
      );

      expect(find.byType(WorkspacePanel), findsOneWidget);
      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.byType(AgentPanel), findsNothing);
      expect(find.text('Run Activity'), findsNothing);
    },
  );

  testWidgets(
    'renders collaboration observability panel for active team runs',
    (tester) async {
      await _pumpWorkspaceHomePage(
        tester,
        state: _buildState(
          workspaceId: 'ws_1',
          workspaceName: 'MicroFlow',
          selectedConversation: const WorkspaceSelectedConversation(
            id: 'chn_1',
            title: 'general',
            kind: WorkspaceSelectedConversationKind.channel,
            isAvailable: true,
          ),
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
          collaborationStatusByConversation: const {
            'chn_1': CollaborationStatusSnapshot(
              collaborationId: 'col_1234567890',
              status: 'RUNNING',
              trigger: '@team',
              round: 1,
              maxRounds: 3,
              stage: 'analyze',
              activeAgentKey: 'reviewer',
              detail: 'Need evidence from the uploaded runbook.',
            ),
          },
          collaborationRunsByConversation: const {
            'chn_1': [
              CollaborationRun(
                collaborationId: 'col_1234567890',
                workspaceId: 'ws_1',
                channelId: 'chn_1',
                status: 'RUNNING',
                round: 1,
                maxRounds: 3,
                startedAt: '2026-04-13T00:00:00Z',
                lastEventAt: '2026-04-13T00:00:00Z',
                stage: 'analyze',
                activeAgentKey: 'reviewer',
                detail: 'Need evidence from the uploaded runbook.',
                trigger: '@team',
                events: [
                  CollaborationEvent(
                    id: 'evt_1',
                    workspaceId: 'ws_1',
                    channelId: 'chn_1',
                    collaborationId: 'col_1234567890',
                    eventType: 'COLLABORATION_STEP',
                    status: 'RUNNING',
                    round: 1,
                    maxRounds: 3,
                    createdAt: '2026-04-13T00:00:00Z',
                    stage: 'analyze',
                    agentKey: 'reviewer',
                    detail: 'Need evidence from the uploaded runbook.',
                    trigger: '@team',
                  ),
                ],
              ),
            ],
          },
        ),
        size: const Size(1280, 900),
      );

      expect(find.text('Team mode'), findsWidgets);
      expect(find.text('round 1 of 3'), findsOneWidget);
      expect(find.text('@reviewer'), findsOneWidget);
      expect(find.text('@team'), findsOneWidget);
      expect(find.text('Analyze'), findsWidgets);
      expect(find.text('Run history'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(
        find.text('Need evidence from the uploaded runbook.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'renders persisted collaboration history without an active snapshot',
    (tester) async {
      await _pumpWorkspaceHomePage(
        tester,
        state: _buildState(
          workspaceId: 'ws_1',
          workspaceName: 'MicroFlow',
          selectedConversation: const WorkspaceSelectedConversation(
            id: 'chn_1',
            title: 'general',
            kind: WorkspaceSelectedConversationKind.channel,
            isAvailable: true,
          ),
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
          collaborationRunsByConversation: const {
            'chn_1': [
              CollaborationRun(
                collaborationId: 'col_history_1',
                workspaceId: 'ws_1',
                channelId: 'chn_1',
                status: 'COMPLETED',
                round: 2,
                maxRounds: 2,
                startedAt: '2026-04-13T00:00:00Z',
                lastEventAt: '2026-04-13T00:01:00Z',
                stage: 'synthesize',
                activeAgentKey: 'writer',
                detail: 'Prepared final summary.',
                trigger: '@team',
                events: [
                  CollaborationEvent(
                    id: 'evt_1',
                    workspaceId: 'ws_1',
                    channelId: 'chn_1',
                    collaborationId: 'col_history_1',
                    eventType: 'COLLABORATION_STARTED',
                    status: 'RUNNING',
                    round: 1,
                    maxRounds: 2,
                    createdAt: '2026-04-13T00:00:00Z',
                    stage: 'analyze',
                    agentKey: 'reviewer',
                    detail: 'Collected repo context.',
                    trigger: '@team',
                  ),
                  CollaborationEvent(
                    id: 'evt_2',
                    workspaceId: 'ws_1',
                    channelId: 'chn_1',
                    collaborationId: 'col_history_1',
                    eventType: 'COLLABORATION_COMPLETED',
                    status: 'COMPLETED',
                    round: 2,
                    maxRounds: 2,
                    createdAt: '2026-04-13T00:01:00Z',
                    stage: 'synthesize',
                    agentKey: 'writer',
                    detail: 'Prepared final summary.',
                    trigger: '@team',
                  ),
                ],
              ),
            ],
          },
        ),
        size: const Size(1280, 900),
      );

      expect(find.text('Team mode'), findsWidgets);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Recent runs'), findsOneWidget);
      expect(
        find.text('Persisted team runs are available for this conversation.'),
        findsOneWidget,
      );
      expect(find.text('Prepared final summary.'), findsOneWidget);
    },
  );

  testWidgets('filters collaboration history by status and agent', (
    tester,
  ) async {
    await _pumpWorkspaceHomePage(
      tester,
      state: _buildState(
        workspaceId: 'ws_1',
        workspaceName: 'MicroFlow',
        selectedConversation: const WorkspaceSelectedConversation(
          id: 'chn_1',
          title: 'general',
          kind: WorkspaceSelectedConversationKind.channel,
          isAvailable: true,
        ),
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
        collaborationRunsByConversation: const {
          'chn_1': [
            CollaborationRun(
              collaborationId: 'col_complete_1',
              workspaceId: 'ws_1',
              channelId: 'chn_1',
              status: 'COMPLETED',
              round: 2,
              maxRounds: 2,
              startedAt: '2026-04-13T00:00:00Z',
              lastEventAt: '2026-04-13T00:01:00Z',
              stage: 'synthesize',
              activeAgentKey: 'writer',
              detail: 'Prepared final summary.',
              trigger: '@team',
              events: [
                CollaborationEvent(
                  id: 'evt_1',
                  workspaceId: 'ws_1',
                  channelId: 'chn_1',
                  collaborationId: 'col_complete_1',
                  eventType: 'COLLABORATION_STARTED',
                  status: 'RUNNING',
                  round: 1,
                  maxRounds: 2,
                  createdAt: '2026-04-13T00:00:00Z',
                  stage: 'analyze',
                  agentKey: 'writer',
                  detail: 'Drafted the response plan.',
                  trigger: '@team',
                ),
                CollaborationEvent(
                  id: 'evt_2',
                  workspaceId: 'ws_1',
                  channelId: 'chn_1',
                  collaborationId: 'col_complete_1',
                  eventType: 'COLLABORATION_COMPLETED',
                  status: 'COMPLETED',
                  round: 2,
                  maxRounds: 2,
                  createdAt: '2026-04-13T00:01:00Z',
                  stage: 'synthesize',
                  agentKey: 'writer',
                  detail: 'Prepared final summary.',
                  trigger: '@team',
                ),
              ],
            ),
            CollaborationRun(
              collaborationId: 'col_abort_1',
              workspaceId: 'ws_1',
              channelId: 'chn_1',
              status: 'ABORTED',
              round: 2,
              maxRounds: 2,
              startedAt: '2026-04-13T00:02:00Z',
              lastEventAt: '2026-04-13T00:03:00Z',
              stage: 'critique',
              activeAgentKey: 'reviewer',
              detail: 'Blocked on missing evidence.',
              trigger: '@team',
              events: [
                CollaborationEvent(
                  id: 'evt_3',
                  workspaceId: 'ws_1',
                  channelId: 'chn_1',
                  collaborationId: 'col_abort_1',
                  eventType: 'COLLABORATION_STARTED',
                  status: 'RUNNING',
                  round: 1,
                  maxRounds: 2,
                  createdAt: '2026-04-13T00:02:00Z',
                  stage: 'analyze',
                  agentKey: 'reviewer',
                  detail: 'Collected repo context.',
                  trigger: '@team',
                ),
                CollaborationEvent(
                  id: 'evt_4',
                  workspaceId: 'ws_1',
                  channelId: 'chn_1',
                  collaborationId: 'col_abort_1',
                  eventType: 'COLLABORATION_ABORTED',
                  status: 'ABORTED',
                  round: 2,
                  maxRounds: 2,
                  createdAt: '2026-04-13T00:03:00Z',
                  stage: 'critique',
                  agentKey: 'reviewer',
                  detail: 'Blocked on missing evidence.',
                  trigger: '@team',
                ),
              ],
            ),
          ],
        },
      ),
      size: const Size(1280, 900),
    );

    expect(find.text('Blocked on missing evidence.'), findsOneWidget);
    expect(find.text('Prepared final summary.'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pumpAndSettle();

    expect(find.text('Prepared final summary.'), findsOneWidget);
    expect(find.text('No runs match current filters.'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, '@reviewer'));
    await tester.pumpAndSettle();

    expect(find.text('No runs match current filters.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All statuses'));
    await tester.pumpAndSettle();

    expect(find.text('Blocked on missing evidence.'), findsOneWidget);
  });

  testWidgets(
    'existing conversations use the normal chat empty state instead of the setup panel',
    (tester) async {
      await _pumpWorkspaceHomePage(
        tester,
        state: _buildState(
          workspaceId: 'ws_1',
          workspaceName: 'MicroFlow',
          selectedConversation: const WorkspaceSelectedConversation(
            id: 'chn_1',
            title: 'general',
            kind: WorkspaceSelectedConversationKind.channel,
            isAvailable: true,
          ),
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
        size: const Size(390, 844),
      );

      expect(find.text('No messages yet'), findsOneWidget);
      expect(
        find.text(
          'Start the conversation with a team update, then mention an agent only when you need help.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Collaboration'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Agents'), findsNothing);
    },
  );
}

Future<void> _pumpWorkspaceHomePage(
  WidgetTester tester, {
  required WorkspaceShellState state,
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workspaceShellControllerProvider.overrideWith(
          () => _FakeWorkspaceShellController(state),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const WorkspaceHomePage(),
      ),
    ),
  );
  await tester.pump();
}

WorkspaceShellState _buildState({
  required String workspaceId,
  required String workspaceName,
  required WorkspaceSelectedConversation selectedConversation,
  List<WorkspaceConversation> conversations = const [],
  List<AgentDescriptor> agents = const [],
  Map<String, CollaborationStatusSnapshot> collaborationStatusByConversation =
      const {},
  Map<String, List<CollaborationRun>> collaborationRunsByConversation =
      const {},
}) {
  return WorkspaceShellState(
    workspaceId: workspaceId,
    workspaceName: workspaceName,
    channels: const <ChannelSummary>[],
    conversations: conversations,
    selectedConversation: selectedConversation,
    messages: const <ChatMessage>[],
    agents: agents,
    agentRuns: const <AgentRun>[],
    connectionStatus: ChatConnectionStatus.idle,
    currentUserId: 'usr_1',
    currentUserLabel: 'Demo User',
    isSendingMessage: false,
    collaborationModeByConversation: const {},
    collaborationStatusByConversation: collaborationStatusByConversation,
    collaborationRunsByConversation: collaborationRunsByConversation,
  );
}

class _FakeWorkspaceShellController extends WorkspaceShellController {
  _FakeWorkspaceShellController(this._state);

  WorkspaceShellState _state;

  @override
  Future<WorkspaceShellState> build() async => _state;

  @override
  Future<void> selectConversation({
    required String conversationId,
    required String title,
    required WorkspaceSelectedConversationKind kind,
    required bool isAvailable,
  }) async {
    _state = _state.copyWith(
      selectedConversation: WorkspaceSelectedConversation(
        id: conversationId,
        title: title,
        kind: kind,
        isAvailable: isAvailable,
      ),
      messages: const <ChatMessage>[],
      clearMessageError: true,
    );
    state = AsyncData(_state);
  }
}
