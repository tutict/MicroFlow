import 'package:flutter/widgets.dart';

import 'app.dart';
import '../core/dev/dev_session_bypass.dart';

void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();
  _prepareDevAccess().whenComplete(() {
    runApp(const AppRoot());
  });
}

/// Runs the debug-only bypass before the first frame so both the connection and
/// session providers observe the seeded state.
Future<void> _prepareDevAccess() async {
  if (!DevSessionBypass.isEnabled) {
    return;
  }
  final report = await DevSessionBypass.ensureAccess();
  debugPrint(report.toString());
}
