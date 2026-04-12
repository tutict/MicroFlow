import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

const supportedAppLocales = <Locale>[
  Locale('zh'),
  Locale('en'),
];

final localeControllerProvider =
    AsyncNotifierProvider<LocaleController, Locale>(LocaleController.new);

class LocaleController extends AsyncNotifier<Locale> {
  static const _localeKey = 'app.locale';

  @override
  Future<Locale> build() async {
    final stored = await ref.read(localStoreProvider).readString(_localeKey);
    if (stored == null || stored.isEmpty) {
      return const Locale('zh');
    }
    return _normalizeLocale(stored);
  }

  Future<void> setLocale(Locale locale) async {
    await ref.read(localStoreProvider).saveString(_localeKey, locale.languageCode);
    state = AsyncData(_normalizeLocale(locale.languageCode));
  }

  Locale _normalizeLocale(String languageCode) {
    return supportedAppLocales.firstWhere(
      (candidate) => candidate.languageCode == languageCode,
      orElse: () => const Locale('zh'),
    );
  }
}
