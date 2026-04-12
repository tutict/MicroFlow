import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

final themeModeControllerProvider =
    AsyncNotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  static const _themeModeKey = 'app.theme_mode';

  @override
  Future<ThemeMode> build() async {
    final stored = await ref.read(localStoreProvider).readString(_themeModeKey);
    return _normalizeThemeMode(stored);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await ref.read(localStoreProvider).saveString(_themeModeKey, mode.name);
    state = AsyncData(mode);
  }

  ThemeMode _normalizeThemeMode(String? raw) {
    return switch (raw) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.light,
    };
  }
}
