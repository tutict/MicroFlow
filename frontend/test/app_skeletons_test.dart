import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/app/theme/app_theme.dart';
import 'package:microflow_frontend/shared/widgets/app_skeletons.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  for (final appBrightness in Brightness.values) {
    testWidgets('loading shimmer follows the $appBrightness app theme', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue =
          appBrightness == Brightness.dark ? Brightness.light : Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(
        MaterialApp(
          theme: appBrightness == Brightness.dark
              ? AppTheme.dark()
              : AppTheme.light(),
          home: const Scaffold(body: AppPageSkeleton()),
        ),
      );
      await tester.pump();

      final scope = tester.widget<SkeletonizerScope>(
        find.byType(SkeletonizerScope),
      );
      final expected = appBrightness == Brightness.dark
          ? const ShimmerEffect.dark()
          : const ShimmerEffect();
      expect((scope.config.effect as ShimmerEffect).colors, expected.colors);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
