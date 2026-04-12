import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/features/agents/domain/entities/agent_descriptor.dart';
import 'package:microflow_frontend/features/agents/domain/entities/agent_run.dart';
import 'package:microflow_frontend/features/agents/presentation/widgets/agent_panel.dart';
import 'package:microflow_frontend/features/chat/domain/entities/channel_summary.dart';
import 'package:microflow_frontend/features/chat/domain/entities/chat_message.dart';
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
          workspaceName: 'SoloFlow',
          selectedConversation: const WorkspaceSelectedConversation(
            id: '',
            title: 'SoloFlow',
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
          workspaceName: 'SoloFlow',
          selectedConversation: const WorkspaceSelectedConversation(
            id: '',
            title: 'SoloFlow',
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
    'desktop no-conversation state keeps side panels visible while showing setup in the main area',
    (tester) async {
      await _pumpWorkspaceHomePage(
        tester,
        state: _buildState(
          workspaceId: 'ws_1',
          workspaceName: 'SoloFlow',
          selectedConversation: const WorkspaceSelectedConversation(
            id: '',
            title: 'SoloFlow',
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
    'existing conversations use the normal chat empty state instead of the setup panel',
    (tester) async {
      await _pumpWorkspaceHomePage(
        tester,
        state: _buildState(
          workspaceId: 'ws_1',
          workspaceName: 'SoloFlow',
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
    collaborationStatusByConversation: const {},
  );
}

class _FakeWorkspaceShellController extends WorkspaceShellController {
  _FakeWorkspaceShellController(this._state);

  final WorkspaceShellState _state;

  @override
  Future<WorkspaceShellState> build() async => _state;
}
