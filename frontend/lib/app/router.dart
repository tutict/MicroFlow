import 'package:flutter/material.dart';

import '../features/agents/presentation/pages/agent_diagnostics_page.dart';
import '../features/bootstrap/presentation/pages/connect_server_page.dart';
import '../features/auth/presentation/widgets/session_gate.dart';
import '../features/auth/presentation/pages/sign_in_page.dart';

final class AppRoutes {
  static const connect = '/connect';
  static const signIn = '/sign-in';
  static const workspace = '/';
  static const agents = '/agents';
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
          builder: (_) => AgentDiagnosticsPage(workspaceId: workspaceId),
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
