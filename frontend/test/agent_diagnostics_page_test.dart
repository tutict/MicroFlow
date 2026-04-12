import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/core/providers/app_providers.dart';
import 'package:microflow_frontend/features/agents/domain/entities/agent_descriptor.dart';
import 'package:microflow_frontend/features/agents/domain/entities/agent_diagnostic.dart';
import 'package:microflow_frontend/features/agents/domain/entities/agent_run.dart';
import 'package:microflow_frontend/features/agents/domain/repositories/agent_repository.dart';
import 'package:microflow_frontend/features/agents/presentation/pages/agent_diagnostics_page.dart';

void main() {
  testWidgets('saving without applying keeps the default role strategy', (
    tester,
  ) async {
    final repository = _FakeAgentRepository(
      diagnostics: const [
        AgentDiagnostic(
          agentKey: 'assistant',
          provider: 'mock-openclaw',
          endpointUrl: 'local://mock-openclaw',
          enabled: true,
          credentialConfigured: false,
          roleStrategy: '',
          status: 'SIMULATED',
          detail: 'Using the built-in mock agent gateway',
          latencyMillis: 0,
          checkedAt: '2026-04-11T00:00:00Z',
        ),
      ],
    );

    await _pumpDiagnosticsPage(
      tester,
      repository: repository,
      locale: const Locale('en'),
    );

    await tester.tap(find.text('Edit role strategy'));
    await tester.pumpAndSettle();

    expect(find.text('Recommended template'), findsOneWidget);
    expect(
      find.text('@assistant is best matched with the Synthesizer template.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.lastUpdatedRoleStrategy, '');
  });

  testWidgets('applies the recommended role strategy and saves it', (
    tester,
  ) async {
    final repository = _FakeAgentRepository(
      diagnostics: const [
        AgentDiagnostic(
          agentKey: 'assistant',
          provider: 'mock-openclaw',
          endpointUrl: 'local://mock-openclaw',
          enabled: true,
          credentialConfigured: false,
          roleStrategy: '',
          status: 'SIMULATED',
          detail: 'Using the built-in mock agent gateway',
          latencyMillis: 0,
          checkedAt: '2026-04-11T00:00:00Z',
        ),
      ],
    );

    await _pumpDiagnosticsPage(
      tester,
      repository: repository,
      locale: const Locale('en'),
    );

    await tester.tap(find.text('Edit role strategy'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply recommended'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      repository.lastUpdatedRoleStrategy,
      'You are the synthesizer. Reconcile the thread, surface consensus, and keep the team response concise.',
    );
  });

  testWidgets('shows the reviewer recommendation for reviewer agents', (
    tester,
  ) async {
    final repository = _FakeAgentRepository(
      diagnostics: const [
        AgentDiagnostic(
          agentKey: 'reviewer',
          provider: 'mock-openclaw',
          endpointUrl: 'local://mock-openclaw',
          enabled: true,
          credentialConfigured: false,
          roleStrategy: '',
          status: 'SIMULATED',
          detail: 'Using the built-in mock agent gateway',
          latencyMillis: 0,
          checkedAt: '2026-04-11T00:00:00Z',
        ),
      ],
    );

    await _pumpDiagnosticsPage(
      tester,
      repository: repository,
      locale: const Locale('en'),
    );

    await tester.tap(find.text('Edit role strategy'));
    await tester.pumpAndSettle();

    expect(
      find.text('@reviewer is best matched with the Reviewer template.'),
      findsOneWidget,
    );
    expect(find.text('Apply recommended'), findsOneWidget);
  });

  testWidgets('renders Chinese diagnostics copy for zh locale', (tester) async {
    final repository = _FakeAgentRepository(
      diagnostics: const [
        AgentDiagnostic(
          agentKey: 'assistant',
          provider: 'mock-openclaw',
          endpointUrl: 'local://mock-openclaw',
          enabled: true,
          credentialConfigured: false,
          roleStrategy: '',
          status: 'SIMULATED',
          detail: 'Using the built-in mock agent gateway',
          latencyMillis: 0,
          checkedAt: '2026-04-11T00:00:00Z',
        ),
      ],
    );

    await _pumpDiagnosticsPage(
      tester,
      repository: repository,
      locale: const Locale('zh'),
    );

    expect(find.text('Agent 诊断'), findsWidgets);
    expect(find.textContaining('工作区'), findsWidgets);

    await tester.tap(find.text('编辑角色策略'));
    await tester.pumpAndSettle();

    expect(find.text('推荐模板'), findsOneWidget);
    expect(find.text('应用推荐'), findsOneWidget);
  });
}

Future<void> _pumpDiagnosticsPage(
  WidgetTester tester, {
  required _FakeAgentRepository repository,
  required Locale locale,
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [agentRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const AgentDiagnosticsPage(workspaceId: 'ws_1'),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

class _FakeAgentRepository implements AgentRepository {
  _FakeAgentRepository({required this.diagnostics});

  final List<AgentDiagnostic> diagnostics;
  String? lastUpdatedWorkspaceId;
  String? lastUpdatedAgentKey;
  String? lastUpdatedRoleStrategy;

  @override
  Future<List<AgentDescriptor>> listAgents(String workspaceId) async =>
      const [];

  @override
  Future<List<AgentDiagnostic>> listDiagnostics(String workspaceId) async =>
      diagnostics;

  @override
  Future<List<AgentRun>> listRuns(String workspaceId) async => const [];

  @override
  Future<void> updateRoleStrategy({
    required String workspaceId,
    required String agentKey,
    required String roleStrategy,
  }) async {
    lastUpdatedWorkspaceId = workspaceId;
    lastUpdatedAgentKey = agentKey;
    lastUpdatedRoleStrategy = roleStrategy;
  }
}
