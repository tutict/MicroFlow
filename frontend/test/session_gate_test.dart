import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/core/providers/app_providers.dart';
import 'package:microflow_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:microflow_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:microflow_frontend/features/auth/presentation/widgets/session_gate.dart';
import 'package:microflow_frontend/features/bootstrap/domain/entities/server_connection.dart';
import 'package:microflow_frontend/features/bootstrap/domain/repositories/server_connection_repository.dart';
import 'package:microflow_frontend/features/bootstrap/presentation/pages/connect_server_page.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';
import 'package:microflow_frontend/l10n/app_localization_delegates.dart';

void main() {
  testWidgets('pairing keeps the form mounted and shows failures for retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _PendingConnectionRepository();
    addTearDown(() {
      if (!repository.result.isCompleted) {
        repository.result.completeError(StateError('test disposed'));
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverConnectionRepositoryProvider.overrideWithValue(repository),
          authRepositoryProvider.overrideWithValue(_SignedOutRepository()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: const SessionGate(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'http://127.0.0.1:18080',
    );
    await tester.enterText(find.byType(TextField).at(1), 'ABCD-1234');
    await tester.tap(find.text('Save and continue'));
    await tester.pump();

    expect(find.byType(ConnectServerPage), findsOneWidget);
    expect(find.text('Connecting...'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).enabled,
      isFalse,
    );

    repository.result.completeError(StateError('pairing failed'));
    await tester.pumpAndSettle();

    expect(find.textContaining('pairing failed'), findsOneWidget);
    expect(find.text('Save and continue'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
      'http://127.0.0.1:18080',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller?.text,
      'ABCD-1234',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).enabled,
      isTrue,
    );
  }, variant: const TargetPlatformVariant({TargetPlatform.linux}));

  testWidgets('rapid pairing submissions wait for one sign-out and request', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final signOut = Completer<void>();
    final repository = _PendingConnectionRepository();
    addTearDown(() {
      if (!signOut.isCompleted) signOut.complete();
      if (!repository.result.isCompleted) {
        repository.result.completeError(StateError('test disposed'));
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverConnectionRepositoryProvider.overrideWithValue(repository),
          authRepositoryProvider.overrideWithValue(
            _SignedOutRepository(signOutResult: signOut.future),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: const SessionGate(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'http://127.0.0.1:18080',
    );
    await tester.enterText(find.byType(TextField).at(1), 'ABCD-1234');
    final submit = find.text('Save and continue');
    await tester.tap(submit);
    await tester.tap(submit);
    signOut.complete();
    await tester.pump();

    expect(repository.pairRequests, 1);
    expect(find.text('Connecting...'), findsOneWidget);
    repository.result.completeError(StateError('pairing failed'));
    await tester.pumpAndSettle();

    expect(find.text('Save and continue'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).enabled,
      isTrue,
    );
    expect(find.textContaining('pairing failed'), findsOneWidget);
  }, variant: const TargetPlatformVariant({TargetPlatform.linux}));
}

class _PendingConnectionRepository implements ServerConnectionRepository {
  final result = Completer<ServerConnection>();
  int pairRequests = 0;

  @override
  Future<ServerConnection?> currentConnection() async => null;

  @override
  Future<List<ServerConnection>> listConnections() async => const [];

  @override
  Future<ServerConnection> pair({
    required String serverUrl,
    required String pairingCode,
  }) {
    pairRequests++;
    return result.future;
  }

  @override
  Future<ServerConnection?> activateConnection(String connectionId) async =>
      null;

  @override
  Future<void> clearCurrentConnection() async {}

  @override
  Future<void> removeConnection(String connectionId) async {}
}

class _SignedOutRepository implements AuthRepository {
  _SignedOutRepository({this.signOutResult});

  final Future<void>? signOutResult;

  @override
  Future<AuthSession?> currentSession() async => null;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<void> signOut() async {
    await signOutResult;
  }
}
