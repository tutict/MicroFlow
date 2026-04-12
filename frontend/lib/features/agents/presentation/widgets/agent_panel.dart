import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/status_badge.dart';
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
    final queuedRuns = runs.where((run) => run.status == 'QUEUED').length;
    final outerRadius = compact ? 20.0 : 30.0;
    final outerPadding = compact ? 14.0 : 18.0;
    final shellSurface = theme.colorScheme.surface.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.5 : 0.76,
    );
    final nestedSurface = theme.colorScheme.surface.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.34 : 0.62,
    );
    final subtleBorder = theme.dividerColor.withValues(alpha: 0.82);

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.4 : 0.82,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: subtleBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.14,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.smart_toy_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.agents,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.enabledCount(enabledAgents),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.66,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _AgentMetricPill(
                      value: '${agents.length}',
                      label: l10n.availableAgents,
                    ),
                    _AgentMetricPill(value: '$queuedRuns', label: l10n.queued),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.availableAgents,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...agents.map(
            (agent) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AgentTile(agent: agent),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.runActivity,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (runs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: shellSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: subtleBorder),
              ),
              child: Text(
                l10n.noAgentExecutions,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
                ),
              ),
            )
          else
            ...runs.map(
              (run) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RunTile(run: run),
              ),
            ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: shellSurface,
        borderRadius: BorderRadius.circular(outerRadius),
        border: Border.all(color: subtleBorder),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark
                ? const Color(0x22000000)
                : const Color(0x120E1A22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              outerPadding,
              compact ? 14 : 18,
              outerPadding,
              compact ? 14 : 16,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.38 : 0.78,
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(outerRadius),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: compact ? 36 : 40,
                      height: compact ? 36 : 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.smart_toy_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: compact ? 10 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.agents,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.enabledCount(enabledAgents),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.66,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 12 : 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _AgentMetricPill(
                      value: '${agents.length}',
                      label: l10n.availableAgents,
                    ),
                    _AgentMetricPill(value: '$queuedRuns', label: l10n.queued),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              outerPadding,
              compact ? 14 : 18,
              outerPadding,
              compact ? 14 : 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.availableAgents,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: compact ? 10 : 12),
                ...agents.map(
                  (agent) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AgentTile(agent: agent),
                  ),
                ),
                SizedBox(height: compact ? 6 : 8),
                Text(
                  l10n.runActivity,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: compact ? 10 : 12),
                if (runs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: nestedSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: subtleBorder),
                    ),
                    child: Text(
                      l10n.noAgentExecutions,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.64,
                        ),
                      ),
                    ),
                  )
                else
                  ...runs.map(
                    (run) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RunTile(run: run),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentMetricPill extends StatelessWidget {
  const _AgentMetricPill({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPill(
      label: label,
      value: value,
      backgroundColor: theme.colorScheme.surface.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.34 : 0.64,
      ),
      borderColor: theme.dividerColor.withValues(alpha: 0.82),
      valueColor: theme.colorScheme.onSurface,
      labelColor: theme.colorScheme.onSurface.withValues(alpha: 0.66),
    );
  }
}

class _AgentTile extends StatelessWidget {
  const _AgentTile({required this.agent});

  final AgentDescriptor agent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.34 : 0.64,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.82)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.smart_toy_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '@${agent.agentKey}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    StatusBadge(
                      label: agent.enabled ? l10n.enabled : l10n.disabled,
                      color: agent.enabled
                          ? const Color(0xFF1F6F5C)
                          : const Color(0xFF7A8791),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AppPill(
                  label: agent.provider,
                  backgroundColor: theme.colorScheme.surface.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.32 : 0.74,
                  ),
                  borderColor: theme.dividerColor.withValues(alpha: 0.82),
                  labelColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.68,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  const _RunTile({required this.run});

  final AgentRun run;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final statusColor = _statusColor(run.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.34 : 0.64,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.82)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '@${run.agentKey}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    StatusBadge(
                      label: _formatRunStatus(l10n, run.status),
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatRunSubtitle(l10n, run.id),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

Color _statusColor(String value) {
  return switch (value) {
    'DONE' || 'COMPLETED' => const Color(0xFF1F8A5C),
    'FAILED' => const Color(0xFFBA3B2F),
    'RUNNING' => const Color(0xFF3D7EA6),
    _ => const Color(0xFFB38A32),
  };
}

String _formatRunSubtitle(AppLocalizations l10n, String runId) {
  final compact = runId.length > 8 ? runId.substring(0, 8) : runId;
  return l10n.executionLabel(compact);
}
