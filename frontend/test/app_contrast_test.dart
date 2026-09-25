import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/shared/theme/app_colors.dart';
import 'package:microflow_frontend/shared/theme/app_contrast.dart';

void main() {
  test('light and dark tokens meet contrast thresholds', () {
    final failures = <String>[];
    for (final palette in [AppPalette.light, AppPalette.dark]) {
      for (final pair in palette.contrastPairs) {
        final ratio = contrastRatio(pair.foreground, pair.background);
        if (ratio < pair.minimum) {
          failures.add(
            '${pair.name}: ${ratio.toStringAsFixed(2)} < ${pair.minimum} '
            'fg=${pair.foreground} bg=${pair.background}',
          );
        }
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
