import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';
import 'package:microflow_frontend/l10n/app_localization_delegates.dart';

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets('standalone UI libraries load $language app localizations', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: Builder(
            builder: (context) => Column(
              children: [
                Text(MaterialLocalizations.of(context).okButtonLabel),
                Text(CupertinoLocalizations.of(context).copyButtonLabel),
                Text(AppLocalizations.of(context)!.appTitle),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(language == 'zh' ? '确定' : 'OK'), findsOneWidget);
      expect(find.text(language == 'zh' ? '复制' : 'Copy'), findsOneWidget);
      expect(find.text(language == 'zh' ? '微澜协作' : 'Weilan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
