import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_theme_extensions.dart';
import '../../../../shared/theme/app_tokens.dart';
import '../../domain/entities/agent_run.dart';
import '../../domain/entities/agent_approval.dart';
import '../providers/agent_runtime_providers.dart';
import 'agent_approval_card.dart';
import 'agent_run_detail_sheet.dart';
import 'agent_run_status_chip.dart';

class AgentRunCard extends ConsumerStatefulWidget {
  const AgentRunCard({super.key, required this.run, this.showDetails = true});

  final AgentRunSummary run;
  final bool showDetails;

  @override
  ConsumerState<AgentRunCard> createState() => _AgentRunCardState();
}

class _AgentRunCardState extends ConsumerState<AgentRunCard> {
  AgentRunSummary get run => widget.run;
  bool _controlPending = false;
  String? _controlError;

  @override
  void didUpdateWidget(covariant AgentRunCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.run.id != run.id) _controlPending = false;
    if (oldWidget.run.id != run.id || oldWidget.run.status != run.status) {
      _controlError = null;
    }
  }

  Future<void> _runControl(bool retry) async {
    if (_controlPending) return;
    final runId = run.id;
    setState(() {
      _controlPending = true;
      _controlError = null;
    });
    try {
      final actions = ref.read(agentRunActionsProvider);
      if (retry) {
        await actions.retry(runId);
      } else {
        await actions.cancel(runId);
      }
    } catch (error) {
      if (mounted && run.id == runId) {
        setState(() => _controlError = error.toString());
      }
    } finally {
      if (mounted && run.id == runId) setState(() => _controlPending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final semantic = AppSemanticColors.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final approvals = run.status == AgentRunStatus.waitingApproval
        ? ref.watch(agentRunApprovalsProvider(run.id))
        : const AsyncData<List<AgentApproval>>([]);

    return Container(
      key: Key('agent-run-card-${run.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AgentRunStatusChip(status: run.status),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '@${run.agentKey}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                if (widget.showDetails)
                  IconButton(
                    key: Key('agent-run-detail-${run.id}'),
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.agentRunStepCount(run.stepCount),
                    onPressed: () => showAgentRunDetailSheet(context, run.id),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              run.goal,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            if (run.contextSummary != null &&
                run.contextSummary!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                run.contextSummary!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
            if (run.errorMessage != null && run.errorMessage!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.agentRunError(run.errorMessage!),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: semantic.danger,
                ),
              ),
            ],
            if (_controlError != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _controlError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: semantic.danger,
                  ),
                ),
              ),
            if (run.status == AgentRunStatus.waitingApproval) ...[
              const SizedBox(height: AppSpacing.xs),
              approvals.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      error.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: semantic.danger,
                      ),
                    ),
                    TextButton(
                      key: Key('agent-run-approvals-retry-${run.id}'),
                      onPressed: () =>
                          ref.invalidate(agentRunApprovalsProvider(run.id)),
                      child: Text(l10n.retryLabel),
                    ),
                  ],
                ),
                data: (items) => Column(
                  children: [
                    for (final approval in items)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: AgentApprovalCard(
                          key: ValueKey(approval.id),
                          runId: run.id,
                          approval: approval,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (run.status.canCancel || run.status.canRetry) ...[
              const SizedBox(height: AppSpacing.xxs),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_controlPending)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (run.status.canRetry)
                    TextButton.icon(
                      key: Key('agent-run-retry-${run.id}'),
                      onPressed: _controlPending
                          ? null
                          : () => _runControl(true),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(l10n.agentRunRetry),
                    ),
                  if (run.status.canCancel)
                    TextButton.icon(
                      key: Key('agent-run-cancel-${run.id}'),
                      onPressed: _controlPending
                          ? null
                          : () => _runControl(false),
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: Text(l10n.agentRunCancel),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
