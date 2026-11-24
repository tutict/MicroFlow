import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_theme_extensions.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/agent_run.dart';

String agentRunStatusLabel(AppLocalizations l10n, AgentRunStatus status) {
  return switch (status) {
    AgentRunStatus.queued => l10n.agentRunStatusQueued,
    AgentRunStatus.contextBuilding => l10n.agentRunStatusContextBuilding,
    AgentRunStatus.running => l10n.agentRunStatusRunning,
    AgentRunStatus.waitingApproval => l10n.agentRunStatusWaitingApproval,
    AgentRunStatus.succeeded => l10n.agentRunStatusSucceeded,
    AgentRunStatus.failed => l10n.agentRunStatusFailed,
    AgentRunStatus.cancelled => l10n.agentRunStatusCancelled,
  };
}

class AgentRunStatusChip extends StatelessWidget {
  const AgentRunStatusChip({super.key, required this.status});

  final AgentRunStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final semantic = AppSemanticColors.of(context);
    final color = switch (status) {
      AgentRunStatus.queued ||
      AgentRunStatus.contextBuilding => semantic.neutral,
      AgentRunStatus.running => semantic.info,
      AgentRunStatus.waitingApproval => semantic.warning,
      AgentRunStatus.succeeded => semantic.success,
      AgentRunStatus.failed => semantic.danger,
      AgentRunStatus.cancelled => semantic.neutral,
    };
    return StatusBadge(label: agentRunStatusLabel(l10n, status), color: color);
  }
}
