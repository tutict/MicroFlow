import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/core/providers/locale_controller.dart';
import 'package:microflow_frontend/core/providers/app_providers.dart';
import 'package:microflow_frontend/features/bootstrap/domain/entities/server_connection.dart';
import 'package:microflow_frontend/features/bootstrap/domain/repositories/server_connection_repository.dart';
import 'package:microflow_frontend/features/bootstrap/presentation/pages/connect_server_page.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

void main() {
  testWidgets('renders device-first connect page', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverConnectionRepositoryProvider.overrideWithValue(
            _FakeServerConnectionRepository(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: supportedAppLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const ConnectServerPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ConnectServerPage), findsOneWidget);
    expect(find.text('My devices'), findsOneWidget);
    expect(find.text('Add device manually'), findsOneWidget);
    expect(find.text('Save and continue'), findsOneWidget);
  });
}

class _FakeServerConnectionRepository implements ServerConnectionRepository {
  @override
  Future<ServerConnection?> currentConnection() async => null;

  @override
  Future<List<ServerConnection>> listConnections() async => const [];

  @override
  Future<ServerConnection> pair({
    required String serverUrl,
    required String pairingCode,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ServerConnection?> activateConnection(String connectionId) async =>
      null;

  @override
  Future<void> clearCurrentConnection() async {}

  @override
  Future<void> removeConnection(String connectionId) async {}
}
