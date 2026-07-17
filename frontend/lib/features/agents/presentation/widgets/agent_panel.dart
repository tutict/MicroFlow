import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../shared/theme/app_theme_extensions.dart';
import '../../../../shared/theme/app_tokens.dart';
import '../../../../shared/widgets/app_layout.dart';
import '../../domain/entities/agent_descriptor.dart';
import '../../domain/entities/agent_run.dart';

class AgentPanel extends StatelessWidget {
  const AgentPanel({
    super.key,
    required this.agents,
    required this.runs,
    this.compact = false,
  });

  final List<AgentDescriptor> agents;
  final List<AgentRun> runs;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final enabledAgents = agents.where((agent) => agent.enabled).length;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.smart_toy_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.agents,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        l10n.enabledCount(enabledAgents),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader(title: l10n.availableAgents, count: agents.length),
            const SizedBox(height: AppSpacing.sm),
            if (agents.isEmpty)
              AppEmptyState(
                icon: Icons.smart_toy_outlined,
                title: l10n.availableAgents,
                compact: true,
              )
            else
              for (final agent in agents) _AgentRow(agent: agent),
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: theme.dividerColor),
            const SizedBox(height: AppSpacing.md),
            _SectionHeader(title: l10n.runActivity, count: runs.length),
            const SizedBox(height: AppSpacing.sm),
            if (runs.isEmpty)
              Text(
                l10n.noAgentExecutions,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final run in runs) _RunRow(run: run),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '$count',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AgentRow extends StatelessWidget {
  const _AgentRow({required this.agent});

  final AgentDescriptor agent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final semantic = AppSemanticColors.of(context);
    return AppListRow(
      title: '@${agent.agentKey}',
      subtitle: agent.provider,
      leading: const Icon(Icons.smart_toy_outlined),
      trailing: AppStatusDot(
        label: agent.enabled ? l10n.enabled : l10n.disabled,
        color: agent.enabled ? semantic.success : semantic.neutral,
        compact: true,
      ),
      compact: true,
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({required this.run});

  final AgentRun run;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = _statusColor(context, run.status);
    return AppListRow(
      title: '@${run.agentKey}',
      subtitle: _formatRunSubtitle(l10n, run.id),
      leading: const Icon(Icons.play_circle_outline_rounded),
      trailing: AppStatusDot(
        label: _formatRunStatus(l10n, run.status),
        color: color,
        compact: true,
      ),
      compact: true,
    );
  }
}

String _formatRunStatus(AppLocalizations l10n, String value) {
  return switch (value) {
    'QUEUED' => l10n.queued,
    'RUNNING' => l10n.running,
    'DONE' || 'COMPLETED' => l10n.completed,
    'FAILED' => l10n.failed,
    _ => value,
  };
}

Color _statusColor(BuildContext context, String value) {
  final semantic = AppSemanticColors.of(context);
  return switch (value) {
    'DONE' || 'COMPLETED' => semantic.success,
    'FAILED' => semantic.danger,
    'RUNNING' => semantic.info,
    _ => semantic.warning,
  };
}

String _formatRunSubtitle(AppLocalizations l10n, String runId) {
  final compact = runId.length > 8 ? runId.substring(0, 8) : runId;
  return l10n.executionLabel(compact);
}
