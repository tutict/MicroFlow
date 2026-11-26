import 'package:material_ui/material_ui.dart';
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
import 'package:microflow_frontend/features/agent_runtime/presentation/widgets/agent_run_card.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';
import 'package:microflow_frontend/l10n/app_localization_delegates.dart';

void main() {
  testWidgets('approval card states the impact and records a decision', (
    tester,
  ) async {
    final repository = _FakeRuntimeRepository(
      runs: [_run(status: AgentRunStatus.waitingApproval)],
      approvals: [_approval()],
    );

    await _pumpCard(
      tester,
      repository,
      _run(status: AgentRunStatus.waitingApproval),
    );

    expect(find.text('Waiting approval'), findsOneWidget);
    expect(find.text('Approval required'), findsOneWidget);
    expect(
      find.textContaining(
        'Move task "Ship the harness" from OPEN to DONE',
        findRichText: true,
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('agent-approval-note')),
      'Approved for the release',
    );
    await tester.tap(find.byKey(const Key('agent-approval-approve')));
    await tester.pumpAndSettle();

    expect(repository.decisions, hasLength(1));
    expect(repository.decisions.single.approve, isTrue);
    expect(repository.decisions.single.note, 'Approved for the release');
  });

  testWidgets('rejecting an approval sends a rejection with no side effect', (
    tester,
  ) async {
    final repository = _FakeRuntimeRepository(
      runs: [_run(status: AgentRunStatus.waitingApproval)],
      approvals: [_approval()],
    );

    await _pumpCard(
      tester,
      repository,
      _run(status: AgentRunStatus.waitingApproval),
    );
    await tester.tap(find.byKey(const Key('agent-approval-reject')));
    await tester.pumpAndSettle();

    expect(repository.decisions, hasLength(1));
    expect(repository.decisions.single.approve, isFalse);
  });

  testWidgets('a running run offers cancel', (tester) async {
    final repository = _FakeRuntimeRepository(
      runs: [_run(status: AgentRunStatus.running)],
    );

    await _pumpCard(tester, repository, _run(status: AgentRunStatus.running));
    expect(find.text('Running'), findsOneWidget);

    await tester.tap(find.byKey(const Key('agent-run-cancel-run_1')));
    await tester.pumpAndSettle();

    expect(repository.cancelled, ['run_1']);
  });

  testWidgets('an interrupted run shows the error and offers retry', (
    tester,
  ) async {
    final repository = _FakeRuntimeRepository(
      runs: [
        _run(
          status: AgentRunStatus.failed,
          error: 'Run interrupted by a process restart',
          interruptionState: 'INTERRUPTED',
        ),
      ],
    );

    await _pumpCard(
      tester,
      repository,
      _run(
        status: AgentRunStatus.failed,
        error: 'Run interrupted by a process restart',
        interruptionState: 'INTERRUPTED',
      ),
    );

    expect(
      find.textContaining('Run interrupted by a process restart'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('agent-run-retry-run_1')));
    await tester.pumpAndSettle();

    expect(repository.retried, ['run_1']);
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  AgentRuntimeRepository repository,
  AgentRunSummary run,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [agentRuntimeRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(child: AgentRunCard(run: run)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AgentRunSummary _run({
  required AgentRunStatus status,
  String? error,
  String? interruptionState,
}) {
  return AgentRunSummary(
    id: 'run_1',
    workspaceId: 'ws_1',
    taskId: 'task_1',
    agentKey: 'assistant',
    kind: 'TASK',
    status: status,
    goal: 'Close the release checklist',
    contextSummary: 'Context: 1 task, 2 decisions',
    errorMessage: error,
    interruptionState: interruptionState,
    pendingApprovalId: status == AgentRunStatus.waitingApproval
        ? 'apr_1'
        : null,
    stepCount: 3,
  );
}

AgentApproval _approval() {
  return const AgentApproval(
    id: 'apr_1',
    runId: 'run_1',
    toolKey: 'task.update_status',
    action: 'Update task status',
    riskLevel: 'INTERNAL_WRITE',
    status: AgentApprovalStatus.pending,
    targetResource: 'task:task_1',
    impactSummary: 'Move task "Ship the harness" from OPEN to DONE.',
  );
}

class _FakeRuntimeRepository implements AgentRuntimeRepository {
  _FakeRuntimeRepository({required this.runs, this.approvals = const []});

  final List<AgentRunSummary> runs;
  final List<AgentApproval> approvals;
  final List<({bool approve, String? note})> decisions = [];
  final List<String> cancelled = [];
  final List<String> retried = [];

  @override
  Future<List<AgentRunSummary>> listRuns({
    required String workspaceId,
    String? taskId,
  }) async => runs;

  @override
  Future<AgentRunSummary> getRun(String runId) async =>
      runs.firstWhere((run) => run.id == runId);

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
  }) async => approvals;

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
  }) async => runs.first;

  @override
  Future<AgentApproval> decideApproval({
    required String runId,
    required String approvalId,
    required bool approve,
    String? note,
  }) async {
    decisions.add((approve: approve, note: note));
    return approvals.first;
  }

  @override
  Future<AgentRunSummary> cancelRun(String runId) async {
    cancelled.add(runId);
    return runs.first;
  }

  @override
  Future<AgentRunSummary> retryRun(String runId) async {
    retried.add(runId);
    return runs.first;
  }
}
