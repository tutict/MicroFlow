import 'package:flutter/material.dart';
import 'package:microflow_frontend/l10n/app_localizations.dart';

import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/status_badge.dart';

class AgentRunsPage extends StatelessWidget {
  const AgentRunsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.agentRunsTitle)),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.brightness == Brightness.dark
                ? const [
                    Color(0xFF081015),
                    Color(0xFF10191F),
                    Color(0xFF152229),
                  ]
                : const [
                    Color(0xFFF7F9F9),
                    Color(0xFFEEF2F3),
                    Color(0xFFE3EAEC),
                  ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: theme.brightness == Brightness.dark
                      ? const [Color(0xFF162229), Color(0xFF111C22)]
                      : const [Color(0xFFFCFDFD), Color(0xFFF2F6F7)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.82),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.brightness == Brightness.dark
                        ? const Color(0x26000000)
                        : const Color(0x140E1A22),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          const Color(0xFF1F8A5C).withValues(alpha: 0.8),
                          theme.colorScheme.primary.withValues(alpha: 0.18),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Text(
                    l10n.recentExecutions,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.workspaceDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.68,
                      ),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      AppPill(
                        label: l10n.agentRunsTitle,
                        icon: Icons.smart_toy_rounded,
                        backgroundColor: theme.colorScheme.surface.withValues(
                          alpha: theme.brightness == Brightness.dark
                              ? 0.34
                              : 0.64,
                        ),
                        borderColor: theme.dividerColor.withValues(alpha: 0.82),
                        labelColor: theme.colorScheme.onSurface.withValues(
                          alpha: 0.76,
                        ),
                        iconColor: theme.colorScheme.primary,
                      ),
                      AppPill(
                        label: l10n.recentActivityLabel,
                        icon: Icons.bolt_rounded,
                        backgroundColor: theme.colorScheme.surface.withValues(
                          alpha: theme.brightness == Brightness.dark
                              ? 0.34
                              : 0.64,
                        ),
                        borderColor: theme.dividerColor.withValues(alpha: 0.82),
                        labelColor: theme.colorScheme.onSurface.withValues(
                          alpha: 0.76,
                        ),
                        iconColor: const Color(0xFF3D7EA6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _RunPreviewTile(
                    agentKey: 'assistant',
                    description: l10n.summarizeArchitectureChanges,
                    statusLabel: l10n.running,
                    statusColor: const Color(0xFFC86A3B),
                  ),
                  const SizedBox(height: 12),
                  _RunPreviewTile(
                    agentKey: 'reviewer',
                    description: l10n.nativeImagePreflightChecks,
                    statusLabel: l10n.completed,
                    statusColor: const Color(0xFF1E8E5A),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunPreviewTile extends StatelessWidget {
  const _RunPreviewTile({
    required this.agentKey,
    required this.description,
    required this.statusLabel,
    required this.statusColor,
  });

  final String agentKey;
  final String description;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.34 : 0.64,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.82)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.smart_toy_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '@$agentKey',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    StatusBadge(label: statusLabel, color: statusColor),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                    height: 1.45,
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
