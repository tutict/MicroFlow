import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/shared/layout/window_class.dart';

void main() {
  test('window class boundaries follow the shell widths', () {
    AppWindowClass at(double width, [double scale = 1]) {
      return AppWindowClassResolver.resolve(width: width, textScale: scale);
    }

    expect(at(599), AppWindowClass.compact);
    expect(at(600), AppWindowClass.medium);
    expect(at(1023), AppWindowClass.medium);
    expect(at(1024), AppWindowClass.expanded);
    expect(at(1439), AppWindowClass.expanded);
    expect(at(1440), AppWindowClass.large);
    expect(at(1440, 1.3), AppWindowClass.large);
    expect(at(1440, 1.4), AppWindowClass.medium);
    expect(at(1100, 1.4), AppWindowClass.medium);
    expect(AppWindowClassResolver.indexWidth(AppWindowClass.medium), 280);
    expect(AppWindowClassResolver.indexWidth(AppWindowClass.expanded), 300);
    expect(AppWindowClassResolver.indexWidth(AppWindowClass.large), 320);
  });
}
