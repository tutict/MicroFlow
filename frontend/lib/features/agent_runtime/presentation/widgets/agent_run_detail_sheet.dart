import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_theme_extensions.dart';
import '../../../../shared/theme/app_tokens.dart';
import '../../domain/entities/agent_run_step.dart';
import '../providers/agent_runtime_providers.dart';
import 'agent_run_card.dart';

Future<void> showAgentRunDetailSheet(BuildContext context, String runId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, controller) =>
            AgentRunDetailSheet(runId: runId, scrollController: controller),
      ),
    );

class AgentRunDetailSheet extends ConsumerWidget {
  const AgentRunDetailSheet({
    super.key,
    required this.runId,
    required this.scrollController,
  });
  final String runId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final run = ref.watch(agentRunProvider(runId));
    final steps = ref.watch(agentRunStepsProvider(runId));
    final sources = ref.watch(agentRunContextSourcesProvider(runId));
    final artifacts = ref.watch(agentRunArtifactsProvider(runId));
    final events = ref.watch(agentRunEventsProvider(runId));
    final eventError =
        ref.watch(
          agentReadErrorProvider((
            resource: AgentReadResource.events,
            id: runId,
          )),
        ) ??
        events.error;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      children: [
        Text(l10n.agentRunDetailTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        run.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _RunDetailError(
            error: error,
            onRetry: () => ref.invalidate(agentRunProvider(runId)),
          ),
          data: (value) => AgentRunCard(
            key: ValueKey(value.id),
            run: value,
            showDetails: false,
          ),
        ),
        _DetailHeading(l10n.agentRunStepsTitle),
        if (steps.hasError)
          _RunDetailError(
            error: steps.error!,
            retryKey: const Key('agent-run-steps-retry'),
            onRetry: () => ref.invalidate(agentRunStepsProvider(runId)),
          ),
        steps.when(
          skipError: true,
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const SizedBox.shrink(),
          data: (items) => items.isEmpty
              ? Text(l10n.agentRunStepsEmpty)
              : Column(
                  key: const Key('agent-run-steps'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final step in items) _RunStepRow(step)],
                ),
        ),
        _DetailHeading(l10n.agentRunSourcesTitle),
        sources.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _RunDetailError(
            error: error,
            onRetry: () =>
                ref.invalidate(agentRunContextSourcesProvider(runId)),
          ),
          data: (items) => items.isEmpty
              ? Text(l10n.agentRunsEmpty, style: theme.textTheme.bodySmall)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final source in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              source.label,
                              style: theme.textTheme.labelMedium,
                            ),
                            if (source.excerpt?.isNotEmpty ?? false)
                              Text(
                                source.excerpt!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        _DetailHeading(l10n.agentRunArtifactsTitle),
        artifacts.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _RunDetailError(
            error: error,
            onRetry: () => ref.invalidate(agentRunArtifactsProvider(runId)),
          ),
          data: (items) => items.isEmpty
              ? Text(l10n.agentRunsEmpty, style: theme.textTheme.bodySmall)
              : Column(
                  children: [
                    for (final artifact in items)
                      ExpansionTile(
                        key: ValueKey(artifact.id),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(
                          bottom: AppSpacing.sm,
                        ),
                        title: Text(
                          artifact.title,
                          style: theme.textTheme.labelLarge,
                        ),
                        subtitle: artifact.summary == null
                            ? null
                            : Text(
                                artifact.summary!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                        children: [
                          if (artifact.content != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SelectableText(
                                artifact.content!,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
        ),
        _DetailHeading(l10n.agentRunEventsTitle),
        if (eventError != null)
          _RunDetailError(
            error: eventError,
            retryKey: const Key('agent-run-events-retry'),
            onRetry: () =>
                ref.read(agentRunEventsProvider(runId).notifier).catchUp(),
          ),
        events.when(
          skipError: true,
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const SizedBox.shrink(),
          data: (items) {
            final tail = items.length > 20
                ? items.sublist(items.length - 20)
                : items;
            return tail.isEmpty
                ? Text(l10n.agentRunsEmpty, style: theme.textTheme.bodySmall)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final event in tail)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.xxs,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 44,
                                child: Text(
                                  '#${event.seq}',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                              Expanded(
                                child: Tooltip(
                                  message: event.type,
                                  child: Text(
                                    _eventLabel(l10n, event.type),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
          },
        ),
      ],
    );
  }
}

class _DetailHeading extends StatelessWidget {
  const _DetailHeading(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _RunDetailError extends StatelessWidget {
  const _RunDetailError({
    required this.error,
    required this.onRetry,
    this.retryKey,
  });
  final Object error;
  final VoidCallback onRetry;
  final Key? retryKey;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      children: [
        Expanded(
          child: Text(
            error.toString(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppSemanticColors.of(context).danger),
          ),
        ),
        TextButton(
          key: retryKey,
          onPressed: onRetry,
          child: Text(AppLocalizations.of(context)!.retryLabel),
        ),
      ],
    ),
  );
}

class _RunStepRow extends StatelessWidget {
  const _RunStepRow(this.step);
  final AgentRunStep step;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final status = switch (step.status) {
      'COMPLETED' => l10n.agentRunStatusSucceeded,
      'FAILED' => l10n.agentRunStatusFailed,
      'REJECTED' => l10n.agentRunStepRejected,
      'CANCELLED' => l10n.agentRunStatusCancelled,
      _ =>
        step.kind == 'APPROVAL'
            ? l10n.agentRunStatusWaitingApproval
            : l10n.agentRunStatusRunning,
    };
    final title = step.kind == 'MODEL_TURN'
        ? l10n.agentRunModelStep(step.agentKey ?? '')
        : step.title;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              step.status == 'FAILED'
                  ? Icons.error_outline
                  : step.status == 'COMPLETED'
                  ? Icons.check_circle_outline
                  : Icons.pending_outlined,
              size: 18,
              color: step.status == 'FAILED'
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelLarge),
                Text(
                  status,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (step.detail?.isNotEmpty ?? false)
                  Text(
                    step.detail!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _eventLabel(AppLocalizations l10n, String type) => switch (type) {
  'RUN_QUEUED' => l10n.agentRunStatusQueued,
  'RUN_CONTEXT_BUILDING' ||
  'RUN_CONTEXT_READY' => l10n.agentRunStatusContextBuilding,
  'RUN_STARTED' || 'RUN_RESUMED' => l10n.agentRunStatusRunning,
  'RUN_WAITING_APPROVAL' ||
  'APPROVAL_REQUESTED' => l10n.agentRunStatusWaitingApproval,
  'RUN_SUCCEEDED' => l10n.agentRunStatusSucceeded,
  'RUN_FAILED' ||
  'RUN_INTERRUPTED' ||
  'MODEL_TURN_FAILED' ||
  'TOOL_FAILED' ||
  'TOOL_UNKNOWN' => l10n.agentRunStatusFailed,
  'RUN_CANCELLED' => l10n.agentRunStatusCancelled,
  'APPROVAL_APPROVED' => l10n.agentRunEventApproved,
  'APPROVAL_REJECTED' || 'TOOL_REJECTED' => l10n.agentRunEventRejected,
  'MODEL_TURN_STARTED' => l10n.agentRunEventModelStarted,
  'MODEL_TURN_COMPLETED' => l10n.agentRunEventModelCompleted,
  'TOOL_STARTED' => l10n.agentRunEventToolStarted,
  'TOOL_COMPLETED' => l10n.agentRunEventToolCompleted,
  'ARTIFACT_CREATED' => l10n.agentRunEventArtifactCreated,
  _ => l10n.agentRunEventUpdated,
};
