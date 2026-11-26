import 'package:material_ui/material_ui.dart';

Widget buildAppMaterialCompatibility(BuildContext context, Widget? child) {
  // mobile_scanner 7.x still reads legacy Material themes and localizations.
  // ignore: deprecated_member_use
  return MaterialUiCompatibilityBridge(child: child ?? const SizedBox.shrink());
}
