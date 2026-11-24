import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/app/theme/app_theme.dart';
import 'package:microflow_frontend/features/tasks/data/dto/task_activity_dto.dart';
import 'package:microflow_frontend/features/tasks/data/dto/task_item_dto.dart';
import 'package:microflow_frontend/features/tasks/domain/entities/my_work_agenda.dart';
import 'package:microflow_frontend/features/tasks/domain/entities/task_activity.dart';
import 'package:microflow_frontend/features/tasks/domain/entities/task_item.dart';
import 'package:microflow_frontend/features/tasks/domain/entities/task_project.dart';
import 'package:microflow_frontend/features/tasks/domain/entities/task_summary.dart';
import 'package:microflow_frontend/features/tasks/domain/repositories/task_repository.dart';
import 'package:microflow_frontend/features/tasks/presentation/pages/task_workbench_page.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

void main() {
  testWidgets('create Enter plus tap sends one write while the button waits', (
    tester,
  ) async {
    final repository = _PendingCreateRepository();
    await tester.pumpWidget(_scopeHarness(repository, 'A'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Draft A');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(repository.creates.length, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    repository.complete(0);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  for (final edited in [
    ['Draft B'],
    ['Draft B', 'Draft A'],
  ]) {
    testWidgets(
      'create completion preserves independently edited ${edited.join(' to ')}',
      (tester) async {
        final repository = _PendingCreateRepository();
        await tester.pumpWidget(_scopeHarness(repository, 'A'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Draft A');
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        for (final title in edited) {
          await tester.enterText(find.byType(TextField).first, title);
        }
        repository.complete(0);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          edited.last,
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failed create keeps its draft and releases submission for retry',
    (tester) async {
      final repository = _PendingCreateRepository();
      await tester.pumpWidget(_scopeHarness(repository, 'A'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Recoverable draft');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      repository.creates[0].response.completeError(
        StateError('Create rejected'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Create rejected'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Recoverable draft',
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(repository.creates.map((request) => request.title), [
        'Recoverable draft',
        'Recoverable draft',
      ]);
      repository.complete(1);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final workspaces in [
    ['B'],
    ['B', 'A'],
  ]) {
    testWidgets(
      'old scope finally cannot release a newer ${workspaces.join(' to ')} create',
      (tester) async {
        final repository = _PendingCreateRepository();
        await tester.pumpWidget(_scopeHarness(repository, 'A'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Original A');
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        for (final workspace in workspaces) {
          await tester.pumpWidget(_scopeHarness(repository, workspace));
          await tester.pumpAndSettle();
        }
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        await tester.enterText(
          find.byType(TextField).first,
          'Current scope draft',
        );
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        expect(repository.creates.map((request) => request.workspaceId), [
          'A',
          workspaces.last,
        ]);
        repository.complete(0);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          'Current scope draft',
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(repository.creates.length, 2);
        repository.complete(1);
        await tester.pumpAndSettle();
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
      },
    );
  }

  testWidgets('All tasks awaits its run menu and reports a retryable failure', (
    tester,
  ) async {
    final repository = _FakeTaskRepository(
      tasks: const [
        TaskItem(
          id: 'task_1',
          workspaceId: 'A',
          title: 'Run this task',
          status: 'OPEN',
          priority: 'NORMAL',
        ),
      ],
    );
    var response = Completer<void>();
    var starts = 0;
    await tester.pumpWidget(
      _scopeHarness(
        repository,
        'A',
        onRunAgent: (task) {
          starts++;
          return response.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-run-agent-task_1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>))
          .enabled,
      isFalse,
    );
    response.completeError(StateError('Start request rejected'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Start request rejected'), findsOneWidget);
    expect(
      tester
          .widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>))
          .enabled,
      isTrue,
    );
    response = Completer<void>();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-run-agent-task_1')));
    await tester.pump();
    expect(starts, 2);
    response.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Start request rejected'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final fails in [false, true]) {
    testWidgets(
      'a create ${fails ? 'failure' : 'completion'} from the old scope does not clear or reload the current draft',
      (tester) async {
        final repository = _DeferredTaskRepository()
          ..createResult = Completer<TaskItem>();
        await tester.pumpWidget(_scopeHarness(repository, 'A'));
        repository.complete(0, 'A current');
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'A draft');
        final l10n = AppLocalizations.of(
          tester.element(find.byType(TaskWorkbenchView)),
        )!;
        await tester.tap(find.text(l10n.taskCreateAction));
        await tester.pump();
        expect(repository.createdScopes.single, (
          workspaceId: 'A',
          title: 'A draft',
          projectId: null,
          mine: false,
        ));
        await tester.pumpWidget(_scopeHarness(repository, 'B'));
        repository.complete(1, 'B current');
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'B draft');
        if (fails) {
          repository.createResult!.completeError(
            Exception('obsolete create failure'),
          );
        } else {
          repository.createResult!.complete(
            const TaskItem(
              id: 'created',
              workspaceId: 'A',
              title: 'A draft',
              status: 'OPEN',
              priority: 'NORMAL',
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          'B draft',
        );
        expect(repository.requests.length, 2);
        expect(find.textContaining('obsolete'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'project dialog never submits into a workspace selected after it opened',
    (tester) async {
      final repository = _DeferredTaskRepository();
      await tester.pumpWidget(_scopeHarness(repository, 'A'));
      repository.complete(0, 'A current');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.create_new_folder_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'A project draft',
      );
      await tester.pumpWidget(_scopeHarness(repository, 'B'));
      repository.complete(1, 'B current');
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AlertDialog)),
      )!;
      await tester.tap(find.text(l10n.taskCreateProjectAction));
      await tester.pumpAndSettle();
      expect(repository.createdProjectScopes, isEmpty);
      expect(find.text('B current'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mounted workspace changes reset projects, filters and task scope',
    (tester) async {
      final repository = _DeferredTaskRepository();
      await tester.pumpWidget(_scopeHarness(repository, 'A'));
      repository.complete(0, 'A current');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Project A (1)'));
      await tester.pump();
      repository.complete(1, 'A project');
      await tester.pumpAndSettle();
      await tester.pumpWidget(_scopeHarness(repository, 'B'));
      await tester.pump();
      expect(find.text('A project'), findsNothing);
      expect(find.text('Project A (1)'), findsNothing);
      expect(repository.requests.last.workspaceId, 'B');
      expect(repository.requests.last.projectId, isNull);
      repository.complete(2, 'B current');
      await tester.pumpAndSettle();
      expect(find.text('B current'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done').last);
      await tester.pumpAndSettle();
      expect(repository.statusScopes, ['B:B_task_2']);
    },
  );

  testWidgets('A to B to A ignores the earlier A completion', (tester) async {
    final repository = _DeferredTaskRepository();
    await tester.pumpWidget(_scopeHarness(repository, 'A'));
    await tester.pumpWidget(_scopeHarness(repository, 'B'));
    await tester.pumpWidget(_scopeHarness(repository, 'A'));
    expect(repository.requests.length, 3);
    repository.complete(2, 'latest A');
    await tester.pumpAndSettle();
    repository.complete(0, 'obsolete A');
    repository.complete(1, 'obsolete B');
    await tester.pumpAndSettle();
    expect(find.text('latest A'), findsOneWidget);
    expect(find.textContaining('obsolete'), findsNothing);
  });

  for (final staleFails in [false, true]) {
    testWidgets(
      'old filter ${staleFails ? 'failure' : 'success'} cannot replace the latest result',
      (tester) async {
        final repository = _DeferredTaskRepository();
        await tester.pumpWidget(_scopeHarness(repository, 'A'));
        repository.complete(0, 'initial');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('task-status-filter-OPEN')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('task-status-filter-BLOCKED')));
        await tester.pump();
        expect(repository.requests[1].status, 'OPEN');
        expect(repository.requests[2].status, 'BLOCKED');
        repository.complete(2, 'latest blocked');
        await tester.pumpAndSettle();
        if (staleFails) {
          repository.requests[1].result.completeError(
            Exception('obsolete failure'),
          );
        } else {
          repository.complete(1, 'obsolete open');
        }
        await tester.pumpAndSettle();
        expect(find.text('latest blocked'), findsOneWidget);
        expect(find.textContaining('obsolete'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('repository and user changes reload the mounted view', (
    tester,
  ) async {
    final first = _DeferredTaskRepository();
    final second = _DeferredTaskRepository();
    await tester.pumpWidget(_scopeHarness(first, 'A'));
    first.complete(0, 'first repository');
    await tester.pumpAndSettle();
    await tester.pumpWidget(_scopeHarness(second, 'A'));
    expect(second.requests.length, 1);
    second.complete(0, 'second repository');
    await tester.pumpAndSettle();
    await tester.pumpWidget(_scopeHarness(second, 'A', userId: 'other'));
    expect(second.requests.length, 2);
    second.complete(1, 'other user');
    await tester.pumpAndSettle();
    expect(find.text('other user'), findsOneWidget);
    expect(find.text('first repository'), findsNothing);
  });

  test('task dto maps json payload and derives overdue state', () {
    final task = TaskItemDto.fromJson({
      'id': 'task_1',
      'workspaceId': 'ws_1',
      'title': 'Fix pairing',
      'status': 'IN_PROGRESS',
      'priority': 'HIGH',
      'projectId': 'proj_1',
      'projectName': 'Stabilize',
      'assigneeUserId': 'usr_2',
      'assigneeDisplayName': 'Teammate',
      'dueAt': '2020-01-01T00:00:00Z',
    }).toDomain();

    expect(task.id, 'task_1');
    expect(task.status, 'IN_PROGRESS');
    expect(task.priority, 'HIGH');
    expect(task.projectName, 'Stabilize');
    expect(task.assigneeDisplayName, 'Teammate');
    expect(task.dueAt, isNotNull);
    expect(task.isDone, isFalse);
    expect(
      task.isOverdue,
      isTrue,
      reason: 'a past due date must read as overdue',
    );
    expect(task.isUnassigned, isFalse);
  });

  test('task dto defaults missing fields instead of throwing', () {
    final task = TaskItemDto.fromJson({
      'id': 'task_2',
      'workspaceId': 'ws_1',
      'title': 'Bare task',
    }).toDomain();

    expect(task.status, 'OPEN');
    expect(task.priority, 'NORMAL');
    expect(task.dueAt, isNull);
    expect(task.isOverdue, isFalse, reason: 'no due date means never overdue');
    expect(task.isUnassigned, isTrue);
  });

  test('completed task is never overdue', () {
    const done = TaskItem(
      id: 'task_3',
      workspaceId: 'ws_1',
      title: 'Shipped',
      status: 'DONE',
      priority: 'NORMAL',
    );
    expect(done.isDone, isTrue);
    expect(done.isOverdue, isFalse);
  });

  testWidgets('workbench lists tasks and shows the summary strip', (
    tester,
  ) async {
    final repository = _FakeTaskRepository(
      projects: const [
        TaskProject(
          id: 'proj_1',
          name: 'Stabilize',
          status: 'ACTIVE',
          taskCount: 2,
          openTaskCount: 1,
        ),
      ],
      tasks: const [
        TaskItem(
          id: 'task_1',
          workspaceId: 'ws_1',
          title: 'Harden the pairing flow',
          status: 'IN_PROGRESS',
          priority: 'HIGH',
          projectName: 'Stabilize',
          assigneeUserId: 'usr_1',
          assigneeDisplayName: 'Engineer',
        ),
        TaskItem(
          id: 'task_2',
          workspaceId: 'ws_1',
          title: 'Write the runbook',
          status: 'OPEN',
          priority: 'NORMAL',
        ),
      ],
      summary: const TaskSummary(
        total: 2,
        open: 1,
        inProgress: 1,
        blocked: 0,
        done: 0,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TaskWorkbenchView(workspaceId: 'ws_1', repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Harden the pairing flow'), findsOneWidget);
    expect(find.text('Write the runbook'), findsOneWidget);
    expect(find.text('Stabilize (1)'), findsOneWidget);
    expect(repository.listProjectsCalls, 1);
    expect(repository.listTasksCalls, 1);
  });

  testWidgets('empty state guides the user to add the first task', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TaskWorkbenchView(
            workspaceId: 'ws_1',
            repository: _FakeTaskRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(TaskWorkbenchView)),
    )!;
    expect(find.text(l10n.taskEmptyState), findsOneWidget);
  });

  testWidgets('creating a task sends the title and refreshes the list', (
    tester,
  ) async {
    final repository = _FakeTaskRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TaskWorkbenchView(workspaceId: 'ws_1', repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Book the venue');
    final l10n = AppLocalizations.of(
      tester.element(find.byType(TaskWorkbenchView)),
    )!;
    await tester.tap(find.text(l10n.taskCreateAction));
    await tester.pumpAndSettle();

    expect(repository.createdTitles, contains('Book the venue'));
    expect(
      repository.listTasksCalls,
      greaterThanOrEqualTo(2),
      reason: 'a reload must follow a successful create',
    );
  });

  testWidgets('blank task titles are never submitted', (tester) async {
    final repository = _FakeTaskRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TaskWorkbenchView(workspaceId: 'ws_1', repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(TaskWorkbenchView)),
    )!;
    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.tap(find.text(l10n.taskCreateAction));
    await tester.pumpAndSettle();

    expect(repository.createdTitles, isEmpty);
  });

  testWidgets('repository failures surface instead of silently showing empty', (
    tester,
  ) async {
    final repository = _FakeTaskRepository(shouldFail: true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TaskWorkbenchView(workspaceId: 'ws_1', repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('network down'), findsOneWidget);
  });

  testWidgets('status filter is forwarded to the repository', (tester) async {
    final repository = _FakeTaskRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TaskWorkbenchView(workspaceId: 'ws_1', repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('task-status-filter-BLOCKED')));
    await tester.pumpAndSettle();

    expect(repository.requestedStatuses, contains('BLOCKED'));
  });

  test('activity dto maps actor and transition values', () {
    final activity = TaskActivityDto(
      id: 'act_1',
      eventType: 'STATUS_CHANGED',
      createdAt: '2026-01-01T10:00:00Z',
      actorDisplayName: 'Engineer',
      fromValue: 'OPEN',
      toValue: 'IN_PROGRESS',
    ).toDomain();

    expect(activity.eventType, 'STATUS_CHANGED');
    expect(activity.actorDisplayName, 'Engineer');
    expect(activity.fromValue, 'OPEN');
    expect(activity.toValue, 'IN_PROGRESS');
    expect(
      activity.createdAt.isUtc,
      isFalse,
      reason: 'must be localized for display',
    );
  });

  test('empty summary reports zero for every bucket', () {
    const summary = TaskSummary.empty();
    expect(summary.total, 0);
    expect(summary.open, 0);
    expect(summary.inProgress, 0);
    expect(summary.blocked, 0);
    expect(summary.done, 0);
  });
}

Widget _scopeHarness(
  TaskRepository repository,
  String workspaceId, {
  String userId = 'me',
  Future<void> Function(TaskItem)? onRunAgent,
}) => MaterialApp(
  theme: AppTheme.light(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: TaskWorkbenchView(
      workspaceId: workspaceId,
      repository: repository,
      currentUserId: userId,
      onRunAgent: onRunAgent,
    ),
  ),
);

class _PendingCreateRepository extends _FakeTaskRepository {
  final creates =
      <({String workspaceId, String title, Completer<TaskItem> response})>[];
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
  }) {
    final response = Completer<TaskItem>();
    creates.add((workspaceId: workspaceId, title: title, response: response));
    return response.future;
  }

  void complete(int index) {
    final request = creates[index];
    request.response.complete(
      TaskItem(
        id: 'created_$index',
        workspaceId: request.workspaceId,
        title: request.title,
        status: 'OPEN',
        priority: 'NORMAL',
      ),
    );
  }
}

class _DeferredTaskRepository extends _FakeTaskRepository {
  final requests =
      <
        ({
          String workspaceId,
          String? projectId,
          String? status,
          bool mine,
          Completer<List<TaskItem>> result,
        })
      >[];
  final statusScopes = <String>[];
  final createdScopes =
      <({String workspaceId, String title, String? projectId, bool mine})>[];
  final createdProjectScopes = <String>[];
  Completer<TaskItem>? createResult;

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
  }) {
    createdScopes.add((
      workspaceId: workspaceId,
      title: title,
      projectId: projectId,
      mine: assigneeIsSelf,
    ));
    return createResult!.future;
  }

  @override
  Future<TaskProject> createProject({
    required String workspaceId,
    required String name,
    String? description,
  }) async {
    createdProjectScopes.add(workspaceId);
    return TaskProject(
      id: 'created_project',
      name: name,
      status: 'ACTIVE',
      taskCount: 0,
      openTaskCount: 0,
    );
  }

  @override
  Future<List<TaskProject>> listProjects(String workspaceId) async => [
    TaskProject(
      id: '${workspaceId}_project',
      name: 'Project $workspaceId',
      status: 'ACTIVE',
      taskCount: 1,
      openTaskCount: 1,
    ),
  ];

  @override
  Future<List<TaskItem>> listTasks({
    required String workspaceId,
    String? projectId,
    String? status,
    String? assignee,
    bool mine = false,
  }) {
    final result = Completer<List<TaskItem>>();
    requests.add((
      workspaceId: workspaceId,
      projectId: projectId,
      status: status,
      mine: mine,
      result: result,
    ));
    return result.future;
  }

  void complete(int index, String title) {
    final request = requests[index];
    request.result.complete([
      TaskItem(
        id: '${request.workspaceId}_task_$index',
        workspaceId: request.workspaceId,
        title: title,
        status: request.status ?? 'OPEN',
        priority: 'NORMAL',
      ),
    ]);
  }

  @override
  Future<TaskItem> updateStatus({
    required String workspaceId,
    required String taskId,
    required String status,
  }) async {
    statusScopes.add('$workspaceId:$taskId');
    throw Exception('controlled action refusal');
  }
}

class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository({
    this.projects = const [],
    this.tasks = const [],
    this.summary = const TaskSummary.empty(),
    this.shouldFail = false,
  });

  final List<TaskProject> projects;
  final List<TaskItem> tasks;
  final TaskSummary summary;
  final bool shouldFail;

  final List<String> createdTitles = [];
  final List<String?> requestedStatuses = [];

  int listProjectsCalls = 0;
  int listTasksCalls = 0;

  void _maybeFail() {
    if (shouldFail) {
      throw Exception('network down');
    }
  }

  @override
  Future<List<TaskProject>> listProjects(String workspaceId) async {
    listProjectsCalls++;
    _maybeFail();
    return projects;
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
      description: description,
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
    listTasksCalls++;
    requestedStatuses.add(status);
    _maybeFail();
    return tasks;
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
    createdTitles.add(title);
    return TaskItem(
      id: 'task_new',
      workspaceId: workspaceId,
      title: title,
      status: status ?? 'OPEN',
      priority: priority ?? 'NORMAL',
      projectId: projectId,
    );
  }

  @override
  Future<TaskItem> updateStatus({
    required String workspaceId,
    required String taskId,
    required String status,
  }) async {
    _maybeFail();
    return tasks.firstWhere((task) => task.id == taskId);
  }

  @override
  Future<TaskItem> assign({
    required String workspaceId,
    required String taskId,
    String? assigneeUserId,
    bool assigneeIsSelf = false,
  }) async {
    _maybeFail();
    return tasks.firstWhere((task) => task.id == taskId);
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
    return summary;
  }

  @override
  Future<MyWorkAgenda> myWork({
    required String workspaceId,
    int limit = 50,
  }) async {
    _maybeFail();
    return const MyWorkAgenda.empty();
  }
}
