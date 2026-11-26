import 'package:material_ui/material_ui.dart';

import 'app_localizations.dart';

// Keep UI delegates here because Flutter's generator still emits legacy ones.
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
