import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_tokens.dart';
import '../domain/entities/task_item.dart';

/// Resolves a task status to its display label, icon and accent colour.
/// Labels come from localization so the badge never shows an untranslated string.
({String label, Color color, IconData icon}) taskStatusPresentation(
  BuildContext context,
  String status,
) {
  final scheme = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  return switch (status) {
    'DONE' => (
      label: l10n.taskStatusDone,
      color: scheme.primary,
      icon: Icons.check_circle_outline,
    ),
    'IN_PROGRESS' => (
      label: l10n.taskStatusInProgress,
      color: scheme.tertiary,
      icon: Icons.play_circle_outline,
    ),
    'BLOCKED' => (
      label: l10n.taskStatusBlocked,
      color: scheme.error,
      icon: Icons.block_outlined,
    ),
    'CANCELLED' => (
      label: l10n.taskStatusCancelled,
      color: scheme.outline,
      icon: Icons.cancel_outlined,
    ),
    _ => (
      label: l10n.taskStatusOpen,
      color: scheme.secondary,
      icon: Icons.radio_button_unchecked,
    ),
  };
}

IconData taskPriorityIcon(String priority) {
  switch (priority) {
    case 'URGENT':
      return Icons.priority_high;
    case 'HIGH':
      return Icons.keyboard_double_arrow_up;
    case 'LOW':
      return Icons.keyboard_double_arrow_down;
    default:
      return Icons.remove;
  }
}

class TaskStatusBadge extends StatelessWidget {
  const TaskStatusBadge({super.key, required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presentation = taskStatusPresentation(context, task.status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(color: presentation.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(presentation.icon, size: 14, color: presentation.color),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            presentation.label,
            style: theme.textTheme.labelSmall?.copyWith(color: presentation.color),
          ),
          if (task.isOverdue) ...[
            const SizedBox(width: AppSpacing.xxs),
            Icon(
              Icons.schedule,
              size: 14,
              color: theme.colorScheme.error,
            ),
          ],
        ],
      ),
    );
  }
}
