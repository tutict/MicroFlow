import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/app/theme/app_theme.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_approval.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_artifact.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_context_source.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_run.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_run_event.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_run_step.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/repositories/agent_runtime_repository.dart';
import 'package:microflow_frontend/features/agent_runtime/presentation/providers/agent_runtime_providers.dart';
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
import 'package:microflow_frontend/features/tasks/domain/entities/my_work_agenda.dart';
import 'package:microflow_frontend/features/tasks/domain/entities/task_activity.dart';
import 'package:microflow_frontend/features/tasks/domain/entities/task_item.dart';
import 'package:microflow_frontend/features/tasks/domain/entities/task_project.dart';
import 'package:microflow_frontend/features/tasks/domain/entities/task_summary.dart';
import 'package:microflow_frontend/features/tasks/domain/repositories/task_repository.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_conversation.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_summary.dart';
import 'package:microflow_frontend/features/workspace/domain/entities/workspace_member.dart';
import 'package:microflow_frontend/features/workspace/presentation/pages/workspace_home_page.dart';
import 'package:microflow_frontend/features/workspace/presentation/providers/workspace_shell_controller.dart';
import 'package:microflow_frontend/features/workspace/presentation/state/workspace_selected_conversation.dart';
import 'package:microflow_frontend/features/workspace/presentation/state/workspace_shell_state.dart';
import 'package:microflow_frontend/features/workspace/presentation/shell/workspace_destination_rail.dart';
import 'package:microflow_frontend/features/workspace/presentation/widgets/workspace_panel.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'home shares a pending task start across My Work All tasks and row remount',
    (tester) async {
      final runtime = _PendingStartRepository();
      await _pumpWorkspaceHomePage(
        tester,
        state: _buildState(
          workspaceId: 'ws_1',
          workspaceName: 'MicroFlow',
          selectedConversation: const WorkspaceSelectedConversation(
            id: '',
            title: '',
            kind: WorkspaceSelectedConversationKind.channel,
            isAvailable: false,
          ),
        ),
        size: const Size(1280, 900),
        taskRepository: _ActionTaskRepository(),
        agentRuntimeRepository: runtime,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.checklist_outlined));
      await tester.pumpAndSettle();
      await _chooseTaskRun(tester, const Key('my-work-run-agent-compact_task'));
      expect(runtime.responses.length, 1);
      await tester.tap(find.byKey(const Key('my-work-scope-all')));
      await tester.pumpAndSettle();
      await _chooseTaskRun(tester, const Key('task-run-agent-compact_task'));
      expect(
        runtime.responses.length,
        1,
        reason: 'All tasks must join the queue HTTP start still in progress',
      );
      await tester.tap(find.byKey(const Key('my-work-scope-mine')));
      await tester.pumpAndSettle();
      await _chooseTaskRun(tester, const Key('my-work-run-agent-compact_task'));
      expect(
        runtime.responses.length,
        1,
        reason: 'a newly mounted row must share the same pending start',
      );
      runtime.responses[0].completeError(StateError('HTTP start failed'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('HTTP start failed'), findsWidgets);
      await _chooseTaskRun(tester, const Key('my-work-run-agent-compact_task'));
      expect(runtime.responses.length, 2);
      runtime.responses[1].complete(
        const AgentRunSummary(
          id: 'retried_start',
          workspaceId: 'ws_1',
          taskId: 'compact_task',
          agentKey: 'assistant',
          kind: 'TASK',
          status: AgentRunStatus.queued,
          goal: 'Compact task',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cached home switches preserve mounted All tasks and reload its workspace',
    (tester) async {
      final repository = _CachedHomeTaskRepository();
      await _pumpWorkspaceHomePage(
        tester,
        state: _buildState(
          workspaceId: 'A',
          workspaceName: 'Workspace A',
          workspaces: const [
            WorkspaceSummary(id: 'A', name: 'Workspace A', memberCount: 1),
            WorkspaceSummary(id: 'B', name: 'Workspace B', memberCount: 1),
          ],
          selectedConversation: const WorkspaceSelectedConversation(
            id: '',
            title: '',
            kind: WorkspaceSelectedConversationKind.channel,
            isAvailable: false,
          ),
        ),
        size: const Size(1280, 900),
        taskRepository: repository,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.checklist_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('my-work-scope-all')));
      // The task request remains pending deliberately; its skeleton keeps
      // animating, so settle only the menu transitions with bounded frames.
      await tester.pump();
      expect(repository.requests.single.workspaceId, 'A');
      final mountedState = tester.state(
        find.byKey(const Key('task-workbench')),
      );
      for (final workspace in ['Workspace B', 'Workspace A']) {
        await tester.tap(find.byTooltip('Switch workspace'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text(workspace).last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          identical(
            tester.state(find.byKey(const Key('task-workbench'))),
            mountedState,
          ),
          isTrue,
          reason: 'cached switching must test the existing mounted view',
        );
      }
      expect(repository.requests.map((request) => request.workspaceId), [
        'A',
        'B',
        'A',
      ]);
      repository.complete(2, 'latest cached A');
      await tester.pumpAndSettle();
      repository.complete(0, 'old cached A');
      repository.requests[1].result.completeError(
        Exception('old cached B failure'),
      );
      await tester.pumpAndSettle();
      expect(find.text('latest cached A'), findsOneWidget);
      expect(find.textContaining('old cached'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final sample in [
    (
      size: const Size(390, 844),
      locale: const Locale('en'),
      dark: false,
      scale: 1.0,
    ),
    (
      size: const Size(800, 1000),
      locale: const Locale('en'),
      dark: false,
      scale: 1.0,
    ),
    (
      size: const Size(390, 844),
      locale: const Locale('zh'),
      dark: true,
      scale: 1.8,
    ),
    (
      size: const Size(800, 1000),
      locale: const Locale('zh'),
      dark: true,
      scale: 1.8,
    ),
  ]) {
    testWidgets(
      'home Tools reaches My Work and task start at ${sample.size.width} ${sample.locale} scale ${sample.scale}',
      (tester) async {
        final runtime = _RecordingStartRepository();
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
          ),
          size: sample.size,
          locale: sample.locale,
          dark: sample.dark,
          textScale: sample.scale,
          taskRepository: _CompactTaskRepository(),
          agentRuntimeRepository: runtime,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.handyman_outlined));
        await tester.pumpAndSettle();
        final entry = find.byKey(const Key('tool-my-work'));
        expect(entry, findsOneWidget);
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('my-work-page')), findsOneWidget);
        expect(find.text('Compact task'), findsOneWidget);
        await tester.tap(find.byType(PopupMenuButton<String>).last);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('my-work-run-agent-compact_task')),
        );
        await tester.pumpAndSettle();
        expect(runtime.started, ['ws_1:compact_task']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'workspace management owns roles while the task page stays focused on work',
    (tester) async {
      final state =
          _buildState(
            workspaceId: 'ws_1',
            workspaceName: 'MicroFlow',
            selectedConversation: const WorkspaceSelectedConversation(
              id: 'chn_1',
              title: 'general',
              kind: WorkspaceSelectedConversationKind.channel,
              isAvailable: true,
            ),
          ).copyWith(
            workspaceMembers: const [
              WorkspaceMember(
                userId: 'usr_1',
                email: 'owner@example.com',
                displayName: 'Owner',
                role: 'OWNER',
                joinedAt: '2026-01-01',
              ),
              WorkspaceMember(
                userId: 'usr_2',
                email: 'mate@example.com',
                displayName: 'Teammate',
                role: 'OPERATOR',
                joinedAt: '2026-01-01',
              ),
            ],
          );
      await _pumpWorkspaceHomePage(
        tester,
        state: state,
        size: const Size(1280, 900),
        taskRepository: _RecordingTaskRepository(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.checklist_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('my-work-scope-all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('workspace-role-manager')), findsNothing);
      expect(find.byIcon(Icons.manage_accounts_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.manage_accounts_outlined));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('workspace-management')), findsOneWidget);
      expect(find.byKey(const Key('workspace-role-manager')), findsOneWidget);
    },
  );

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

  testWidgets('phone surfaces a run waiting for approval in the app bar', (
    tester,
  ) async {
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
      ),
      size: const Size(390, 844),
      agentRuntimeRepository: const _SilentAgentRuntimeRepository(
        runs: [
          AgentRunSummary(
            id: 'run_1',
            workspaceId: 'ws_1',
            agentKey: 'assistant',
            kind: 'TASK',
            status: AgentRunStatus.waitingApproval,
            goal: 'Send the weekly update',
            taskId: 'task_1',
            pendingApprovalId: 'apr_1',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agent-approval-inbox')), findsOneWidget);
    expect(
      find.text('1'),
      findsOneWidget,
      reason: 'the badge must count the run that blocks on a human',
    );

    await tester.tap(find.byKey(const Key('agent-approval-inbox')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agent-runs-sheet')), findsOneWidget);
  });

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
    'a chat message can be turned into a task that keeps its origin',
    (tester) async {
      final tasks = _RecordingTaskRepository();
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
          messages: const [
            ChatMessage(
              id: 'msg_1',
              author: 'usr_2',
              text: 'Please renew the certificate before Friday',
              createdAt: '2026-10-28T04:00:00Z',
              isAgent: false,
            ),
          ],
        ),
        size: const Size(390, 844),
        taskRepository: tasks,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Please renew the certificate before Friday'),
        findsOneWidget,
        reason: 'the message itself must render before its action can',
      );
      await tester.tap(find.byKey(const Key('chat-message-task-msg_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task-from-message-create')));
      await tester.pumpAndSettle();

      expect(tasks.created, hasLength(1));
      expect(
        tasks.created.single.title,
        'Please renew the certificate before Friday',
      );
      expect(tasks.created.single.originMessageId, 'msg_1');
      expect(
        tasks.created.single.originChannelId,
        'chn_1',
        reason: 'a task must remember the conversation it came from',
      );
    },
  );

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

Future<void> _chooseTaskRun(WidgetTester tester, Key key) async {
  final popup = find.byType(PopupMenuButton<String>).last;
  if (!tester.widget<PopupMenuButton<String>>(popup).enabled) return;
  await tester.tap(popup);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byKey(key));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class _ActionTaskRepository extends _CompactTaskRepository {
  @override
  Future<List<TaskItem>> listTasks({
    required String workspaceId,
    String? projectId,
    String? status,
    String? assignee,
    bool mine = false,
  }) async => const [
    TaskItem(
      id: 'compact_task',
      workspaceId: 'ws_1',
      title: 'Compact task',
      status: 'OPEN',
      priority: 'NORMAL',
    ),
  ];
}

class _PendingStartRepository extends _SilentAgentRuntimeRepository {
  final responses = <Completer<AgentRunSummary>>[];
  @override
  Future<AgentRunSummary> startTaskRun({
    required String workspaceId,
    required String taskId,
    String? agentKey,
    String? goal,
  }) {
    final response = Completer<AgentRunSummary>();
    responses.add(response);
    return response.future;
  }
}

class _CompactTaskRepository extends _RecordingTaskRepository {
  @override
  Future<MyWorkAgenda> myWork({
    required String workspaceId,
    int limit = 50,
  }) async => const MyWorkAgenda(
    actionable: [
      TaskItem(
        id: 'compact_task',
        workspaceId: 'ws_1',
        title: 'Compact task',
        status: 'OPEN',
        priority: 'NORMAL',
      ),
    ],
  );
}

class _CachedHomeTaskRepository extends _RecordingTaskRepository {
  final requests = <({String workspaceId, Completer<List<TaskItem>> result})>[];
  @override
  Future<List<TaskItem>> listTasks({
    required String workspaceId,
    String? projectId,
    String? status,
    String? assignee,
    bool mine = false,
  }) {
    final result = Completer<List<TaskItem>>();
    requests.add((workspaceId: workspaceId, result: result));
    return result.future;
  }

  void complete(int index, String title) {
    final request = requests[index];
    request.result.complete([
      TaskItem(
        id: 'task_$index',
        workspaceId: request.workspaceId,
        title: title,
        status: 'OPEN',
        priority: 'NORMAL',
      ),
    ]);
  }
}

class _RecordingStartRepository extends _SilentAgentRuntimeRepository {
  final started = <String>[];
  @override
  Future<AgentRunSummary> startTaskRun({
    required String workspaceId,
    required String taskId,
    String? agentKey,
    String? goal,
  }) async {
    started.add('$workspaceId:$taskId');
    return AgentRunSummary(
      id: 'started_run',
      workspaceId: workspaceId,
      taskId: taskId,
      agentKey: 'assistant',
      kind: 'TASK',
      status: AgentRunStatus.queued,
      goal: 'Compact task',
    );
  }
}

Future<void> _pumpWorkspaceHomePage(
  WidgetTester tester, {
  required WorkspaceShellState state,
  required Size size,
  double textScale = 1,
  Locale locale = const Locale('en'),
  bool dark = false,
  bool silentRepositories = false,
  AgentRuntimeRepository? agentRuntimeRepository,
  TaskRepository? taskRepository,
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
        // The inspector's execution view lists runs; without this the page
        // starts a real HTTP request whose timeout timer outlives the test.
        agentRuntimeRepositoryProvider.overrideWithValue(
          agentRuntimeRepository ?? const _SilentAgentRuntimeRepository(),
        ),
        if (taskRepository != null)
          taskRepositoryProvider.overrideWithValue(taskRepository),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        locale: locale,
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
  List<ChatMessage> messages = const [],
}) {
  return WorkspaceShellState(
    workspaceId: workspaceId,
    workspaceName: workspaceName,
    channels: const <ChannelSummary>[],
    conversations: conversations,
    selectedConversation: selectedConversation,
    messages: messages,
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
  Future<void> selectWorkspace(String workspaceId) async {
    final target = _state.workspaces.firstWhere(
      (workspace) => workspace.id == workspaceId,
    );
    _state = _state.copyWith(
      workspaceId: target.id,
      workspaceName: target.name,
    );
    state = AsyncData(_state);
  }

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

/// Answers every runtime query with nothing, so layout tests never open a socket.
class _SilentAgentRuntimeRepository implements AgentRuntimeRepository {
  const _SilentAgentRuntimeRepository({this.runs = const []});

  final List<AgentRunSummary> runs;

  @override
  Future<List<AgentRunSummary>> listRuns({
    required String workspaceId,
    String? taskId,
  }) async => runs;

  @override
  Future<AgentRunSummary> getRun(String runId) async =>
      throw UnimplementedError();

  @override
  Future<List<AgentRunSummary>> listActiveRuns({
    required String workspaceId,
  }) async => runs.where((run) => run.status.isActive).toList();

  @override
  Future<List<AgentRunStep>> listSteps(String runId) async => const [];

  @override
  Future<List<AgentRunEvent>> listEvents(
    String runId, {
    int afterSeq = 0,
    int limit = 200,
  }) async => const [];

  @override
  Future<List<AgentApproval>> listApprovals(
    String runId, {
    String? status,
  }) async => const [];

  @override
  Future<List<AgentContextSource>> listContextSources(String runId) async =>
      const [];

  @override
  Future<List<AgentArtifact>> listArtifacts(String runId) async => const [];

  @override
  Future<AgentRunSummary> startTaskRun({
    required String workspaceId,
    required String taskId,
    String? agentKey,
    String? goal,
  }) async => throw UnimplementedError();

  @override
  Future<AgentApproval> decideApproval({
    required String runId,
    required String approvalId,
    required bool approve,
    String? note,
  }) async => throw UnimplementedError();

  @override
  Future<AgentRunSummary> cancelRun(String runId) async =>
      throw UnimplementedError();

  @override
  Future<AgentRunSummary> retryRun(String runId) async =>
      throw UnimplementedError();
}

/// Captures the one call this test cares about: a task created from a message.
class _RecordingTaskRepository implements TaskRepository {
  final List<({String title, String? originChannelId, String? originMessageId})>
  created = [];

  @override
  Future<TaskItem> createTask({
    required String workspaceId,
    required String title,
    String? projectId,
    String? detail,
    String? priority,
    String? status,
    String? assigneeUserId,
    bool assigneeIsSelf = false,
    String? originChannelId,
    String? originMessageId,
    DateTime? dueAt,
  }) async {
    created.add((
      title: title,
      originChannelId: originChannelId,
      originMessageId: originMessageId,
    ));
    return TaskItem(
      id: 'task_new',
      workspaceId: workspaceId,
      title: title,
      status: 'OPEN',
      priority: 'NORMAL',
      originChannelId: originChannelId,
      originMessageId: originMessageId,
    );
  }

  @override
  Future<MyWorkAgenda> myWork({
    required String workspaceId,
    int limit = 50,
  }) async => const MyWorkAgenda.empty();

  @override
  Future<List<TaskProject>> listProjects(String workspaceId) async => const [];

  @override
  Future<TaskProject> createProject({
    required String workspaceId,
    required String name,
    String? description,
  }) async => throw UnimplementedError();

  @override
  Future<List<TaskItem>> listTasks({
    required String workspaceId,
    String? projectId,
    String? status,
    String? assignee,
    bool mine = false,
  }) async => const [];

  @override
  Future<TaskItem> updateStatus({
    required String workspaceId,
    required String taskId,
    required String status,
  }) async => throw UnimplementedError();

  @override
  Future<TaskItem> assign({
    required String workspaceId,
    required String taskId,
    String? assigneeUserId,
    bool assigneeIsSelf = false,
  }) async => throw UnimplementedError();

  @override
  Future<List<TaskActivity>> listActivity({
    required String workspaceId,
    required String taskId,
  }) async => const [];

  @override
  Future<TaskSummary> summarize({
    required String workspaceId,
    String? projectId,
  }) async => const TaskSummary.empty();
}
