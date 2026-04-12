import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../core/providers/locale_controller.dart';
import '../core/providers/theme_mode_controller.dart';
import '../features/auth/presentation/widgets/session_gate.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: MicroFlowApp(),
    );
  }
}

class MicroFlowApp extends ConsumerWidget {
  const MicroFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider).valueOrNull ?? const Locale('zh');
    final themeMode = ref.watch(themeModeControllerProvider).valueOrNull ?? ThemeMode.light;

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SessionGate(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
