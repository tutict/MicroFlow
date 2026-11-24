import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_run.dart';
import 'package:microflow_frontend/features/agent_runtime/presentation/providers/agent_runtime_providers.dart';
import 'package:microflow_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:microflow_frontend/features/auth/presentation/providers/auth_session_controller.dart';

import 'support/recording_runtime_repository.dart';

void main() {
  test(
    'unfinished task start shares one write and allows an explicit later run',
    () async {
      final container = await _container();
      final repository = container.read(_runtimeHolder);
      final actions = container.read(agentRunActionsProvider);
      final first = actions.startOnTask(
        workspaceId: 'ws_1',
        taskId: 'task_1',
        agentKey: 'assistant',
        goal: 'Original goal',
      );
      final duplicate = container
          .read(agentRunActionsProvider)
          .startOnTask(
            workspaceId: 'ws_1',
            taskId: 'task_1',
            agentKey: 'other',
            goal: 'Duplicate goal',
          );
      await Future<void>.delayed(Duration.zero);
      expect(repository.requests.length, 1);
      expect(repository.requests.single.agentKey, 'assistant');
      expect(repository.requests.single.goal, 'Original goal');
      repository.complete(0, 'first_run');
      expect((await first).id, 'first_run');
      expect((await duplicate).id, 'first_run');
      final later = actions.startOnTask(workspaceId: 'ws_1', taskId: 'task_1');
      await Future<void>.delayed(Duration.zero);
      expect(repository.requests.length, 2);
      repository.complete(1, 'explicit_later_run');
      expect((await later).id, 'explicit_later_run');
    },
  );

  test(
    'pending starts for different tasks and workspaces do not block each other',
    () async {
      final container = await _container();
      final repository = container.read(_runtimeHolder);
      final actions = container.read(agentRunActionsProvider);
      final requests = [
        actions.startOnTask(workspaceId: 'ws_1', taskId: 'task_1'),
        actions.startOnTask(workspaceId: 'ws_1', taskId: 'task_2'),
        actions.startOnTask(workspaceId: 'ws_2', taskId: 'task_1'),
      ];
      await Future<void>.delayed(Duration.zero);
      expect(
        repository.requests.map(
          (request) => (request.workspaceId, request.taskId),
        ),
        [('ws_1', 'task_1'), ('ws_1', 'task_2'), ('ws_2', 'task_1')],
      );
      for (var i = 0; i < 3; i++) {
        repository.complete(i, 'run_$i');
      }
      expect((await Future.wait(requests)).map((run) => run.id), [
        'run_0',
        'run_1',
        'run_2',
      ]);
    },
  );

  test('shared failed start releases the task for a later retry', () async {
    final container = await _container();
    final repository = container.read(_runtimeHolder);
    final actions = container.read(agentRunActionsProvider);
    final first = actions.startOnTask(workspaceId: 'ws_1', taskId: 'task_1');
    final duplicate = actions.startOnTask(
      workspaceId: 'ws_1',
      taskId: 'task_1',
    );
    await Future<void>.delayed(Duration.zero);
    expect(repository.requests.length, 1);
    final failures = [
      expectLater(first, throwsStateError),
      expectLater(duplicate, throwsStateError),
    ];
    repository.requests[0].response.completeError(
      StateError('HTTP start rejected'),
    );
    await Future.wait(failures);
    final retry = actions.startOnTask(workspaceId: 'ws_1', taskId: 'task_1');
    await Future<void>.delayed(Duration.zero);
    expect(repository.requests.length, 2);
    repository.complete(1, 'retried_run');
    expect((await retry).id, 'retried_run');
  });

  for (final boundary in ['repository', 'session']) {
    test(
      '$boundary A to B to A does not share or apply an obsolete start',
      () async {
        final container = await _container();
        final repository = container.read(_runtimeHolder);
        container.listen(agentWorkspaceRunsProvider('ws_1'), (_, _) {});
        await container.read(agentWorkspaceRunsProvider('ws_1').future);
        final first = container
            .read(agentRunActionsProvider)
            .startOnTask(workspaceId: 'ws_1', taskId: 'task_1');
        await Future<void>.delayed(Duration.zero);
        if (boundary == 'repository') {
          container.read(_runtimeHolder.notifier).replace(_StartRepository());
        } else {
          (container.read(authSessionControllerProvider.notifier)
                  as _SessionController)
              .replace(_session('B'));
        }
        await Future<void>.delayed(Duration.zero);
        container.read(agentRunActionsProvider);
        if (boundary == 'repository') {
          container.read(_runtimeHolder.notifier).replace(repository);
        } else {
          (container.read(authSessionControllerProvider.notifier)
                  as _SessionController)
              .replace(_session('A'));
        }
        await Future<void>.delayed(Duration.zero);
        await container.read(agentWorkspaceRunsProvider('ws_1').future);
        final current = container
            .read(agentRunActionsProvider)
            .startOnTask(workspaceId: 'ws_1', taskId: 'task_1');
        await Future<void>.delayed(Duration.zero);
        expect(repository.requests.length, 2);
        repository.complete(1, 'current_run');
        await current;
        repository.complete(0, 'obsolete_run');
        await first;
        expect(
          container
              .read(agentWorkspaceRunsProvider('ws_1'))
              .value!
              .map((run) => run.id),
          ['current_run'],
        );
      },
    );
  }
}

Future<ProviderContainer> _container() async {
  final container = ProviderContainer(
    overrides: [
      agentRuntimeRepositoryProvider.overrideWith(
        (ref) => ref.watch(_runtimeHolder),
      ),
      authSessionControllerProvider.overrideWith(() => _SessionController()),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authSessionControllerProvider.future);
  return container;
}

final _runtimeHolder = NotifierProvider<_RuntimeHolder, _StartRepository>(
  _RuntimeHolder.new,
);

class _RuntimeHolder extends Notifier<_StartRepository> {
  @override
  _StartRepository build() => _StartRepository();
  void replace(_StartRepository repository) => state = repository;
}

class _SessionController extends AuthSessionController {
  @override
  Future<AuthSession?> build() async => _session('A');
  void replace(AuthSession session) => state = AsyncData(session);
}

AuthSession _session(String user) => AuthSession(
  userId: user,
  email: '$user@example.com',
  displayName: user,
  accessToken: 'fixture_access_$user',
  refreshToken: 'fixture_refresh_$user',
);

class _StartRepository extends RecordingRuntimeRepository {
  final requests =
      <
        ({
          String workspaceId,
          String taskId,
          String? agentKey,
          String? goal,
          Completer<AgentRunSummary> response,
        })
      >[];
  @override
  Future<AgentRunSummary> startTaskRun({
    required String workspaceId,
    required String taskId,
    String? agentKey,
    String? goal,
  }) {
    final response = Completer<AgentRunSummary>();
    requests.add((
      workspaceId: workspaceId,
      taskId: taskId,
      agentKey: agentKey,
      goal: goal,
      response: response,
    ));
    return response.future;
  }

  void complete(int index, String runId) {
    final request = requests[index];
    request.response.complete(
      testRun(
        id: runId,
        workspaceId: request.workspaceId,
        taskId: request.taskId,
      ),
    );
  }
}
