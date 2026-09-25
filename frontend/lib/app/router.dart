import 'package:flutter/material.dart';

import '../features/bootstrap/presentation/pages/connect_server_page.dart';
import '../features/auth/presentation/pages/sign_in_page.dart';
import '../features/auth/presentation/widgets/session_gate.dart';
import '../features/workspace/presentation/shell/shell_destination.dart';

final class AppRoutes {
  static const connect = '/connect';
  static const signIn = '/sign-in';
  static const workspace = '/';
  static const agents = '/agents';
  static const accounting = '/accounting';
}

final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.connect:
        return MaterialPageRoute<void>(
          builder: (_) => const ConnectServerPage(),
          settings: settings,
        );
      case AppRoutes.signIn:
        return MaterialPageRoute<void>(
          builder: (_) => const SignInPage(),
          settings: settings,
        );
      case AppRoutes.agents:
        final workspaceId = settings.arguments as String? ?? '';
        return MaterialPageRoute<void>(
          builder: (_) => SessionGate(
            initialDestination: ShellDestination.diagnostics,
            initialWorkspaceId: workspaceId,
          ),
          settings: settings,
        );
      case AppRoutes.accounting:
        final workspaceId = settings.arguments as String? ?? '';
        return MaterialPageRoute<void>(
          builder: (_) => SessionGate(
            initialDestination: ShellDestination.accounting,
            initialWorkspaceId: workspaceId,
          ),
          settings: settings,
        );
      case AppRoutes.workspace:
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const SessionGate(),
          settings: settings,
        );
    }
  }
}
