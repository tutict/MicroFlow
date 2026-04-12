import 'package:flutter_test/flutter_test.dart';
import 'package:microflow_frontend/app/app.dart';
import 'package:microflow_frontend/features/bootstrap/presentation/pages/connect_server_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders connect server page before sign in', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AppRoot());
    await tester.pumpAndSettle();

    expect(find.byType(ConnectServerPage), findsOneWidget);
    expect(find.textContaining('localhost:8080'), findsWidgets);
  });
}
