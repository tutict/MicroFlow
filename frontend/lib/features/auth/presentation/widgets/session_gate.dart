import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../bootstrap/presentation/pages/connect_server_page.dart';
import '../../../bootstrap/presentation/providers/server_connection_controller.dart';
import '../../../workspace/presentation/pages/workspace_home_page.dart';
import '../pages/sign_in_page.dart';
import '../providers/auth_session_controller.dart';

class SessionGate extends ConsumerWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final serverConnection = ref.watch(serverConnectionControllerProvider);
    final authSession = ref.watch(authSessionControllerProvider);

    if (serverConnection.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (serverConnection.hasError) {
      return Scaffold(
        body: Center(
          child: Text(
            l10n.restoreSessionError(serverConnection.error.toString()),
          ),
        ),
      );
    }
    if (serverConnection.valueOrNull == null) {
      return const ConnectServerPage();
    }

    return authSession.when(
      data: (session) =>
          session == null ? const SignInPage() : const WorkspaceHomePage(),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(child: Text(l10n.restoreSessionError(error.toString()))),
      ),
    );
  }
}
