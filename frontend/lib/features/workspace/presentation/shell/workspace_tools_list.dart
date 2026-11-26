import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../shared/theme/app_tokens.dart';

class WorkspaceToolsList extends StatelessWidget {
  const WorkspaceToolsList({
    super.key,
    required this.hasWorkspace,
    required this.onKnowledge,
    this.onMyWork,
    required this.onConnectors,
    required this.onAgentRuns,
    required this.onAccounting,
    required this.onDiagnostics,
    required this.onWorkspaceManagement,
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
  final VoidCallback? onMyWork;
  final VoidCallback? onConnectors;
  final VoidCallback? onAgentRuns;
  final VoidCallback? onAccounting;
  final VoidCallback? onDiagnostics;
  final VoidCallback? onWorkspaceManagement;
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
          key: const Key('tool-my-work'),
          icon: Icons.checklist_outlined,
          title: l10n.destinationMyWork,
          description: l10n.myWorkSubtitle,
          onTap: hasWorkspace ? onMyWork : null,
        ),
        _ToolTile(
          icon: Icons.library_books_outlined,
          title: l10n.destinationKnowledge,
          description: l10n.toolKnowledgeDescription,
          onTap: hasWorkspace ? onKnowledge : null,
        ),
        _ToolTile(
          key: const Key('tool-agent-runs'),
          icon: Icons.play_circle_outline,
          title: l10n.agentRunsTitle,
          description: l10n.toolAgentRunsDescription,
          onTap: hasWorkspace ? onAgentRuns : null,
        ),
        _ToolTile(
          icon: Icons.hub_outlined,
          title: l10n.destinationConnectors,
          description: l10n.toolConnectorsDescription,
          onTap: hasWorkspace ? onConnectors : null,
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
          key: const Key('tool-workspace-management'),
          icon: Icons.manage_accounts_outlined,
          title: l10n.workspaceManagementTitle,
          description: l10n.toolWorkspaceManagementDescription,
          onTap: hasWorkspace ? onWorkspaceManagement : null,
        ),
        const Divider(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Text(
            l10n.preferencesHeading,
            style: theme.textTheme.titleSmall,
          ),
        ),
        _PreferenceRow(
          icon: Icons.contrast_rounded,
          title: l10n.theme,
          options: [
            ChoiceChip(
              key: const Key('tool-theme-light'),
              label: Text(l10n.lightMode),
              selected: themeMode == ThemeMode.light,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: (_) => onUseLight(),
            ),
            ChoiceChip(
              key: const Key('tool-theme-dark'),
              label: Text(l10n.darkMode),
              selected: themeMode == ThemeMode.dark,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: (_) => onUseDark(),
            ),
          ],
        ),
        _PreferenceRow(
          icon: Icons.translate_rounded,
          title: l10n.language,
          options: [
            ChoiceChip(
              key: const Key('tool-language-zh'),
              label: Text(l10n.languageChinese),
              selected: languageCode == 'zh',
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: (_) => onUseChinese(),
            ),
            ChoiceChip(
              key: const Key('tool-language-en'),
              label: Text(l10n.english),
              selected: languageCode == 'en',
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: (_) => onUseEnglish(),
            ),
          ],
        ),
        const Divider(height: AppSpacing.lg),
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
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = onTap == null
        ? theme.disabledColor
        : destructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      minVerticalPadding: AppSpacing.sm,
      enabled: onTap != null,
      leading: Icon(icon, size: 20, color: accent),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(color: accent),
      ),
      subtitle: Text(
        description,
        style: theme.textTheme.bodySmall?.copyWith(
          color: onTap == null
              ? theme.disabledColor
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: destructive
          ? null
          : const Icon(Icons.chevron_right_rounded, size: 18),
      onTap: onTap,
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.icon,
    required this.title,
    required this.options,
  });

  final IconData icon;
  final String title;
  final List<Widget> options;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.lg),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: options,
            ),
          ),
        ],
      ),
    );
  }
}
