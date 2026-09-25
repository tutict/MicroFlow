import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../core/providers/theme_mode_controller.dart';
import '../theme/app_tokens.dart';

class ThemeModeSwitcher extends ConsumerWidget {
  const ThemeModeSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode =
        ref.watch(themeModeControllerProvider).value ?? ThemeMode.light;
    final isDark = themeMode == ThemeMode.dark;
    final theme = Theme.of(context);

    return PopupMenuButton<ThemeMode>(
      tooltip: l10n.theme,
      initialValue: themeMode,
      onSelected: (mode) {
        ref.read(themeModeControllerProvider.notifier).setThemeMode(mode);
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: ThemeMode.light, child: Text(l10n.lightMode)),
        PopupMenuItem(value: ThemeMode.dark, child: Text(l10n.darkMode)),
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
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              isDark ? l10n.darkMode : l10n.lightMode,
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
