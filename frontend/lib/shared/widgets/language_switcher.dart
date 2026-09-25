import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../core/providers/locale_controller.dart';
import '../theme/app_tokens.dart';

class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale =
        ref.watch(localeControllerProvider).value ?? const Locale('zh');
    final theme = Theme.of(context);

    return PopupMenuButton<Locale>(
      tooltip: l10n.language,
      initialValue: currentLocale,
      onSelected: (locale) {
        ref.read(localeControllerProvider.notifier).setLocale(locale);
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: const Locale('en'), child: Text(l10n.english)),
        PopupMenuItem(
          value: const Locale('zh'),
          child: Text(l10n.simplifiedChinese),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.82),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              currentLocale.languageCode == 'zh'
                  ? l10n.simplifiedChinese
                  : l10n.english,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
