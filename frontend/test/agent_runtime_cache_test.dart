import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/app/theme/app_theme.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_run.dart';
import 'package:microflow_frontend/features/agent_runtime/presentation/providers/agent_runtime_providers.dart';
import 'package:microflow_frontend/features/agent_runtime/presentation/widgets/agent_execution_panel.dart';
import 'package:microflow_frontend/features/tasks/presentation/providers/task_queue_providers.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';
import 'package:microflow_frontend/l10n/app_localization_delegates.dart';

import 'support/recording_runtime_repository.dart';

void main() {
  test(
    'manual refresh reloads task history outside the workspace window',
    () async {
      final repository = RecordingRuntimeRepository(
        runs: [
          for (var i = 0; i < 50; i++)
            testRun(
              id: 'new_$i',
              taskId: 'new_task_$i',
              status: AgentRunStatus.waitingApproval,
            ),
          testRun(
            id: 'old_run',
            taskId: 'old_task',
            status: AgentRunStatus.failed,
            createdAt: '2020-01-01T00:00:00Z',
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          agentRuntimeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      const query = (workspaceId: 'ws_1', taskId: 'old_task');
      container.listen(agentRunsProvider(query), (_, _) {});
      expect(
        (await container.read(agentRunsProvider(query).future)).single.status,
        AgentRunStatus.failed,
      );
      repository.runs = [
        ...repository.runs.take(50),
        testRun(
          id: 'old_run',
          taskId: 'old_task',
          status: AgentRunStatus.succeeded,
          createdAt: '2020-01-01T00:00:00Z',
          updatedAt: '2026-11-23T10:00:05Z',
        ),
      ];
      await container
          .read(agentWorkspaceRunsProvider('ws_1').notifier)
          .refresh();
      await Future<void>.delayed(Duration.zero);
      expect(
        (await container.read(agentRunsProvider(query).future)).single.status,
        AgentRunStatus.succeeded,
      );
    },
  );

  test('failed refresh preserves a newer live snapshot', () async {
    final repository = RecordingRuntimeRepository(
      runs: [testRun(status: AgentRunStatus.running)],
    );
    final container = ProviderContainer(
      overrides: [agentRuntimeRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.listen(agentWorkspaceRunsProvider('ws_1'), (_, _) {});
    await container.read(agentWorkspaceRunsProvider('ws_1').future);
    final response = Completer<List<AgentRunSummary>>();
    repository.listResponses.add(response.future);
    final controller = container.read(
      agentWorkspaceRunsProvider('ws_1').notifier,
    );
    final refresh = controller.refresh();
    controller.upsert(
      testRun(
        status: AgentRunStatus.succeeded,
        updatedAt: '2026-11-23T10:00:01Z',
      ),
    );
    response.completeError(StateError('Refresh failed'));
    await refresh;
    expect(
      container.read(agentWorkspaceRunsProvider('ws_1')).value?.single.status,
      AgentRunStatus.succeeded,
    );
  });

  test(
    'an older failed request cannot replace the result of a newer refresh',
    () async {
      final repository = RecordingRuntimeRepository(
        runs: [testRun(status: AgentRunStatus.running)],
      );
      final container = ProviderContainer(
        overrides: [
          agentRuntimeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      container.listen(agentWorkspaceRunsProvider('ws_1'), (_, _) {});
      await container.read(agentWorkspaceRunsProvider('ws_1').future);
      final first = Completer<List<AgentRunSummary>>();
      final second = Completer<List<AgentRunSummary>>();
      repository.listResponses.addAll([first.future, second.future]);
      final controller = container.read(
        agentWorkspaceRunsProvider('ws_1').notifier,
      );
      final olderRefresh = controller.refresh();
      final newerRefresh = controller.refresh();
      second.complete([
        testRun(
          status: AgentRunStatus.succeeded,
          updatedAt: '2026-11-23T10:00:02Z',
        ),
      ]);
      await newerRefresh;
      first.completeError(StateError('Older refresh failed'));
      await olderRefresh;
      expect(
        container.read(agentWorkspaceRunsProvider('ws_1')).value?.single.status,
        AgentRunStatus.succeeded,
      );
      expect(
        container.read(
          agentReadErrorProvider((
            resource: AgentReadResource.runs,
            id: 'ws_1',
          )),
        ),
        isNull,
      );
    },
  );

  test('task history remains available outside the workspace window', () async {
    final repository = RecordingRuntimeRepository(
      runs: [
        for (var i = 0; i < 50; i++)
          testRun(
            id: 'new_$i',
            taskId: 'new_task_$i',
            status: AgentRunStatus.waitingApproval,
          ),
        testRun(
          id: 'old_finished',
          taskId: 'old_task',
          status: AgentRunStatus.succeeded,
          createdAt: '2020-01-01T00:00:00Z',
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [agentRuntimeRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    const query = (workspaceId: 'ws_1', taskId: 'old_task');
    container.listen(agentRunsProvider(query), (_, _) {});
    expect(
      (await container.read(agentRunsProvider(query).future))
          .map((run) => run.id),
      ['old_finished'],
    );
  });

  test(
    'more than fifty pending runs cannot hide a task approval badge',
    () async {
      final repository = RecordingRuntimeRepository(
        runs: [
          for (var i = 0; i < 50; i++)
            testRun(
              id: 'new_$i',
              taskId: 'new_task_$i',
              status: AgentRunStatus.waitingApproval,
            ),
          testRun(
            id: 'old_waiting',
            taskId: 'old_task',
            status: AgentRunStatus.waitingApproval,
            createdAt: '2020-01-01T00:00:00Z',
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          agentRuntimeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      container.listen(taskRunIndexProvider('ws_1'), (_, _) {});
      expect(
        (await container.read(
          taskRunIndexProvider('ws_1').future,
        ))['old_task']?.id,
        'old_waiting',
      );
    },
  );

  testWidgets(
    'disconnected execution polls only its active task without list requests',
    (tester) async {
      final repository = RecordingRuntimeRepository(
        runs: [
          testRun(status: AgentRunStatus.running),
          testRun(
            id: 'run_2',
            taskId: 'task_2',
            status: AgentRunStatus.running,
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          agentRuntimeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: const Scaffold(
              body: AgentExecutionPanel(workspaceId: 'ws_1', taskId: 'task_1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initialListRequests = repository.listQueries.length;
      repository.runs = [
        testRun(status: AgentRunStatus.succeeded),
        testRun(id: 'run_2', taskId: 'task_2', status: AgentRunStatus.running),
      ];
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Completed'), findsOneWidget);
      expect(repository.getQueries, ['run_1']);
      expect(repository.listQueries, hasLength(initialListRequests));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('connected execution uses events instead of polling', (
    tester,
  ) async {
    final repository = RecordingRuntimeRepository(
      runs: [testRun(status: AgentRunStatus.running)],
    );
    final container = ProviderContainer(
      overrides: [agentRuntimeRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.read(agentRuntimeConnectedProvider.notifier).setConnected(true);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: const Scaffold(body: AgentExecutionPanel(workspaceId: 'ws_1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(repository.getQueries, isEmpty);
    expect(repository.listQueries, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('task badges share the execution panel workspace request', () async {
    final repository = RecordingRuntimeRepository(runs: [testRun()]);
    final container = ProviderContainer(
      overrides: [agentRuntimeRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    const query = (workspaceId: 'ws_1', taskId: null);
    container.listen(agentRunsProvider(query), (_, _) {});
    container.listen(taskRunIndexProvider('ws_1'), (_, _) {});
    await container.read(agentRunsProvider(query).future);
    final index = await container.read(taskRunIndexProvider('ws_1').future);
    expect(index['task_1']?.id, 'run_1');
    expect(repository.listQueries, [(workspaceId: 'ws_1', taskId: null)]);
  });

  test('approving one run keeps other workspace lists cached', () async {
    final repository = RecordingRuntimeRepository(
      runs: [
        testRun(status: AgentRunStatus.running),
        testRun(id: 'run_2', workspaceId: 'ws_2'),
      ],
    );
    final container = ProviderContainer(
      overrides: [agentRuntimeRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    const first = (workspaceId: 'ws_1', taskId: null);
    const other = (workspaceId: 'ws_2', taskId: null);
    container.listen(agentRunsProvider(first), (_, _) {});
    container.listen(agentRunsProvider(other), (_, _) {});
    await container.read(agentRunsProvider(first).future);
    await container.read(agentRunsProvider(other).future);
    await container
        .read(agentRunActionsProvider)
        .decide(runId: 'run_1', approvalId: 'apr_1', approve: true);
    await Future<void>.delayed(Duration.zero);
    expect(
      repository.listQueries.where((query) => query.workspaceId == 'ws_2'),
      hasLength(1),
    );
    expect(
      (await container.read(agentRunsProvider(first).future)).single.status,
      AgentRunStatus.running,
    );
  });

  test(
    'starting a run inserts its returned snapshot without refetching the list',
    () async {
      final repository = RecordingRuntimeRepository(runToStart: testRun());
      final container = ProviderContainer(
        overrides: [
          agentRuntimeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      const query = (workspaceId: 'ws_1', taskId: null);
      container.listen(agentRunsProvider(query), (_, _) {});
      await container.read(agentRunsProvider(query).future);
      await container
          .read(agentRunActionsProvider)
          .startOnTask(workspaceId: 'ws_1', taskId: 'task_1');
      await Future<void>.delayed(Duration.zero);
      expect(
        (await container.read(agentRunsProvider(query).future))
            .map((run) => run.id),
        ['run_1'],
      );
      expect(repository.listQueries, hasLength(1));
    },
  );

  test('an older pending approval outranks a newer running badge for the same task', () async {
    final repository = RecordingRuntimeRepository(
      runs: [
        testRun(
          id: 'waiting',
          status: AgentRunStatus.waitingApproval,
          createdAt: '2020-01-01T00:00:00Z',
        ),
        testRun(id: 'running', status: AgentRunStatus.running),
      ],
    );
    final container = ProviderContainer(
      overrides: [agentRuntimeRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container.listen(taskRunIndexProvider('ws_1'), (_, _) {});
    expect(
      (await container.read(taskRunIndexProvider('ws_1').future))['task_1']?.id,
      'waiting',
    );
  });

  testWidgets(
    'execution panel follows workspace and task changes on the same widget',
    (tester) async {
      final repository = RecordingRuntimeRepository(
        runs: [
          testRun(
            status: AgentRunStatus.succeeded,
            goal: 'First workspace task',
          ),
          testRun(
            id: 'run_2',
            workspaceId: 'ws_2',
            taskId: 'task_2',
            status: AgentRunStatus.succeeded,
            goal: 'Second workspace task',
          ),
        ],
      );
      Widget harness(String workspaceId, String taskId) => ProviderScope(
        overrides: [
          agentRuntimeRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: Scaffold(
            body: AgentExecutionPanel(
              key: const Key('execution'),
              workspaceId: workspaceId,
              taskId: taskId,
            ),
          ),
        ),
      );
      await tester.pumpWidget(harness('ws_1', 'task_1'));
      await tester.pumpAndSettle();
      expect(find.text('First workspace task'), findsOneWidget);
      await tester.pumpWidget(harness('ws_2', 'task_2'));
      await tester.pumpAndSettle();
      expect(find.text('Second workspace task'), findsOneWidget);
      expect(find.text('First workspace task'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
