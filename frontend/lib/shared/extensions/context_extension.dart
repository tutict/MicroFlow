import 'package:flutter/material.dart';

extension ContextExtension on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;

  ColorScheme get colors => Theme.of(this).colorScheme;
}
