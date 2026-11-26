import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/app/theme/app_theme.dart';
import 'package:microflow_frontend/core/providers/app_providers.dart';
import 'package:microflow_frontend/core/errors/app_exception.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_run.dart';
import 'package:microflow_frontend/features/tasks/data/dto/my_work_agenda_dto.dart';
import 'package:microflow_frontend/features/tasks/domain/entities/my_work_agenda.dart';
import 'package:microflow_frontend/features/tasks/domain/entities/task_activity.dart';
import 'package:microflow_frontend/features/tasks/domain/entities/task_item.dart';
import 'package:microflow_frontend/features/tasks/domain/entities/task_project.dart';
import 'package:microflow_frontend/features/tasks/domain/entities/task_summary.dart';
import 'package:microflow_frontend/features/tasks/domain/repositories/task_repository.dart';
import 'package:microflow_frontend/features/tasks/presentation/pages/my_work_page.dart';
import 'package:microflow_frontend/features/tasks/presentation/providers/task_queue_providers.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

const _workspaceId = 'ws_1';

void main() {
  testWidgets('a narrow large-text queue can select any task lane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeTaskRepository(
      agenda: const MyWorkAgenda(
        blocked: [
          TaskItem(
            id: 'blocked',
            workspaceId: _workspaceId,
            title: 'Blocked task',
            status: 'BLOCKED',
            priority: 'NORMAL',
          ),
        ],
      ),
    );
    await tester.pumpWidget(_harness(repository, textScale: 1.8));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final lanes = find.byKey(const Key('my-work-lane-menu'));
    expect(lanes, findsOneWidget);
    await tester.tap(lanes);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('my-work-lane-blocked')));
    await tester.pumpAndSettle();
    expect(find.text('Blocked task'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'queue actions share an unfinished status write across row remounts',
    () async {
      final repository = _PendingStatusRepository();
      final container = ProviderContainer(
        overrides: [taskRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final actions = container.read(taskQueueActionsProvider);
      final first = actions.setStatus(
        workspaceId: _workspaceId,
        taskId: 'task_1',
        status: 'DONE',
      );
      final second = actions.setStatus(
        workspaceId: _workspaceId,
        taskId: 'task_1',
        status: 'BLOCKED',
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        repository.statusCalls,
        1,
        reason:
            'a rebuilt row must not dispatch a second mutation for the same task',
      );
      final failureChecks = [
        expectLater(first, throwsException),
        expectLater(second, throwsException),
      ];
      repository.pending.completeError(Exception('controlled failure'));
      await Future.wait(failureChecks);
      repository.pending = Completer<TaskItem>();
      final retry = actions.setStatus(
        workspaceId: _workspaceId,
        taskId: 'task_1',
        status: 'DONE',
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        repository.statusCalls,
        2,
        reason: 'failed writes must release the task for retry',
      );
      repository.pending.complete(
        const TaskItem(
          id: 'task_1',
          workspaceId: _workspaceId,
          title: 'Recoverable task',
          status: 'DONE',
          priority: 'NORMAL',
        ),
      );
      await retry;
    },
  );

  for (final error in [
    Exception('network down'),
    const AppException('403 permission denied'),
    const AppException('409 state conflict'),
  ]) {
    testWidgets(
      'queue status $error is visible and retryable without an unhandled future',
      (tester) async {
        final repository = _PendingStatusRepository();
        await tester.pumpWidget(_harness(repository));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done').last);
        await tester.pumpAndSettle();
        repository.pending.completeError(error);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining(error.toString()), findsOneWidget);
        expect(find.text('Recoverable task'), findsOneWidget);
        repository.pending = Completer<TaskItem>();
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done').last);
        await tester.pumpAndSettle();
        repository.pending.complete(
          const TaskItem(
            id: 'task_1',
            workspaceId: _workspaceId,
            title: 'Recoverable task',
            status: 'DONE',
            priority: 'NORMAL',
          ),
        );
        await tester.pumpAndSettle();
        expect(repository.myWorkCalls, 2);
        expect(find.textContaining(error.toString()), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'waiting queue status action disables duplicate menu submissions',
    (tester) async {
      final repository = _PendingStatusRepository();
      await tester.pumpWidget(_harness(repository));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .enabled,
        isFalse,
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(repository.statusCalls, 1);
      repository.pending.completeError(Exception('controlled failure'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .enabled,
        isTrue,
      );
    },
  );

  test(
    'server execution lanes contribute to open work without client rebucketing',
    () {
      final agenda = MyWorkAgendaDto.fromJson({
        'running': [
          {
            'id': 'running_task',
            'workspaceId': _workspaceId,
            'title': 'Agent is working',
          },
        ],
        'waitingApproval': [
          {
            'id': 'review_task',
            'workspaceId': _workspaceId,
            'title': 'Review a write',
          },
        ],
      }).toDomain();
      expect(agenda.openCount, 2);
      expect(agenda.allTasks.map((task) => task.id), [
        'running_task',
        'review_task',
      ]);
      expect(agenda.isEmpty, isFalse);
    },
  );

  testWidgets('running and approval lanes reveal the server assigned tasks', (
    tester,
  ) async {
    final repository = _FakeTaskRepository(
      agenda: MyWorkAgendaDto.fromJson({
        'running': [
          {
            'id': 'running_task',
            'workspaceId': _workspaceId,
            'title': 'Agent is working',
          },
        ],
        'waitingApproval': [
          {
            'id': 'review_task',
            'workspaceId': _workspaceId,
            'title': 'Review a write',
          },
        ],
      }).toDomain(),
    );
    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my-work-lane-running')), findsOneWidget);
    await tester.tap(find.byKey(const Key('my-work-lane-running')));
    await tester.pumpAndSettle();
    expect(find.text('Agent is working'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('my-work-lane-waitingApproval')),
    );
    await tester.tap(find.byKey(const Key('my-work-lane-waitingApproval')));
    await tester.pumpAndSettle();
    expect(find.text('Review a write'), findsOneWidget);
    expect(find.text('Agent is working'), findsNothing);
  });

  test('agenda dto buckets tasks and skips a malformed lane', () {
    final agenda = MyWorkAgendaDto.fromJson({
      'actionable': [
        {'id': 'task_1', 'workspaceId': _workspaceId, 'title': 'Ship it'},
      ],
      'blocked': [
        {'id': 'task_2', 'workspaceId': _workspaceId, 'title': 'Waiting'},
      ],
      'awaitingOthers': 'not-a-list',
      'recentlyDone': [
        {'id': 'task_3', 'workspaceId': _workspaceId, 'title': 'Done'},
      ],
    }).toDomain();

    expect(agenda.actionable.single.id, 'task_1');
    expect(agenda.blocked.single.id, 'task_2');
    expect(
      agenda.awaitingOthers,
      isEmpty,
      reason: 'a broken lane must not fail the whole agenda',
    );
    expect(agenda.recentlyDone.single.id, 'task_3');
    expect(agenda.openCount, 2);
    expect(agenda.isEmpty, isFalse);
  });

  test('empty agenda is empty and has nothing open', () {
    const agenda = MyWorkAgenda.empty();
    expect(agenda.isEmpty, isTrue);
    expect(agenda.openCount, 0);
    expect(agenda.tasksFor(MyWorkLane.blocked), isEmpty);
  });

  testWidgets('queue shows every lane with its count and the actionable task', (
    tester,
  ) async {
    final repository = _FakeTaskRepository(
      agenda: const MyWorkAgenda(
        actionable: [
          TaskItem(
            id: 'task_1',
            workspaceId: _workspaceId,
            title: 'Harden the pairing flow',
            status: 'OPEN',
            priority: 'HIGH',
          ),
        ],
        blocked: [
          TaskItem(
            id: 'task_2',
            workspaceId: _workspaceId,
            title: 'Blocked by the vendor',
            status: 'BLOCKED',
            priority: 'NORMAL',
          ),
        ],
        awaitingOthers: [
          TaskItem(
            id: 'task_3',
            workspaceId: _workspaceId,
            title: 'Review with the team',
            status: 'IN_PROGRESS',
            priority: 'NORMAL',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    expect(find.text('Harden the pairing flow'), findsOneWidget);
    expect(find.text('Blocked by the vendor'), findsNothing);
    expect(find.textContaining('To do · 1'), findsOneWidget);
    expect(find.textContaining('Blocked · 1'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('my-work-lane-blocked')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Waiting on others · 1'), findsOneWidget);
    expect(find.textContaining('Recently done · 0'), findsOneWidget);
  });

  testWidgets('switching lanes swaps the visible queue', (tester) async {
    final repository = _FakeTaskRepository(
      agenda: const MyWorkAgenda(
        actionable: [
          TaskItem(
            id: 'task_1',
            workspaceId: _workspaceId,
            title: 'Harden the pairing flow',
            status: 'OPEN',
            priority: 'HIGH',
          ),
        ],
        blocked: [
          TaskItem(
            id: 'task_2',
            workspaceId: _workspaceId,
            title: 'Blocked by the vendor',
            status: 'BLOCKED',
            priority: 'NORMAL',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('my-work-lane-blocked')));
    await tester.pumpAndSettle();

    expect(find.text('Blocked by the vendor'), findsOneWidget);
    expect(find.text('Harden the pairing flow'), findsNothing);
  });

  testWidgets('an overdue task is flagged, a dated one shows its due date', (
    tester,
  ) async {
    final repository = _FakeTaskRepository(
      agenda: MyWorkAgenda(
        actionable: [
          TaskItem(
            id: 'task_1',
            workspaceId: _workspaceId,
            title: 'Late one',
            status: 'OPEN',
            priority: 'NORMAL',
            dueAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
          TaskItem(
            id: 'task_2',
            workspaceId: _workspaceId,
            title: 'Later one',
            status: 'OPEN',
            priority: 'NORMAL',
            dueAt: DateTime(2099, 3, 4),
          ),
        ],
      ),
    );

    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(MyWorkPage)))!;
    expect(find.text(l10n.myWorkOverdue), findsOneWidget);
    expect(find.text(l10n.myWorkDueOn('2099-03-04')), findsOneWidget);
  });

  testWidgets('a task with an agent run shows the run status chip', (
    tester,
  ) async {
    final repository = _FakeTaskRepository(
      agenda: const MyWorkAgenda(
        actionable: [
          TaskItem(
            id: 'task_1',
            workspaceId: _workspaceId,
            title: 'Harden the pairing flow',
            status: 'IN_PROGRESS',
            priority: 'HIGH',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      _harness(
        repository,
        runIndex: {
          'task_1': AgentRunSummary(
            id: 'run_1',
            workspaceId: _workspaceId,
            agentKey: 'openclaw',
            kind: 'TASK',
            status: AgentRunStatus.waitingApproval,
            goal: 'Harden the pairing flow',
            taskId: 'task_1',
            createdAt: '2026-10-28T04:00:00Z',
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my-work-run-task_1')), findsOneWidget);
    expect(find.text('Waiting approval'), findsOneWidget);
  });

  testWidgets('run agent action is wired to the callback', (tester) async {
    final repository = _FakeTaskRepository(
      agenda: const MyWorkAgenda(
        actionable: [
          TaskItem(
            id: 'task_1',
            workspaceId: _workspaceId,
            title: 'Harden the pairing flow',
            status: 'OPEN',
            priority: 'HIGH',
          ),
        ],
      ),
    );
    final started = <String>[];

    await tester.pumpWidget(
      _harness(repository, onRunAgent: (task) async => started.add(task.id)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('my-work-run-agent-task_1')));
    await tester.pumpAndSettle();

    expect(started, ['task_1']);
  });

  testWidgets('marking a task done persists and refetches the queue', (
    tester,
  ) async {
    final repository = _FakeTaskRepository(
      agenda: const MyWorkAgenda(
        actionable: [
          TaskItem(
            id: 'task_1',
            workspaceId: _workspaceId,
            title: 'Harden the pairing flow',
            status: 'OPEN',
            priority: 'HIGH',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(MyWorkPage)))!;
    await tester.tap(find.text(l10n.taskStatusDone));
    await tester.pumpAndSettle();

    expect(
      repository.updatedStatuses,
      contains((taskId: 'task_1', status: 'DONE')),
    );
    expect(
      repository.myWorkCalls,
      greaterThanOrEqualTo(2),
      reason: 'the queue must refetch after a status change',
    );
  });

  testWidgets('an empty queue explains itself and can jump to all tasks', (
    tester,
  ) async {
    final repository = _FakeTaskRepository();

    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(MyWorkPage)))!;
    expect(find.byKey(const Key('my-work-empty')), findsOneWidget);
    expect(find.text(l10n.myWorkEmptyTitle), findsOneWidget);

    await tester.tap(find.byKey(const Key('my-work-browse-all')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('task-workbench')), findsOneWidget);
  });

  testWidgets('a failed agenda surfaces a retry that refetches', (
    tester,
  ) async {
    final repository = _FakeTaskRepository(shouldFail: true);

    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my-work-error')), findsOneWidget);
    expect(find.textContaining('network down'), findsOneWidget);

    repository.shouldFail = false;
    await tester.tap(find.byKey(const Key('my-work-retry')));
    await tester.pumpAndSettle();

    expect(repository.myWorkCalls, greaterThanOrEqualTo(2));
    expect(find.byKey(const Key('my-work-error')), findsNothing);
  });
}

class _PendingStatusRepository extends _FakeTaskRepository {
  _PendingStatusRepository()
    : super(
        agenda: const MyWorkAgenda(
          actionable: [
            TaskItem(
              id: 'task_1',
              workspaceId: _workspaceId,
              title: 'Recoverable task',
              status: 'OPEN',
              priority: 'NORMAL',
            ),
          ],
        ),
      );
  var pending = Completer<TaskItem>();
  int statusCalls = 0;
  @override
  Future<TaskItem> updateStatus({
    required String workspaceId,
    required String taskId,
    required String status,
  }) {
    statusCalls++;
    return pending.future;
  }
}

Widget _harness(
  TaskRepository repository, {
  double textScale = 1,
  Map<String, AgentRunSummary> runIndex = const {},
  Future<void> Function(TaskItem task)? onRunAgent,
}) {
  return ProviderScope(
    overrides: [
      taskRepositoryProvider.overrideWithValue(repository),
      taskRunIndexProvider(_workspaceId).overrideWith((ref) async => runIndex),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: MyWorkPage(
          workspaceId: _workspaceId,
          currentUserId: 'usr_1',
          onRunAgent: onRunAgent,
        ),
      ),
    ),
  );
}

class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository({
    this.agenda = const MyWorkAgenda.empty(),
    this.shouldFail = false,
  });

  final MyWorkAgenda agenda;
  bool shouldFail;

  int myWorkCalls = 0;
  final List<({String taskId, String status})> updatedStatuses = [];

  void _maybeFail() {
    if (shouldFail) {
      throw Exception('network down');
    }
  }

  @override
  Future<MyWorkAgenda> myWork({
    required String workspaceId,
    int limit = 50,
  }) async {
    myWorkCalls++;
    _maybeFail();
    return agenda;
  }

  @override
  Future<List<TaskProject>> listProjects(String workspaceId) async {
    _maybeFail();
    return const [];
  }

  @override
  Future<TaskProject> createProject({
    required String workspaceId,
    required String name,
    String? description,
  }) async {
    _maybeFail();
    return TaskProject(
      id: 'proj_new',
      name: name,
      status: 'ACTIVE',
      taskCount: 0,
      openTaskCount: 0,
    );
  }

  @override
  Future<List<TaskItem>> listTasks({
    required String workspaceId,
    String? projectId,
    String? status,
    String? assignee,
    bool mine = false,
  }) async {
    _maybeFail();
    return const [];
  }

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
    _maybeFail();
    return TaskItem(
      id: 'task_new',
      workspaceId: workspaceId,
      title: title,
      status: status ?? 'OPEN',
      priority: priority ?? 'NORMAL',
    );
  }

  @override
  Future<TaskItem> updateStatus({
    required String workspaceId,
    required String taskId,
    required String status,
  }) async {
    _maybeFail();
    updatedStatuses.add((taskId: taskId, status: status));
    for (final task in agenda.allTasks) {
      if (task.id == taskId) {
        return TaskItem(
          id: task.id,
          workspaceId: task.workspaceId,
          title: task.title,
          status: status,
          priority: task.priority,
        );
      }
    }
    throw StateError('unknown task $taskId');
  }

  @override
  Future<TaskItem> assign({
    required String workspaceId,
    required String taskId,
    String? assigneeUserId,
    bool assigneeIsSelf = false,
  }) async {
    _maybeFail();
    throw UnimplementedError('not used by the my-work queue');
  }

  @override
  Future<List<TaskActivity>> listActivity({
    required String workspaceId,
    required String taskId,
  }) async {
    _maybeFail();
    return const [];
  }

  @override
  Future<TaskSummary> summarize({
    required String workspaceId,
    String? projectId,
  }) async {
    _maybeFail();
    return const TaskSummary.empty();
  }
}
