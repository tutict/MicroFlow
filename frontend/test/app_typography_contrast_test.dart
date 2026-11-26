import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/app/theme/app_theme.dart';
import 'package:microflow_frontend/shared/theme/app_contrast.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      '$brightness headings and body text stay readable on the canvas',
      (tester) async {
        final theme = brightness == Brightness.light
            ? AppTheme.light()
            : AppTheme.dark();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Column(
                children: [
                  Text(
                    'Task title',
                    key: const Key('heading'),
                    style: theme.textTheme.titleLarge,
                  ),
                  Text(
                    'Task description',
                    key: const Key('body'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        );
        for (final key in ['heading', 'body']) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.byKey(Key(key)),
          );
          // TextStyle's paragraph paint defaults to white when no foreground is supplied.
          final style = paragraph.text.style!;
          final color =
              style.foreground?.color ?? style.color ?? const Color(0xFFFFFFFF);
          expect(
            contrastRatio(color, theme.scaffoldBackgroundColor),
            greaterThanOrEqualTo(4.5),
            reason:
                'rendered $key text must use the surface foreground, including inherited styles',
          );
        }
      },
    );
  }
}
