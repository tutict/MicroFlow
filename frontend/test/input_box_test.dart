import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/features/chat/presentation/widgets/input_box.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

void main() {
  testWidgets('keeps the draft when send fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: InputBox(onSend: _failingSend)),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Draft message');
    await tester.tap(find.text('Send'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Draft message'), findsOneWidget);
    expect(find.textContaining('send failed'), findsOneWidget);
  });

  testWidgets('shows collaboration toggle when enabled for the composer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: InputBox(
            collaborationModeVisible: true,
            collaborationModeEnabled: true,
            collaborationStatusText: 'Team run active',
            onCollaborationModeChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Team mode'), findsOneWidget);
    expect(find.text('Team run active'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });
}

Future<void> _failingSend(String value) async {
  throw StateError('send failed');
}
