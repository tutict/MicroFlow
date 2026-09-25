import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../shared/theme/app_tokens.dart';
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
        destination: ShellDestination.knowledge,
        icon: Icons.library_books_outlined,
        label: l10n.destinationKnowledge,
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
    ];
    return FocusTraversalOrder(
      order: const NumericFocusOrder(1),
      child: ColoredBox(
        color: theme.colorScheme.surfaceContainerLow,
        child: SizedBox(
          width: showLabels ? 96 : 72,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            children: [
              for (final item in items)
                _RailButton(
                  item: item,
                  selected: item.destination == selected,
                  showLabel: showLabels,
                  onSelected: () => onSelected(item.destination),
                ),
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
    final button = Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 24, color: color),
                if (showLabel) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (showLabel) {
      return InkWell(onTap: onSelected, child: button);
    }
    return IconButton(tooltip: item.label, onPressed: onSelected, icon: button);
  }
}
