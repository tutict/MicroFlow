import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../core/providers/locale_controller.dart';
import '../core/providers/theme_mode_controller.dart';
import '../features/auth/presentation/widgets/session_gate.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: MicroFlowApp());
  }
}

class MicroFlowApp extends ConsumerWidget {
  const MicroFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale =
        ref.watch(localeControllerProvider).value ?? const Locale('zh');
    final themeMode =
        ref.watch(themeModeControllerProvider).value ?? ThemeMode.light;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(dynamicScheme: lightDynamic),
          darkTheme: AppTheme.dark(dynamicScheme: darkDynamic),
          themeMode: themeMode,
          locale: locale,
          supportedLocales: supportedAppLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => ResponsiveBreakpoints.builder(
            child: child ?? const SizedBox.shrink(),
            breakpoints: const [
              Breakpoint(start: 0, end: 599, name: MOBILE),
              Breakpoint(start: 600, end: 899, name: TABLET),
              Breakpoint(start: 900, end: 1279, name: DESKTOP),
              Breakpoint(start: 1280, end: double.infinity, name: 'XL'),
            ],
          ),
          home: const SessionGate(),
          onGenerateRoute: AppRouter.onGenerateRoute,
        );
      },
    );
  }
}
