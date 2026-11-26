import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/features/chat/presentation/widgets/input_box.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';
import 'package:microflow_frontend/l10n/app_localization_delegates.dart';

void main() {
  testWidgets('blank drafts cannot be sent', (tester) async {
    await _pumpComposer(tester, onSend: (_) async {});
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '  \n ');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'Ready');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('keyboard sends once while the request is pending', (
    tester,
  ) async {
    final pending = Completer<void>();
    final sent = <String>[];
    await _pumpComposer(
      tester,
      onSend: (value) {
        sent.add(value);
        return pending.future;
      },
    );
    await tester.enterText(find.byType(TextField), 'First line\nSecond line');
    await _sendShortcut(tester);
    await _sendShortcut(tester);
    expect(sent, ['First line\nSecond line']);
    expect(find.text('First line\nSecond line'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('a composing IME value is not sent by the keyboard shortcut', (
    tester,
  ) async {
    final sent = <String>[];
    await _pumpComposer(tester, onSend: (value) async => sent.add(value));
    await tester.showKeyboard(find.byType(TextField));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'zhong',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5),
      ),
    );
    await tester.pump();
    await _sendShortcut(tester);
    expect(sent, isEmpty);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '中文',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pump();
    await _sendShortcut(tester);
    await tester.pumpAndSettle();
    expect(sent, ['中文']);
  });

  testWidgets('mobile collaboration controls leave a usable full-width input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpComposer(
      tester,
      onSend: (_) async {},
      compact: true,
      collaboration: true,
    );
    expect(tester.getSize(find.byType(TextField)).width, greaterThan(260));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mentions are reachable on demand and preserve the draft', (
    tester,
  ) async {
    await _pumpComposer(tester, onSend: (_) async {}, mentions: ['@assistant']);
    await tester.enterText(find.byType(TextField), 'Please review');
    expect(find.text('@assistant'), findsNothing);
    await tester.tap(find.byKey(const Key('composer-mention')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('@assistant'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Please review @assistant ',
    );
  });

  testWidgets('keeps the draft when send fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Scaffold(body: InputBox(onSend: _failingSend)),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Draft message');
    await tester.pump();
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
        localizationsDelegates: appLocalizationsDelegates,
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

Future<void> _pumpComposer(
  WidgetTester tester, {
  required Future<void> Function(String) onSend,
  bool compact = false,
  bool collaboration = false,
  List<String> mentions = const [],
}) => tester.pumpWidget(
  MaterialApp(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: Scaffold(
      body: InputBox(
        onSend: onSend,
        compact: compact,
        collaborationModeVisible: collaboration,
        onCollaborationModeChanged: (_) {},
        suggestedMentions: mentions,
      ),
    ),
  ),
);

Future<void> _sendShortcut(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

Future<void> _failingSend(String value) async {
  throw StateError('send failed');
}
