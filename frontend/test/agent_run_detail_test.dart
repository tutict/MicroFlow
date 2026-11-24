import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/app/theme/app_theme.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_approval.dart';
import 'package:microflow_frontend/features/agent_runtime/domain/entities/agent_run.dart';
import 'package:microflow_frontend/features/agent_runtime/presentation/providers/agent_runtime_providers.dart';
import 'package:microflow_frontend/features/agent_runtime/presentation/widgets/agent_run_card.dart';
import 'package:microflow_frontend/features/agent_runtime/presentation/widgets/agent_run_detail_sheet.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import 'support/recording_runtime_repository.dart';

void main() {
  testWidgets('cancelled execution steps are not presented as still running', (
    tester,
  ) async {
    final repository = RecordingRuntimeRepository(
      runs: [testRun(status: AgentRunStatus.cancelled)],
    );
    repository.stepRecords.add({
      'id': 'step_cancelled',
      'seq': 1,
      'kind': 'APPROVAL',
      'status': 'CANCELLED',
      'title': 'Review task update',
    });
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _host(
        repository,
        AgentRunDetailSheet(runId: 'run_1', scrollController: scroll),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Running'), findsNothing);
    expect(find.text('Cancelled'), findsAtLeastNWidgets(1));
  });

  testWidgets('run detail exposes agent steps and the approval action', (
    tester,
  ) async {
    final repository = RecordingRuntimeRepository(
      runs: [testRun(status: AgentRunStatus.waitingApproval)],
    );
    repository.approvals.add(
      const AgentApproval(
        id: 'apr_run_1',
        runId: 'run_1',
        toolKey: 'task.update_status',
        action: 'Update task',
        riskLevel: 'INTERNAL_WRITE',
        status: AgentApprovalStatus.pending,
        targetResource: 'task:task_1',
        impactSummary: 'Move task to done.',
      ),
    );
    repository.stepRecords.add({
      'id': 'step_1',
      'seq': 1,
      'kind': 'MODEL_TURN',
      'status': 'COMPLETED',
      'agentKey': 'assistant',
      'title': 'Agent: @assistant',
      'detail': 'Checked the task.',
    });
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _host(
        repository,
        AgentRunDetailSheet(runId: 'run_1', scrollController: scroll),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Checked the task.'),
      160,
      scrollable: find
          .descendant(
            of: find.byType(AgentRunDetailSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Checked the task.'), findsOneWidget);
    expect(
      find.byKey(const Key('agent-run-detail-run_1')),
      findsNothing,
      reason: 'the detail must not recursively open itself',
    );
  });

  testWidgets('step fetch failures offer a retry that restores the steps', (
    tester,
  ) async {
    final repository = RecordingRuntimeRepository(
      runs: [testRun(status: AgentRunStatus.succeeded)],
    )..failSteps = true;
    repository.stepRecords.add({
      'id': 'step_1',
      'seq': 1,
      'kind': 'MODEL_TURN',
      'status': 'COMPLETED',
      'agentKey': 'assistant',
      'title': 'Agent: @assistant',
      'detail': 'Recovered step.',
    });
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _host(
        repository,
        AgentRunDetailSheet(runId: 'run_1', scrollController: scroll),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('agent-run-steps-retry')), findsOneWidget);
    repository.failSteps = false;
    await tester.ensureVisible(find.byKey(const Key('agent-run-steps-retry')));
    await tester.tap(find.byKey(const Key('agent-run-steps-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Recovered step.'), findsOneWidget);
  });

  testWidgets(
    'run control failures are shown in the card with a usable retry',
    (tester) async {
      final repository = RecordingRuntimeRepository(
        runs: [testRun(status: AgentRunStatus.running)],
      )..controlError = StateError('The run could not be cancelled');
      await tester.pumpWidget(
        _host(
          repository,
          SingleChildScrollView(
            child: AgentRunCard(run: repository.runs.single),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('agent-run-cancel-run_1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be cancelled'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _host(RecordingRuntimeRepository repository, Widget child) =>
    ProviderScope(
      overrides: [agentRuntimeRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: child),
      ),
    );
