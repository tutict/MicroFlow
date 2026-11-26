import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../shared/theme/app_tokens.dart';

class WorkspaceBottomNavigation extends StatelessWidget {
  const WorkspaceBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    this.hasWorkspace = true,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final bool hasWorkspace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final items = [
      (
        key: 'conversations',
        icon: Icons.forum_outlined,
        label: l10n.destinationConversation,
      ),
      (
        key: 'work',
        icon: Icons.checklist_outlined,
        label: l10n.destinationMyWork,
      ),
      (
        key: 'knowledge',
        icon: Icons.library_books_outlined,
        label: l10n.destinationKnowledge,
      ),
      (key: 'tools', icon: Icons.handyman_outlined, label: l10n.toolsTab),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  flex: largeText && currentIndex == index ? 2 : 1,
                  child: Builder(
                    builder: (context) {
                      final item = items[index];
                      final selected = currentIndex == index;
                      final enabled = hasWorkspace || index == 0 || index == 3;
                      final color = !enabled
                          ? theme.disabledColor
                          : selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant;
                      return MergeSemantics(
                        child: Semantics(
                          key: Key('mobile-nav-${item.key}'),
                          label: largeText && !selected ? item.label : null,
                          button: true,
                          selected: selected,
                          enabled: enabled,
                          child: Tooltip(
                            message: item.label,
                            excludeFromSemantics: true,
                            child: Material(
                              color: selected
                                  ? theme.colorScheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                AppRadii.small,
                              ),
                              child: InkWell(
                                onTap: enabled ? () => onSelected(index) : null,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.small,
                                ),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 56,
                                    minWidth: 44,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xxs,
                                      vertical: AppSpacing.xs,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(item.icon, size: 20, color: color),
                                        if (!largeText || selected) ...[
                                          const SizedBox(
                                            height: AppSpacing.xxs,
                                          ),
                                          Text(
                                            item.label,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: color,
                                                  fontWeight: selected
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
