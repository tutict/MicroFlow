import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/app/theme/app_theme.dart';
import 'package:microflow_frontend/core/providers/app_providers.dart';
import 'package:microflow_frontend/features/accounting/domain/entities/accounting_account.dart';
import 'package:microflow_frontend/features/accounting/domain/entities/accounting_voucher.dart';
import 'package:microflow_frontend/features/accounting/domain/entities/trial_balance_row.dart';
import 'package:microflow_frontend/features/accounting/domain/repositories/accounting_repository.dart';
import 'package:microflow_frontend/features/agents/domain/repositories/agent_repository.dart';
import 'package:microflow_frontend/features/agents/domain/entities/agent_descriptor.dart';
import 'package:microflow_frontend/features/agents/domain/entities/agent_diagnostic.dart';
import 'package:microflow_frontend/features/agents/domain/entities/agent_run.dart';
import 'package:microflow_frontend/features/agents/presentation/widgets/agent_panel.dart';
import 'package:microflow_frontend/features/chat/domain/entities/channel_summary.dart';
import 'package:microflow_frontend/features/chat/domain/entities/chat_message.dart';
import 'package:microflow_frontend/features/chat/domain/entities/collaboration_event.dart';
import 'package:microflow_frontend/features/chat/domain/entities/collaboration_run.dart';
import 'package:microflow_frontend/features/chat/presentation/state/chat_connection_status.dart';
import 'package:microflow_frontend/features/chat/presentation/widgets/input_box.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_conversation.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_summary.dart';
import 'package:microflow_frontend/features/workspace/presentation/pages/workspace_home_page.dart';
import 'package:microflow_frontend/features/workspace/presentation/providers/workspace_shell_controller.dart';
import 'package:microflow_frontend/features/workspace/presentation/state/workspace_selected_conversation.dart';
import 'package:microflow_frontend/features/workspace/presentation/state/workspace_shell_state.dart';
import 'package:microflow_frontend/features/workspace/presentation/shell/workspace_destination_rail.dart';
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
      find.text('Conversations, teammates, and agents in one place.'),
      findsOneWidget,
    );
    expect(find.textContaining('Backend conversation APIs'), findsNothing);
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
      expect(find.widgetWithText(FilledButton, 'Index'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Index'));
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

      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();

      expect(find.text('Diagnostics'), findsWidgets);
      expect(find.text('Accounting'), findsWidgets);
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

      await tester.tap(find.text('Index'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alex Chen'));
      await tester.pumpAndSettle();

      expect(find.text('1:1 team conversation'), findsWidgets);
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
      expect(find.byType(AgentPanel), findsNothing);
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
      expect(find.text('@reviewer'), findsWidgets);
      expect(find.text('@team'), findsWidgets);
      expect(find.text('Analyze'), findsNothing);

      await tester.tap(find.byTooltip('Show collaboration details'));
      await tester.pumpAndSettle();

      expect(find.text('Analyze'), findsWidgets);
      expect(find.text('Run history'), findsWidgets);
      expect(
        find.text('Need evidence from the uploaded runbook.'),
        findsWidgets,
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
      expect(find.text('Recent runs'), findsNothing);

      await tester.tap(find.byTooltip('Show collaboration details'));
      await tester.pumpAndSettle();

      expect(find.text('Recent runs'), findsOneWidget);
      expect(
        find.text('Persisted team runs are available for this conversation.'),
        findsWidgets,
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

    await tester.tap(find.byTooltip('Show collaboration details'));
    await tester.pumpAndSettle();

    expect(find.text('Blocked on missing evidence.'), findsOneWidget);
    expect(find.text('Prepared final summary.'), findsNothing);

    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Completed'))
        .onSelected!(true);
    await tester.pumpAndSettle();

    expect(find.text('Prepared final summary.'), findsOneWidget);
    expect(find.text('No runs match current filters.'), findsNothing);

    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '@reviewer'))
        .onSelected!(true);
    await tester.pumpAndSettle();

    expect(find.text('No runs match current filters.'), findsOneWidget);

    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All statuses'))
        .onSelected!(true);
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
      expect(find.text('Send the first message.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Index'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Agents'), findsNothing);
    },
  );

  testWidgets(
    'shell keeps navigation while opening accounting and diagnostics',
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
        silentRepositories: true,
      );

      expect(find.byType(InputBox), findsOneWidget);
      await tester.tap(find.text('Index'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkspacePanel), findsOneWidget);

      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Accounting'));
      await tester.tap(find.text('Accounting'));
      await tester.pumpAndSettle();
      expect(find.text('Chat'), findsWidgets);
      expect(find.byTooltip('Back to conversation'), findsOneWidget);

      await tester.tap(find.byTooltip('Back to conversation'));
      await tester.pumpAndSettle();
      expect(find.text('general'), findsWidgets);

      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Diagnostics'));
      await tester.tap(find.text('Diagnostics'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back to conversation'), findsOneWidget);
      expect(find.text('Chat'), findsWidgets);
    },
  );

  testWidgets('medium and expanded widths keep the index beside the composer', (
    tester,
  ) async {
    final state = _buildState(
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
    );

    await _pumpWorkspaceHomePage(
      tester,
      state: state,
      size: const Size(820, 900),
    );
    expect(find.byType(WorkspacePanel), findsOneWidget);
    expect(find.byType(InputBox), findsOneWidget);
    expect(find.byType(WorkspaceDestinationRail), findsNothing);

    await _pumpWorkspaceHomePage(
      tester,
      state: state,
      size: const Size(1100, 900),
    );
    expect(find.byType(WorkspacePanel), findsOneWidget);
    expect(find.byType(InputBox), findsOneWidget);
    expect(find.byType(WorkspaceDestinationRail), findsOneWidget);
  });

  testWidgets('large text scale drops the fixed inspector column', (
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
            unreadCount: 1,
            available: true,
            lastActivityAt: null,
          ),
        ],
      ),
      size: const Size(1440, 900),
      textScale: 1.4,
    );

    expect(find.byKey(const Key('workspace-inspector')), findsNothing);
    expect(find.byType(WorkspacePanel), findsOneWidget);
    expect(find.byType(InputBox), findsOneWidget);
  });

  testWidgets('large layout keeps the inspector beside the conversation', (
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
      ),
      size: const Size(1440, 900),
    );

    expect(find.byKey(const Key('workspace-inspector')), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.byType(InputBox), findsOneWidget);
  });

  testWidgets(
    'narrow top bar keeps the workspace name and offers switching in the overflow menu',
    (tester) async {
      await _pumpWorkspaceHomePage(
        tester,
        state: _buildState(
          workspaceId: 'ws_1',
          workspaceName: 'North Lab',
          workspaces: const [
            WorkspaceSummary(id: 'ws_1', name: 'North Lab', memberCount: 1),
            WorkspaceSummary(id: 'ws_2', name: 'South Lab', memberCount: 2),
          ],
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

      expect(find.text('North Lab'), findsOneWidget);
      expect(find.text('Weilan'), findsNothing);

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      expect(find.text('South Lab'), findsOneWidget);
      expect(find.text('New workspace'), findsOneWidget);
    },
  );
}

Future<void> _pumpWorkspaceHomePage(
  WidgetTester tester, {
  required WorkspaceShellState state,
  required Size size,
  double textScale = 1,
  bool silentRepositories = false,
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
        if (silentRepositories)
          accountingRepositoryProvider.overrideWithValue(
            _SilentAccountingRepository(),
          ),
        if (silentRepositories)
          agentRepositoryProvider.overrideWithValue(_SilentAgentRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(textScale)),
            child: child ?? const SizedBox.shrink(),
          );
        },
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
  List<WorkspaceSummary> workspaces = const [],
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
    workspaces: workspaces,
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

class _SilentAccountingRepository implements AccountingRepository {
  @override
  Future<AccountingAccount> createAccount({
    required String workspaceId,
    required String code,
    required String name,
    required String category,
    required String normalBalance,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AccountingVoucher> createVoucher({
    required String workspaceId,
    required String voucherDate,
    required String description,
    required List<CreateAccountingVoucherLineInput> lines,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<AccountingAccount>> listAccounts(String workspaceId) async {
    return const [];
  }

  @override
  Future<List<AccountingVoucher>> listVouchers(String workspaceId) async {
    return const [];
  }

  @override
  Future<AccountingVoucher> postVoucher({
    required String workspaceId,
    required String voucherId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<TrialBalanceRow>> trialBalance({
    required String workspaceId,
    String? period,
  }) async {
    return const [];
  }
}

class _SilentAgentRepository implements AgentRepository {
  @override
  Future<List<AgentDescriptor>> listAgents(String workspaceId) async {
    return const [];
  }

  @override
  Future<List<AgentDiagnostic>> listDiagnostics(String workspaceId) async {
    return const [];
  }

  @override
  Future<List<AgentRun>> listRuns(String workspaceId) async {
    return const [];
  }

  @override
  Future<void> updateRoleStrategy({
    required String workspaceId,
    required String agentKey,
    required String roleStrategy,
  }) async {}
}
