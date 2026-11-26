import 'package:material_ui/material_ui.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../shared/theme/app_tokens.dart';
import '../../../../shared/theme/app_theme_extensions.dart';
import 'shell_destination.dart';

class WorkspaceDestinationRail extends StatelessWidget {
  const WorkspaceDestinationRail({
    super.key,
    required this.selected,
    required this.showLabels,
    required this.onSelected,
  });

  final ShellDestination selected;
  final bool showLabels;
  final ValueChanged<ShellDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final items = <_RailItem>[
      _RailItem(
        destination: ShellDestination.conversation,
        icon: Icons.forum_outlined,
        label: l10n.destinationConversation,
      ),
      _RailItem(
        destination: ShellDestination.tasks,
        icon: Icons.checklist_outlined,
        label: l10n.destinationMyWork,
      ),
      _RailItem(
        destination: ShellDestination.knowledge,
        icon: Icons.library_books_outlined,
        label: l10n.destinationKnowledge,
      ),
      _RailItem(
        destination: ShellDestination.connectors,
        icon: Icons.hub_outlined,
        label: l10n.destinationConnectors,
      ),
      _RailItem(
        destination: ShellDestination.accounting,
        icon: Icons.account_balance_outlined,
        label: l10n.destinationAccounting,
      ),
      _RailItem(
        destination: ShellDestination.diagnostics,
        icon: Icons.health_and_safety_outlined,
        label: l10n.destinationDiagnostics,
      ),
      _RailItem(
        destination: ShellDestination.workspaceManagement,
        icon: Icons.manage_accounts_outlined,
        label: l10n.destinationWorkspaceManagement,
      ),
    ];
    return FocusTraversalOrder(
      order: const NumericFocusOrder(1),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        child: SizedBox(
          width: showLabels ? 176 : 64,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xs),
            children: [
              for (var index = 0; index < items.length; index++) ...[
                if (index == 3) ...[
                  const Divider(height: AppSpacing.lg),
                  if (showLabels)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xs,
                        0,
                        AppSpacing.xs,
                        AppSpacing.xs,
                      ),
                      child: Text(
                        l10n.workspaceToolsHeading,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
                _RailButton(
                  item: items[index],
                  selected: items[index].destination == selected,
                  showLabel: showLabels,
                  onSelected: () => onSelected(items[index].destination),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem {
  const _RailItem({
    required this.destination,
    required this.icon,
    required this.label,
  });

  final ShellDestination destination;
  final IconData icon;
  final String label;
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.onSelected,
  });

  final _RailItem item;
  final bool selected;
  final bool showLabel;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final contents = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 44),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(
          mainAxisAlignment: showLabel
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 20, color: color),
            if (showLabel) ...[
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    final button = Material(
      color: selected
          ? AppSemanticColors.of(context).selectedOverlay
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(AppRadii.small),
        focusColor: theme.colorScheme.primaryContainer,
        child: contents,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Tooltip(
        message: item.label,
        excludeFromSemantics: true,
        child: MergeSemantics(
          child: Semantics(
            key: Key('shell-nav-${item.destination.name}'),
            selected: selected,
            button: true,
            label: showLabel ? null : item.label,
            child: button,
          ),
        ),
      ),
    );
  }
}
