import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_theme_extensions.dart';
import '../../../../shared/theme/app_tokens.dart';
import '../../domain/entities/agent_approval.dart';
import '../providers/agent_runtime_providers.dart';

/// Approval card: states the action, the target and the impact, and requires an
/// explicit human decision before anything is executed.
class AgentApprovalCard extends ConsumerStatefulWidget {
  const AgentApprovalCard({
    super.key,
    required this.runId,
    required this.approval,
  });

  final String runId;
  final AgentApproval approval;

  @override
  ConsumerState<AgentApprovalCard> createState() => _AgentApprovalCardState();
}

class _AgentApprovalCardState extends ConsumerState<AgentApprovalCard> {
  final _noteController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _decide(bool approve) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(agentRunActionsProvider)
          .decide(
            runId: widget.runId,
            approvalId: widget.approval.id,
            approve: approve,
            note: _noteController.text.trim(),
          );
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final semantic = AppSemanticColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: semantic.warningContainer,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: semantic.warning.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gavel_outlined, size: 18, color: semantic.warning),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.agentRunApprovalRequired,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    _riskLabel(l10n, widget.approval.riskLevel),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.approval.action,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.approval.targetResource != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              _LabelledLine(
                label: l10n.agentRunTarget,
                value: widget.approval.targetResource!,
              ),
            ],
            if (widget.approval.impactSummary != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              _LabelledLine(
                label: l10n.agentRunImpact,
                value: widget.approval.impactSummary!,
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            TextField(
              key: const Key('agent-approval-note'),
              controller: _noteController,
              enabled: !_submitting,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.agentRunRejectReason,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: semantic.danger,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const Key('agent-approval-reject'),
                  onPressed: _submitting ? null : () => _decide(false),
                  child: Text(l10n.agentRunReject),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton(
                  key: const Key('agent-approval-approve'),
                  onPressed: _submitting ? null : () => _decide(true),
                  child: Text(l10n.agentRunApprove),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _riskLabel(AppLocalizations l10n, String risk) => switch (risk) {
    'READ_ONLY' => l10n.agentRiskReadOnly,
    'INTERNAL_WRITE' => l10n.agentRiskInternalWrite,
    'EXTERNAL_WRITE' => l10n.agentRiskExternalWrite,
    'DESTRUCTIVE' => l10n.agentRiskDestructive,
    _ => l10n.agentRiskUnknown,
  };
}

class _LabelledLine extends StatelessWidget {
  const _LabelledLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: value,
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}
