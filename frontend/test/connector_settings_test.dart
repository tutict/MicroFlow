import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/app/theme/app_theme.dart';
import 'package:microflow_frontend/features/connectors/domain/entities/agent_connector.dart';
import 'package:microflow_frontend/features/connectors/domain/repositories/connector_repository.dart';
import 'package:microflow_frontend/features/connectors/presentation/pages/connector_settings_page.dart';
import 'package:microflow_frontend/features/connectors/presentation/providers/connector_providers.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';
import 'package:microflow_frontend/l10n/app_localization_delegates.dart';

void main() {
  for (final entry in [
    (field: 'username', value: 'new@example.com'),
    (field: 'password', value: '  replacement password  '),
  ]) {
    testWidgets(
      'editing only ${entry.field} emits its independent secret patch',
      (tester) async {
        final repository = _FakeConnectorRepository(connectors: [_connector()]);
        await _pump(tester, repository);
        await tester.tap(find.byKey(const Key('connector-edit-con_1')));
        await tester.pumpAndSettle();
        for (final field in ['username', 'password']) {
          final input = tester.widget<TextField>(
            find.byKey(Key('connector-form-$field')),
          );
          expect(
            input.controller!.text,
            isEmpty,
            reason: 'stored credentials are write-only',
          );
        }
        await tester.enterText(
          find.byKey(Key('connector-form-${entry.field}')),
          entry.value,
        );
        await tester.ensureVisible(
          find.byKey(const Key('connector-form-save')),
        );
        await tester.tap(find.byKey(const Key('connector-form-save')));
        await tester.pumpAndSettle();
        expect(repository.updated.single.secrets, {entry.field: entry.value});
        expect(repository.updated.single.config, {
          'host': 'imap.example.com',
          'port': 993,
          'tls': false,
          'mailbox': 'Archive',
          'fromAddress': 'sender@example.com',
        });
      },
    );
  }

  testWidgets(
    'renaming preserves unexposed config and omits untouched secrets',
    (tester) async {
      final repository = _FakeConnectorRepository(connectors: [_connector()]);
      await _pump(tester, repository);
      await tester.tap(find.byKey(const Key('connector-edit-con_1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('connector-form-name')),
        'Renamed',
      );
      await tester.ensureVisible(find.byKey(const Key('connector-form-save')));
      await tester.tap(find.byKey(const Key('connector-form-save')));
      await tester.pumpAndSettle();
      expect(repository.updated.single.name, 'Renamed');
      expect(repository.updated.single.secrets, isNull);
      expect(repository.updated.single.config['mailbox'], 'Archive');
      expect(repository.updated.single.config['tls'], false);
    },
  );

  testWidgets('an empty workspace invites the first connector', (tester) async {
    final repository = _FakeConnectorRepository(connectors: const []);
    await _pump(tester, repository);

    expect(find.text('No connectors yet'), findsOneWidget);
    expect(find.byKey(const Key('connector-empty-add')), findsOneWidget);
    expect(find.byKey(const Key('connector-add')), findsOneWidget);
  });

  testWidgets('a connector row states direction, sharing and stored secrets', (
    tester,
  ) async {
    final repository = _FakeConnectorRepository(connectors: [_connector()]);
    await _pump(tester, repository);

    expect(find.byKey(const Key('connector-tile-con_1')), findsOneWidget);
    expect(find.text('Team mailbox'), findsOneWidget);
    expect(find.textContaining('imap.example.com:993'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    // No password value is ever rendered, only the fact that one is stored.
    expect(find.textContaining('password'), findsOneWidget);
    expect(find.text('Not tested'), findsOneWidget);
  });

  testWidgets('testing a connector reports the probe result', (tester) async {
    final repository = _FakeConnectorRepository(
      connectors: [_connector()],
      check: const ConnectorCheck(
        connectorId: 'con_1',
        status: ConnectorStatus.active,
        detail: 'IMAP greeting received on port 993',
      ),
    );
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('connector-test-con_1')));
    await tester.pumpAndSettle();

    expect(repository.tested, ['con_1']);
    expect(find.text('IMAP greeting received on port 993'), findsOneWidget);
  });

  testWidgets('deleting asks for confirmation before removing anything', (
    tester,
  ) async {
    final repository = _FakeConnectorRepository(connectors: [_connector()]);
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('connector-delete-con_1')));
    await tester.pumpAndSettle();
    expect(repository.deleted, isEmpty);
    expect(find.textContaining('Delete Team mailbox?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('connector-delete-confirm')));
    await tester.pumpAndSettle();
    expect(repository.deleted, ['con_1']);
  });

  testWidgets('a connector shared with me offers no edit or delete', (
    tester,
  ) async {
    final repository = _FakeConnectorRepository(
      connectors: [
        _connector(
          ownedByMe: false,
          sharingScope: ConnectorSharingScope.workspace,
        ),
      ],
    );
    await _pump(tester, repository);

    expect(find.byKey(const Key('connector-tile-con_1')), findsOneWidget);
    expect(find.byKey(const Key('connector-edit-con_1')), findsNothing);
    expect(find.byKey(const Key('connector-delete-con_1')), findsNothing);
    expect(find.text('Shared with you'), findsOneWidget);
    expect(find.text('Whole workspace'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, ConnectorRepository repository) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [connectorRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Scaffold(body: ConnectorSettingsPage(workspaceId: 'ws_1')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AgentConnector _connector({
  bool ownedByMe = true,
  ConnectorSharingScope sharingScope = ConnectorSharingScope.ownerOnly,
}) {
  return AgentConnector(
    id: 'con_1',
    workspaceId: 'ws_1',
    ownerUserId: 'user_1',
    ownedByMe: ownedByMe,
    kind: ConnectorKind.imap,
    name: 'Team mailbox',
    config: const {
      'host': 'imap.example.com',
      'port': 993,
      'tls': false,
      'mailbox': 'Archive',
      'fromAddress': 'sender@example.com',
    },
    secretFields: const ['password', 'username'],
    sharingScope: sharingScope,
    sharedUserIds: const [],
    sharedAgentKeys: const [],
    status: ConnectorStatus.unverified,
    readEnabled: true,
    writeEnabled: false,
  );
}

class _FakeConnectorRepository implements ConnectorRepository {
  _FakeConnectorRepository({required this.connectors, this.check});

  final List<AgentConnector> connectors;
  final ConnectorCheck? check;
  final List<String> tested = [];
  final List<String> deleted = [];
  final List<ConnectorDraft> updated = [];

  @override
  Future<List<AgentConnector>> list(String workspaceId) async => connectors;

  @override
  Future<AgentConnector> create(
    String workspaceId,
    ConnectorDraft draft,
  ) async => connectors.first;

  @override
  Future<AgentConnector> update(
    String workspaceId,
    String connectorId,
    ConnectorDraft draft,
  ) async {
    updated.add(draft);
    return connectors.first;
  }

  @override
  Future<void> delete(String workspaceId, String connectorId) async {
    deleted.add(connectorId);
  }

  @override
  Future<ConnectorCheck> test(String workspaceId, String connectorId) async {
    tested.add(connectorId);
    return check ??
        ConnectorCheck(
          connectorId: connectorId,
          status: ConnectorStatus.active,
        );
  }
}
