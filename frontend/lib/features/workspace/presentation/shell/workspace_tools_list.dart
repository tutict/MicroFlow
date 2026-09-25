import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../shared/theme/app_tokens.dart';

class WorkspaceToolsList extends StatelessWidget {
  const WorkspaceToolsList({
    super.key,
    required this.hasWorkspace,
    required this.onKnowledge,
    required this.onAccounting,
    required this.onDiagnostics,
    required this.onUseLight,
    required this.onUseDark,
    required this.onUseChinese,
    required this.onUseEnglish,
    required this.onSignOut,
    required this.themeMode,
    required this.locale,
  });

  final bool hasWorkspace;
  final VoidCallback? onKnowledge;
  final VoidCallback? onAccounting;
  final VoidCallback? onDiagnostics;
  final VoidCallback onUseLight;
  final VoidCallback onUseDark;
  final VoidCallback onUseChinese;
  final VoidCallback onUseEnglish;
  final VoidCallback onSignOut;
  final ThemeMode themeMode;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final languageCode = locale.languageCode;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xs),
      children: [
        Text(l10n.toolsTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        _ToolTile(
          icon: Icons.library_books_outlined,
          title: l10n.destinationKnowledge,
          description: l10n.toolKnowledgeDescription,
          onTap: hasWorkspace ? onKnowledge : null,
        ),
        _ToolTile(
          icon: Icons.account_balance_outlined,
          title: l10n.destinationAccounting,
          description: l10n.toolAccountingDescription,
          onTap: hasWorkspace ? onAccounting : null,
        ),
        _ToolTile(
          icon: Icons.health_and_safety_outlined,
          title: l10n.destinationDiagnostics,
          description: l10n.toolDiagnosticsDescription,
          onTap: hasWorkspace ? onDiagnostics : null,
        ),
        _ToolTile(
          icon: Icons.light_mode_outlined,
          title: l10n.theme,
          description: l10n.toolAppearanceDescription,
          selected: themeMode == ThemeMode.light,
          onTap: onUseLight,
        ),
        _ToolTile(
          icon: Icons.dark_mode_outlined,
          title: l10n.darkMode,
          description: l10n.toolAppearanceDescription,
          selected: themeMode == ThemeMode.dark,
          onTap: onUseDark,
        ),
        _ToolTile(
          icon: Icons.translate_rounded,
          title: l10n.language,
          description: l10n.toolLanguageDescription,
          selected: languageCode == 'zh',
          onTap: onUseChinese,
        ),
        _ToolTile(
          icon: Icons.language_rounded,
          title: l10n.english,
          description: l10n.toolLanguageDescription,
          selected: languageCode == 'en',
          onTap: onUseEnglish,
        ),
        _ToolTile(
          icon: Icons.logout_rounded,
          title: l10n.signOutTooltip,
          description: l10n.toolSignOutDescription,
          destructive: true,
          onTap: onSignOut,
        ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.selected = false,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool selected;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = destructive
        ? theme.colorScheme.error
        : selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            side: BorderSide(
              color: destructive
                  ? theme.colorScheme.error
                  : selected
                  ? theme.colorScheme.primary
                  : theme.dividerColor,
              width: selected || destructive ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.medium),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: accent,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          Text(
                            description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
