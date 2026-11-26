import 'package:flutter/material.dart' as legacy;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:microflow_frontend/app/material_compatibility.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';
import 'package:microflow_frontend/l10n/app_localization_delegates.dart';

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets('legacy plugin widgets inherit the $language app theme', (
      tester,
    ) async {
      const primary = Color(0xFF366FF5);
      var pressed = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: buildAppMaterialCompatibility,
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: primary)
                .copyWith(primary: primary),
          ),
          home: legacy.Builder(
            key: const Key('legacy-plugin-context'),
            builder: (context) => legacy.TextButton(
              onPressed: () => pressed++,
              child: legacy.Text(
                legacy.MaterialLocalizations.of(context).okButtonLabel,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(
        find.byKey(const Key('legacy-plugin-context')),
      );
      expect(legacy.Theme.of(context).colorScheme.primary, primary);
      await tester.tap(find.text(language == 'zh' ? '确定' : 'OK'));
      await tester.pumpAndSettle();
      expect(pressed, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
